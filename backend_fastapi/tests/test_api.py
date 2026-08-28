import pytest
import io
import fitz
import asyncio
from httpx import AsyncClient, ASGITransport
from backend_fastapi.main import app

def create_sample_pdf_bytes() -> bytes:
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((50, 72), "Chapter 1: Artificial Intelligence Guide", fontsize=14)
    page.insert_text((50, 100), "Fast processing for documents and eBooks.", fontsize=11)
    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes

@pytest.mark.asyncio
async def test_health_check():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "PolyGlotDoc AI"

@pytest.mark.asyncio
async def test_upload_and_download_flow():
    pdf_bytes = create_sample_pdf_bytes()
    
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        files = {
            "files": ("Quantum_Physics_Guide.pdf", io.BytesIO(pdf_bytes), "application/pdf")
        }
        data = {
            "target_language": "PT-BR",
            "source_language": "en",
            "preserve_layout": "true",
            "client_id": "test_client_1"
        }

        # 1. Upload
        upload_resp = await client.post("/api/v1/documents/upload", files=files, data=data)
        assert upload_resp.status_code == 201
        upload_data = upload_resp.json()
        assert "batch_id" in upload_data
        assert len(upload_data["tasks"]) == 1
        
        task_info = upload_data["tasks"][0]
        task_id = task_info["task_id"]
        assert task_info["output_filename"] == "Quantum_Physics_Guide - Traduzido PTBR.pdf"

        # 2. Wait for async processing to complete (small document takes < 1s)
        for _ in range(20):
            status_resp = await client.get(f"/api/v1/tasks/{task_id}/status")
            assert status_resp.status_code == 200
            task_status = status_resp.json()
            if task_status["status"] == "completed":
                break
            await asyncio.sleep(0.1)

        assert task_status["status"] == "completed"
        assert task_status["percentage"] == 100.0

        # 3. Download translated file
        download_resp = await client.get(f"/api/v1/tasks/{task_id}/download")
        assert download_resp.status_code == 200
        assert len(download_resp.content) > 0
        disp = download_resp.headers.get("content-disposition", "")
        assert "Quantum_Physics_Guide" in disp and "PTBR.pdf" in disp

