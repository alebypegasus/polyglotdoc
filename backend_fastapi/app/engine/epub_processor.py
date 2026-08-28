import logging
from pathlib import Path
from typing import List, Dict, Any, Callable, Optional
import ebooklib
from ebooklib import epub
from bs4 import BeautifulSoup, NavigableString
from backend_fastapi.app.services.ai_translator import ai_translator, DocumentTranslationContext

logger = logging.getLogger(__name__)

class EPUBProcessor:
    def get_document_info(self, file_path: str) -> Dict[str, Any]:
        try:
            book = epub.read_epub(file_path)
            items = list(book.get_items_of_type(ebooklib.ITEM_DOCUMENT))
            title = book.get_metadata("DC", "title")
            title_str = title[0][0] if title else Path(file_path).stem
            author = book.get_metadata("DC", "creator")
            author_str = author[0][0] if author else "Desconhecido"
            return {
                "total_pages": max(1, len(items)),
                "title": title_str,
                "author": author_str
            }
        except Exception as e:
            logger.warning(f"Failed to read EPUB info: {e}")
            return {
                "total_pages": 1,
                "title": Path(file_path).stem,
                "author": "Desconhecido"
            }

    async def process_epub(
        self,
        input_path: str,
        output_path: str,
        target_language: str,
        source_language: str = "auto",
        progress_callback: Optional[Callable[[Dict[str, Any]], Any]] = None
    ) -> Dict[str, Any]:
        book = epub.read_epub(input_path)
        items = list(book.get_items_of_type(ebooklib.ITEM_DOCUMENT))
        total_items = len(items)
        context = DocumentTranslationContext(source_language=source_language, target_language=target_language)

        for idx, item in enumerate(items):
            current_num = idx + 1
            if progress_callback:
                await progress_callback({
                    "status": "extracting",
                    "current_page": current_num,
                    "total_pages": total_items,
                    "percentage": round((idx / total_items) * 100, 1),
                    "message": f"Processando capítulo {current_num}/{total_items}"
                })

            content = item.get_content().decode("utf-8", errors="ignore")
            soup = BeautifulSoup(content, "html.parser")

            # Collect text tags
            tags_to_translate = soup.find_all(["p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "td", "th"])
            blocks = []
            valid_tags = []

            for t_idx, tag in enumerate(tags_to_translate):
                text = tag.get_text().strip()
                if text:
                    blocks.append({"id": t_idx, "text": text, "bbox": [0, 0, 100, 20]})
                    valid_tags.append((t_idx, tag))

            if blocks:
                if progress_callback:
                    await progress_callback({
                        "status": "translating",
                        "current_page": current_num,
                        "total_pages": total_items,
                        "percentage": round(((idx + 0.5) / total_items) * 100, 1),
                        "message": f"Traduzindo capítulo {current_num}/{total_items}"
                    })

                translated_blocks = await ai_translator.translate_blocks(
                    blocks=blocks,
                    context=context,
                    page_num=current_num,
                    total_pages=total_items
                )

                trans_map = {b["id"]: b.get("translated_text", "") for b in translated_blocks}

                for t_idx, tag in valid_tags:
                    if t_idx in trans_map:
                        tag.string = trans_map[t_idx]

                item.set_content(str(soup).encode("utf-8"))

            if progress_callback:
                await progress_callback({
                    "status": "reconstructing",
                    "current_page": current_num,
                    "total_pages": total_items,
                    "percentage": round(((idx + 0.9) / total_items) * 100, 1),
                    "message": f"Reconstruindo capítulo {current_num}/{total_items}"
                })

        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        epub.write_epub(output_path, book)

        return {
            "total_pages": total_items,
            "output_path": output_path
        }

epub_processor = EPUBProcessor()
