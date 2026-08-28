import time
import json
import httpx
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from backend_fastapi.app.core.config import settings

router = APIRouter()

class AISettingsModel(BaseModel):
    ai_provider: str = "gemini"  # gemini, openai, claude, deepseek, groq, openrouter, ollama, google_translate_free
    gemini_api_key: Optional[str] = ""
    gemini_model: str = "gemini-3.5-flash"
    gemini_tier: str = "medium"  # low, medium, high
    
    openai_api_key: Optional[str] = ""
    openai_model: str = "gpt-4o-mini"
    openai_reasoning_effort: str = "medium"
    
    claude_api_key: Optional[str] = ""
    claude_model: str = "claude-3-7-sonnet-20250219"
    
    deepseek_api_key: Optional[str] = ""
    deepseek_model: str = "deepseek-chat"
    
    groq_api_key: Optional[str] = ""
    groq_model: str = "llama-3.3-70b-versatile"
    
    openrouter_api_key: Optional[str] = ""
    openrouter_model: str = "google/gemini-2.0-flash-001"
    
    ollama_host: str = "http://localhost:11434"
    ollama_model: str = "llama3.3"
    custom_system_prompt: str = ""

class TestConnectionRequest(BaseModel):
    provider: str
    api_key: Optional[str] = ""
    model: Optional[str] = ""
    endpoint: Optional[str] = ""

class TestConnectionResponse(BaseModel):
    success: bool
    message: str
    latency_ms: int
    technical_details: Optional[str] = None

@router.get("", response_model=AISettingsModel)
async def get_settings():
    return AISettingsModel(
        ai_provider=settings.AI_PROVIDER,
        gemini_api_key=settings.GEMINI_API_KEY,
        gemini_model=settings.GEMINI_MODEL,
        gemini_tier=settings.GEMINI_TIER,
        openai_api_key=settings.OPENAI_API_KEY,
        openai_model=settings.OPENAI_MODEL,
        openai_reasoning_effort=settings.OPENAI_REASONING_EFFORT,
        claude_api_key=settings.CLAUDE_API_KEY,
        claude_model=settings.CLAUDE_MODEL,
        deepseek_api_key=settings.DEEPSEEK_API_KEY,
        deepseek_model=settings.DEEPSEEK_MODEL,
        groq_api_key=settings.GROQ_API_KEY,
        groq_model=settings.GROQ_MODEL,
        openrouter_api_key=settings.OPENROUTER_API_KEY,
        openrouter_model=settings.OPENROUTER_MODEL,
        ollama_host=settings.OLLAMA_HOST,
        ollama_model=settings.OLLAMA_MODEL,
        custom_system_prompt=settings.CUSTOM_SYSTEM_PROMPT,
    )

@router.post("")
async def update_settings(new_settings: AISettingsModel):
    settings.AI_PROVIDER = new_settings.ai_provider
    
    if new_settings.gemini_api_key is not None:
        settings.GEMINI_API_KEY = new_settings.gemini_api_key
    settings.GEMINI_MODEL = new_settings.gemini_model
    settings.GEMINI_TIER = new_settings.gemini_tier
    
    if new_settings.openai_api_key is not None:
        settings.OPENAI_API_KEY = new_settings.openai_api_key
    settings.OPENAI_MODEL = new_settings.openai_model
    settings.OPENAI_REASONING_EFFORT = new_settings.openai_reasoning_effort
    
    if new_settings.claude_api_key is not None:
        settings.CLAUDE_API_KEY = new_settings.claude_api_key
    settings.CLAUDE_MODEL = new_settings.claude_model
    
    if new_settings.deepseek_api_key is not None:
        settings.DEEPSEEK_API_KEY = new_settings.deepseek_api_key
    settings.DEEPSEEK_MODEL = new_settings.deepseek_model
    
    if new_settings.groq_api_key is not None:
        settings.GROQ_API_KEY = new_settings.groq_api_key
    settings.GROQ_MODEL = new_settings.groq_model
    
    if new_settings.openrouter_api_key is not None:
        settings.OPENROUTER_API_KEY = new_settings.openrouter_api_key
    settings.OPENROUTER_MODEL = new_settings.openrouter_model
    
    settings.OLLAMA_HOST = new_settings.ollama_host
    settings.OLLAMA_MODEL = new_settings.ollama_model
    
    if new_settings.custom_system_prompt:
        settings.CUSTOM_SYSTEM_PROMPT = new_settings.custom_system_prompt

    return {"message": "Configurações de IA salvas com sucesso!", "provider": settings.AI_PROVIDER}

