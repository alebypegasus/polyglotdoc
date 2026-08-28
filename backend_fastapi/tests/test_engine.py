import pytest
import fitz
import tempfile
from pathlib import Path
from unittest.mock import patch
from backend_fastapi.app.engine.pdf_processor import pdf_processor
from backend_fastapi.app.services.ai_translator import ai_translator, DocumentTranslationContext

async def _mock_real_translation(blocks, source_lang, target_lang):
    translations = {
        "Chapter 1: Quantum Physics Introduction": "Capítulo 1: Introdução à Física Quântica",
        "This document explains artificial intelligence and machine learning principles.": "Este documento explica princípios de Inteligência Artificial.",
        "Chapter 2: System Architecture": "Capítulo 2: Arquitetura do Sistema",
        "High performance software engineering in modern data pipelines.": "Engenharia de software em pipelines modernos.",
        "Chapter 1: Overview and System Architecture": "Capítulo 1: Visão Geral e Arquitetura do Sistema",
        "This is high performance software": "Este é um software de alta performance"
    }
    return [
        {"id": b["id"], "translated_text": translations.get(b["text"].strip(), f"Traduzido: {b['text']}")}
        for b in blocks
    ]

@pytest.mark.asyncio
async def test_pdf_extraction_and_reconstruction():
    # 1. Create a dummy multi-page PDF with PyMuPDF
    doc = fitz.open()
    page1 = doc.new_page()
    page1.insert_text((50, 72), "Chapter 1: Quantum Physics Introduction", fontsize=14)
    page1.insert_text((50, 100), "This document explains artificial intelligence and machine learning principles.", fontsize=11)
    
    page2 = doc.new_page()
    page2.insert_text((50, 72), "Chapter 2: System Architecture", fontsize=14)
    page2.insert_text((50, 100), "High performance software engineering in modern data pipelines.", fontsize=11)

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp_in:
        in_path = tmp_in.name
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp_out:
        out_path = tmp_out.name

    doc.save(in_path)
    doc.close()

    # 2. Check info
    info = pdf_processor.get_document_info(in_path)
    assert info["total_pages"] == 2

    # 3. Process PDF translation
    progress_events = []
    async def _on_progress(event):
        progress_events.append(event)

    with patch.object(ai_translator, "_real_translation_deep_translator", side_effect=_mock_real_translation):
        res = await pdf_processor.process_pdf(
            input_path=in_path,
            output_path=out_path,
            target_language="pt-br",
            progress_callback=_on_progress
        )

    assert res["total_pages"] == 2
    assert Path(out_path).exists()
    assert len(progress_events) > 0

    # 4. Verify reconstructed PDF can be opened and contains translated text
    translated_doc = fitz.open(out_path)
    assert len(translated_doc) == 2
    text_p1 = translated_doc[0].get_text()
    assert "Capítulo" in text_p1 or "Inteligência Artificial" in text_p1 or "Introdução" in text_p1
    translated_doc.close()

    # Cleanup
    Path(in_path).unlink(missing_ok=True)
    Path(out_path).unlink(missing_ok=True)


@pytest.mark.asyncio
async def test_ai_translator_contextual():
    context = DocumentTranslationContext(source_language="en", target_language="pt-br")
    blocks = [
        {"id": 0, "text": "Chapter 1: Overview and System Architecture"},
        {"id": 1, "text": "This is high performance software"}
    ]
    with patch.object(ai_translator, "_real_translation_deep_translator", side_effect=_mock_real_translation):
        translated = await ai_translator.translate_blocks(blocks, context, page_num=1, total_pages=1)
    assert len(translated) == 2
    assert translated[0]["translated_text"] != ""
    assert "Capítulo" in translated[0]["translated_text"] or "Arquitetura" in translated[0]["translated_text"]
