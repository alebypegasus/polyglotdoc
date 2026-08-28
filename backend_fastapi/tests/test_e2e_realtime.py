import pytest
import io
import fitz
import asyncio
from httpx import AsyncClient, ASGITransport
from backend_fastapi.main import app

def create_multipage_pdf() -> bytes:
    doc = fitz.open()
    
    # Page 1
    p1 = doc.new_page()
    p1.insert_text((72, 100), "Chapter 1: Quantum Computing Foundations", fontsize=16)
    p1.insert_text((72, 140), "Artificial intelligence accelerates discovery in physics and engineering.", fontsize=11)
    
    # Page 2
    p2 = doc.new_page()
    p2.insert_text((72, 100), "Chapter 2: Neural Networks and Deep Learning", fontsize=16)
    p2.insert_text((72, 140), "High performance algorithms optimize data representations across dimensions.", fontsize=11)
    
    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes

@pytest.mark.asyncio
async def test_full_pipeline_multipage_pdf_with_strict_naming():
    pdf_bytes = create_multipage_pdf()
    
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        files = {
            "files": ("Clean_Code_Architecture.pdf", io.BytesIO(pdf_bytes), "application/pdf")
        }
        data = {
            "target_language": "PT-BR",
            "source_language": "en",
            "preserve_layout": "true",
            "client_id": "client_integration_test"
        }

        # 1. Upload
        upload_resp = await client.post("/api/v1/documents/upload", files=files, data=data)
        assert upload_resp.status_code == 201
        upload_json = upload_resp.json()
        
        task_info = upload_json["tasks"][0]
        task_id = task_info["task_id"]
        assert task_info["total_pages"] == 2
        assert task_info["output_filename"] == "Clean_Code_Architecture - Traduzido PTBR.pdf"

        # 2. Wait for completion
        for _ in range(40):
            status_resp = await client.get(f"/api/v1/tasks/{task_id}/status")
            assert status_resp.status_code == 200
            task_status = status_resp.json()
            if task_status["status"] == "completed":
                break
            await asyncio.sleep(0.1)

        assert task_status["status"] == "completed"
        assert task_status["current_page"] == 2
        assert task_status["percentage"] == 100.0

        # 3. Preview endpoint
        preview_resp = await client.get(f"/api/v1/tasks/{task_id}/preview")
        assert preview_resp.status_code == 200
        preview_data = preview_resp.json()
        assert preview_data["total_pages"] == 2
        assert len(preview_data["pages"]) == 2

        # 4. Download endpoint with strict naming validation
        download_resp = await client.get(f"/api/v1/tasks/{task_id}/download")
        assert download_resp.status_code == 200
        assert len(download_resp.content) > 0
        disp_header = download_resp.headers.get("content-disposition", "")
        assert "Clean_Code_Architecture" in disp_header and "PTBR.pdf" in disp_header