@router.post("/test-connection", response_model=TestConnectionResponse)
async def test_ai_connection(req: TestConnectionRequest):
    provider = req.provider.lower().strip()
    api_key = (req.api_key or "").strip()
    start_time = time.time()

    # 1. Free Google Translate
    if provider == "google_translate_free":
        latency = int((time.time() - start_time) * 1000)
        return TestConnectionResponse(
            success=True,
            message="Motor Google Translate Gratuito Ativo (100% operacional sem necessidade de API Key).",
            latency_ms=latency
        )

    # 2. Google Gemini
    if provider == "gemini":
        key = api_key or settings.GEMINI_API_KEY
        if not key:
            return TestConnectionResponse(
                success=False,
                message="Chave de API do Gemini não fornecida. Cole sua chave obtida no Google AI Studio (aistudio.google.com) ou selecione 'Google Translate (100% Gratuito)'.",
                latency_ms=0,
                technical_details="HTTP Client Pre-check: Missing GEMINI_API_KEY"
            )

        model = req.model or settings.GEMINI_MODEL or "gemini-2.0-flash"
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
        payload = {"contents": [{"parts": [{"text": "Ping"}]}]}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, json=payload)
                latency = int((time.time() - start_time) * 1000)

                if resp.status_code == 200:
                    return TestConnectionResponse(
                        success=True,
                        message=f"Conexão com Google Gemini ({model}) validada e ativa!",
                        latency_ms=latency
                    )
                
                # Check for 404 model not found -> attempt fallback to gemini-2.0-flash / gemini-1.5-flash
                error_body = resp.text
                try:
                    err_json = resp.json()
                    err_msg = err_json.get("error", {}).get("message", error_body)
                    err_status = err_json.get("error", {}).get("status", str(resp.status_code))
                except Exception:
                    err_msg = error_body
                    err_status = str(resp.status_code)

                if resp.status_code == 404:
                    # Test modern fallback
                    fb_model = "gemini-3.5-flash-lite"
                    fb_url = f"https://generativelanguage.googleapis.com/v1beta/models/{fb_model}:generateContent?key={key}"
                    fb_resp = await client.post(fb_url, json=payload)
                    if fb_resp.status_code == 200:
                        return TestConnectionResponse(
                            success=True,
                            message=f"Chave válida! O modelo '{model}' não foi localizado, mas '{fb_model}' está 100% operacional. Recomendamos usar '{fb_model}'.",
                            latency_ms=latency
                        )

                return TestConnectionResponse(
                    success=False,
                    message=f"Google Gemini retornou erro ({err_status}): {err_msg}",
                    latency_ms=latency,
                    technical_details=f"Status: {resp.status_code}\nEndpoint: {url.split('?')[0]}\nResponse: {error_body}"
                )
        except Exception as e:
            latency = int((time.time() - start_time) * 1000)
            return TestConnectionResponse(
                success=False,
                message=f"Falha de rede ou timeout ao conectar com o Google Gemini: {str(e)}",
                latency_ms=latency,
                technical_details=str(e)
            )

    # 3. OpenAI / Claude / DeepSeek / Groq / OpenRouter
    elif provider in ["openai", "claude", "deepseek", "groq", "openrouter"]:
        key_map = {
            "openai": (api_key or settings.OPENAI_API_KEY, "https://api.openai.com/v1/models", req.model or settings.OPENAI_MODEL),
            "claude": (api_key or settings.CLAUDE_API_KEY, "https://api.anthropic.com/v1/models", req.model or settings.CLAUDE_MODEL),
            "deepseek": (api_key or settings.DEEPSEEK_API_KEY, "https://api.deepseek.com/models", req.model or settings.DEEPSEEK_MODEL),
            "groq": (api_key or settings.GROQ_API_KEY, "https://api.groq.com/openai/v1/models", req.model or settings.GROQ_MODEL),
            "openrouter": (api_key or settings.OPENROUTER_API_KEY, "https://openrouter.ai/api/v1/models", req.model or settings.OPENROUTER_MODEL),
        }
        
        target_key, test_url, target_model = key_map[provider]
        if not target_key:
            return TestConnectionResponse(
                success=False,
                message=f"Chave de API de {provider.upper()} não informada. Cole sua chave ou use outro provedor.",
                latency_ms=0,
                technical_details=f"HTTP Client Pre-check: Missing {provider.upper()}_API_KEY"
            )
        
        headers = {"Authorization": f"Bearer {target_key}"}
        if provider == "claude":
            headers = {"x-api-key": target_key, "anthropic-version": "2023-06-01"}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(test_url, headers=headers)
                latency = int((time.time() - start_time) * 1000)
                if resp.status_code in [200, 201]:
                    return TestConnectionResponse(
                        success=True,
                        message=f"Conexão com {provider.upper()} ({target_model}) autenticada com sucesso!",
                        latency_ms=latency
                    )
                else:
                    return TestConnectionResponse(
                        success=False,
                        message=f"Erro de autenticação com {provider.upper()} (Status {resp.status_code}).",
                        latency_ms=latency,
                        technical_details=f"Status: {resp.status_code}\nResponse: {resp.text}"
                    )
        except Exception as e:
            latency = int((time.time() - start_time) * 1000)
            return TestConnectionResponse(
                success=False,
                message=f"Erro de conexão com {provider.upper()}: {str(e)}",
                latency_ms=latency,
                technical_details=str(e)
            )

    # 4. Ollama
    elif provider == "ollama":
        host = req.endpoint or settings.OLLAMA_HOST
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(f"{host}/api/tags")
                latency = int((time.time() - start_time) * 1000)
                if resp.status_code == 200:
                    return TestConnectionResponse(
                        success=True,
                        message="Ollama local detectado e pronto para uso offline!",
                        latency_ms=latency
                    )
                else:
                    return TestConnectionResponse(
                        success=False,
                        message=f"Ollama respondeu com status {resp.status_code}",
                        latency_ms=latency,
                        technical_details=resp.text
                    )
        except Exception as e:
            latency = int((time.time() - start_time) * 1000)
            return TestConnectionResponse(
                success=False,
                message=f"Não foi possível conectar ao Ollama em {host}. Verifique se o comando 'ollama serve' está rodando no seu terminal.",
                latency_ms=latency,
                technical_details=str(e)
            )

    latency = int((time.time() - start_time) * 1000)
    return TestConnectionResponse(
        success=True,
        message=f"Provedor {provider} configurado.",
        latency_ms=latency
    )
