import json
import logging
import asyncio
from typing import List, Dict, Any, Optional
import httpx
from deep_translator import GoogleTranslator
from backend_fastapi.app.core.config import settings

logger = logging.getLogger(__name__)

class DocumentTranslationContext:
    """Maintains cross-page terminology, glossary and cumulative context."""
    def __init__(self, source_language: str = "auto", target_language: str = "pt-br"):
        self.source_language = source_language
        self.target_language = target_language
        self.glossary: Dict[str, str] = {}
        self.previous_page_summaries: List[str] = []

    def add_summary(self, page_num: int, summary: str):
        self.previous_page_summaries.append(f"Página {page_num}: {summary}")
        if len(self.previous_page_summaries) > 3:
            self.previous_page_summaries.pop(0)

    def get_context_text(self) -> str:
        if not self.previous_page_summaries and not self.glossary:
            return "Nenhum contexto anterior registrado ainda."
        
        parts = []
        if self.glossary:
            terms = ", ".join([f"{k} -> {v}" for k, v in list(self.glossary.items())[:10]])
            parts.append(f"Glossário: [{terms}]")
        if self.previous_page_summaries:
            parts.append(f"Contexto: {'; '.join(self.previous_page_summaries)}")
        return " | ".join(parts)


class AITranslator:
    def __init__(self):
        pass

    def _normalize_lang_code(self, code: str) -> str:
        cleaned = code.strip().lower()
        if cleaned in ["pt-br", "pt_br", "portuguese", "pt"]:
            return "pt"
        if cleaned in ["en-us", "en_us", "english", "en"]:
            return "en"
        if cleaned in ["es-es", "spanish", "es"]:
            return "es"
        if cleaned in ["french", "fr"]:
            return "fr"
        if cleaned in ["german", "de"]:
            return "de"
        if cleaned in ["italian", "it"]:
            return "it"
        if cleaned in ["japanese", "ja"]:
            return "ja"
        if cleaned in ["chinese", "mandarin", "zh"]:
            return "zh-CN"
        return cleaned

    def _build_system_prompt(self, context: DocumentTranslationContext) -> str:
        raw_prompt = settings.CUSTOM_SYSTEM_PROMPT
        prompt = raw_prompt.replace("[IDIOMA_ORIGEM]", context.source_language)
        prompt = prompt.replace("[IDIOMA_DESTINO]", context.target_language)
        prompt = prompt.replace("[INSERIR_GLOSSARIO_OU_CONTEXTO_ANTERIOR]", context.get_context_text())
        return prompt

    async def translate_blocks(
        self,
        blocks: List[Dict[str, Any]],
        context: DocumentTranslationContext,
        page_num: int = 1,
        total_pages: int = 1
    ) -> List[Dict[str, Any]]:
        """
        Translates a list of document text blocks while preserving layout constraints, tables,
        diagrams, and editorial markup.
        """
        if not blocks:
            return []

        text_blocks_to_translate = [
            {"id": b["id"], "text": b["text"]} 
            for b in blocks 
            if b.get("text", "").strip()
        ]

        if not text_blocks_to_translate:
            return [{"id": b["id"], "translated_text": b.get("text", "")} for b in blocks]

        provider = settings.AI_PROVIDER.lower().strip()

        # 1. Try Gemini LLM
        if provider == "gemini" and settings.GEMINI_API_KEY:
            try:
                translated = await self._call_gemini_api(text_blocks_to_translate, context, page_num)
                context.add_summary(page_num, f"Página com {len(text_blocks_to_translate)} blocos traduzida com Gemini.")
                return self._merge_translations(blocks, translated)
            except Exception as e:
                logger.error(f"Gemini API translation error ({e}). Falling back to DeepTranslator.")

        # 2. Try OpenAI LLM
        elif provider == "openai" and settings.OPENAI_API_KEY:
            try:
                translated = await self._call_openai_compatible_api(
                    endpoint="https://api.openai.com/v1/chat/completions",
                    api_key=settings.OPENAI_API_KEY,
                    model=settings.OPENAI_MODEL,
                    blocks=text_blocks_to_translate,
                    context=context,
                    page_num=page_num
                )
                context.add_summary(page_num, f"Página com {len(text_blocks_to_translate)} blocos traduzida com OpenAI.")
                return self._merge_translations(blocks, translated)
            except Exception as e:
                logger.error(f"OpenAI API translation error ({e}). Falling back to DeepTranslator.")

        # 3. Try Claude LLM
        elif provider == "claude" and settings.CLAUDE_API_KEY:
            try:
                translated = await self._call_claude_api(
                    api_key=settings.CLAUDE_API_KEY,
                    model=settings.CLAUDE_MODEL,
                    blocks=text_blocks_to_translate,
                    context=context,
                    page_num=page_num
                )
                context.add_summary(page_num, f"Página com {len(text_blocks_to_translate)} blocos traduzida com Claude.")
                return self._merge_translations(blocks, translated)
            except Exception as e:
                logger.error(f"Claude API translation error ({e}). Falling back to DeepTranslator.")

        # 4. Try Groq LLM
        elif provider == "groq" and settings.GROQ_API_KEY:
            try:
                translated = await self._call_openai_compatible_api(
                    endpoint="https://api.groq.com/openai/v1/chat/completions",
                    api_key=settings.GROQ_API_KEY,
                    model=settings.GROQ_MODEL,
                    blocks=text_blocks_to_translate,
                    context=context,
                    page_num=page_num
                )
                context.add_summary(page_num, f"Página com {len(text_blocks_to_translate)} blocos traduzida com Groq.")
                return self._merge_translations(blocks, translated)
            except Exception as e:
                logger.error(f"Groq API translation error ({e}). Falling back to DeepTranslator.")

        # 5. Try Ollama Local
        elif provider == "ollama":
            try:
                translated = await self._call_ollama_api(text_blocks_to_translate, context, page_num)
                return self._merge_translations(blocks, translated)
            except Exception as e:
                logger.error(f"Ollama translation error ({e}). Falling back to DeepTranslator.")

        # 6. Real Translation using DeepTranslator (Google Translate Engine)
        translated = await self._real_translation_deep_translator(
            text_blocks_to_translate, 
            context.source_language, 
            context.target_language
        )
        context.add_summary(page_num, f"Página {page_num}/{total_pages} traduzida.")
        return self._merge_translations(blocks, translated)

    async def _real_translation_deep_translator(
        self, 
        blocks: List[Dict[str, Any]], 
        source_lang: str, 
        target_lang: str
    ) -> List[Dict[str, Any]]:
        """Real translation using Google Translate Engine via deep-translator in async threadpool."""
        src = "auto" if source_lang == "auto" else self._normalize_lang_code(source_lang)
        tgt = self._normalize_lang_code(target_lang)

        def _do_translate():
            translator = GoogleTranslator(source=src, target=tgt)
            results = []
            for b in blocks:
                text = b["text"].strip()
                if not text:
                    results.append({"id": b["id"], "translated_text": ""})
                    continue
                try:
                    trans = translator.translate(text)
                    results.append({"id": b["id"], "translated_text": trans or text})
                except Exception as e:
                    logger.warning(f"Error translating single block ({e}): {text[:30]}")
                    results.append({"id": b["id"], "translated_text": text})
            return results

        return await asyncio.to_thread(_do_translate)

    @staticmethod
    def _extract_json(text: str) -> Dict[str, Any]:
        """Robustly extracts JSON from LLM output, removing <think> tags and markdown blocks."""
        cleaned = text.strip()
        # Remove reasoning thoughts (e.g. DeepSeek-R1 / reasoning models)
        if "</think>" in cleaned:
            cleaned = cleaned.split("</think>")[-1].strip()
        # Strip markdown fences
        if cleaned.startswith("```"):
            lines = cleaned.splitlines()
            if lines and lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].startswith("```"):
                lines = lines[:-1]
            cleaned = "\n".join(lines).strip()
        return json.loads(cleaned)

    async def _call_gemini_api(
        self, 
        blocks: List[Dict[str, Any]], 
        context: DocumentTranslationContext,
        page_num: int
    ) -> List[Dict[str, Any]]:
        prompt_system = self._build_system_prompt(context)
        input_payload = {"page_number": page_num, "blocks": blocks}
        user_content = json.dumps(input_payload, ensure_ascii=False)

        candidate_models = [settings.GEMINI_MODEL]
        if settings.GEMINI_MODEL != "gemini-3.5-flash-lite":
            candidate_models.append("gemini-3.5-flash-lite")

        last_error = None
        for current_model in candidate_models:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{current_model}:generateContent?key={settings.GEMINI_API_KEY}"
            payload = {
                "system_instruction": {"parts": [{"text": prompt_system}]},
                "contents": [{"parts": [{"text": f"Traduza os blocos:\n{user_content}"}]}],
                "generationConfig": {"response_mime_type": "application/json", "temperature": 0.2}
            }

            for attempt in range(3):
                try:
                    async with httpx.AsyncClient(timeout=60.0) as client:
                        resp = await client.post(url, json=payload)
                        if resp.status_code == 200:
                            data = resp.json()
                            raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
                            parsed = self._extract_json(raw_text)
                            return parsed.get("blocks", [])
                        
                        # Handle 429 Quota or 503 Server Busy with exponential backoff
                        if resp.status_code in [429, 503]:
                            wait_time = (2 ** attempt) * 2  # 2s, 4s, 8s
                            logger.warning(
                                f"Gemini API returned {resp.status_code} (Rate/Quota limit) for {current_model}. "
                                f"Retrying in {wait_time}s (Attempt {attempt+1}/3)..."
                            )
                            await asyncio.sleep(wait_time)
                            continue
                        
                        resp.raise_for_status()
                except Exception as e:
                    last_error = e
                    if attempt < 2:
                        await asyncio.sleep(2.0)
                        continue

        if last_error:
            raise last_error
        raise RuntimeError("Gemini API translation failed on all models and retry attempts.")

    async def _call_openai_compatible_api(
        self,
        endpoint: str,
        api_key: str,
        model: str,
        blocks: List[Dict[str, Any]],
        context: DocumentTranslationContext,
        page_num: int
    ) -> List[Dict[str, Any]]:
        prompt_system = self._build_system_prompt(context)
        input_payload = {"page_number": page_num, "blocks": blocks}
        user_content = json.dumps(input_payload, ensure_ascii=False)

        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": prompt_system},
                {"role": "user", "content": user_content}
            ],
            "temperature": 0.2
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(endpoint, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
            raw_content = data["choices"][0]["message"]["content"]
            parsed = self._extract_json(raw_content)
            return parsed.get("blocks", [])

    async def _call_claude_api(
        self,
        api_key: str,
        model: str,
        blocks: List[Dict[str, Any]],
        context: DocumentTranslationContext,
        page_num: int
    ) -> List[Dict[str, Any]]:
        prompt_system = self._build_system_prompt(context)
        input_payload = {"page_number": page_num, "blocks": blocks}
        user_content = json.dumps(input_payload, ensure_ascii=False)

        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        }
        payload = {
            "model": model,
            "system": prompt_system,
            "messages": [
                {"role": "user", "content": f"Traduza e retorne JSON:\n{user_content}"}
            ],
            "max_tokens": 4096,
            "temperature": 0.2
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post("https://api.anthropic.com/v1/messages", headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
            raw_content = data["content"][0]["text"]
            parsed = self._extract_json(raw_content)
            return parsed.get("blocks", [])

    async def _call_ollama_api(
        self,
        blocks: List[Dict[str, Any]],
        context: DocumentTranslationContext,
        page_num: int
    ) -> List[Dict[str, Any]]:
        prompt_system = self._build_system_prompt(context)
        input_payload = {"page_number": page_num, "blocks": blocks}
        user_content = json.dumps(input_payload, ensure_ascii=False)

        url = f"{settings.OLLAMA_HOST}/api/chat"
        payload = {
            "model": settings.OLLAMA_MODEL,
            "messages": [
                {"role": "system", "content": prompt_system},
                {"role": "user", "content": user_content}
            ],
            "stream": False,
            "format": "json"
        }
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()
            raw_content = data["message"]["content"]
            parsed = self._extract_json(raw_content)
            return parsed.get("blocks", [])

    def _merge_translations(
        self, 
        original_blocks: List[Dict[str, Any]], 
        translated_blocks: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        trans_map = {}
        for b in translated_blocks:
            b_id = b.get("id")
            # Support both "text" and "translated_text" keys in the returned JSON
            text_val = b.get("text") or b.get("translated_text", "")
            trans_map[str(b_id)] = text_val
            if isinstance(b_id, int):
                trans_map[b_id] = text_val

        merged = []
        for orig in original_blocks:
            b_id = orig["id"]
            orig_text = orig.get("text", "")
            translated_text = trans_map.get(b_id, trans_map.get(str(b_id), orig_text))
            item = dict(orig)
            item["translated_text"] = translated_text
            merged.append(item)
        return merged

ai_translator = AITranslator()
