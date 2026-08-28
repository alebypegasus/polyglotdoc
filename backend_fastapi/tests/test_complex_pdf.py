import pytest
import fitz
import tempfile
from pathlib import Path
from backend_fastapi.app.engine.pdf_processor import pdf_processor

@pytest.mark.asyncio
async def test_complex_pdf_dark_page_and_drop_cap_reconstruction():
    # Create a synthetic complex PDF with dark background and gold text
    doc = fitz.open()
    
    # Page 1: Dark background with gold header (like book cover / astrological wheel)
    p1 = doc.new_page(width=500, height=700)
    p1.draw_rect(fitz.Rect(0, 0, 500, 700), color=(0.05, 0.08, 0.15), fill=(0.05, 0.08, 0.15))
    p1.insert_text(fitz.Point(100, 200), "ASTROLOGY MAGICK", fontsize=24, color=(0.95, 0.80, 0.10))
    p1.insert_text(fitz.Point(120, 250), "Love yourself using magick", fontsize=14, color=(1.0, 1.0, 1.0))
    
    # Page 2: Drop cap + paragraph
    p2 = doc.new_page(width=500, height=700)
    p2.insert_text(fitz.Point(50, 100), "A", fontsize=32, color=(0.1, 0.1, 0.1))
    p2.insert_text(fitz.Point(75, 100), "strology has played a big role in my craft for six years.", fontsize=12, color=(0.1, 0.1, 0.1))
    
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp_in, \
         tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp_out:
        
        doc.save(tmp_in.name)
        doc.close()
        
        result = await pdf_processor.process_pdf(
            input_path=tmp_in.name,
            output_path=tmp_out.name,
            target_language="pt-br",
            source_language="en"
        )
        
        assert result["total_pages"] == 2
        assert Path(tmp_out.name).exists()
        
        # Verify output PDF can be opened and rendered
        out_doc = fitz.open(tmp_out.name)
        assert len(out_doc) == 2
        
        # Verify PNG rendering works on both pages
        png_p1 = pdf_processor.render_page_as_png(tmp_out.name, 1)
        assert len(png_p1) > 100
        
        png_p2 = pdf_processor.render_page_as_png(tmp_out.name, 2)
        assert len(png_p2) > 100
        
        out_doc.close()
        Path(tmp_in.name).unlink(missing_ok=True)
        Path(tmp_out.name).unlink(missing_ok=True)
