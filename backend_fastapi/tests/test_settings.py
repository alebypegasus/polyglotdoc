import pytest
from httpx import AsyncClient, ASGITransport
from backend_fastapi.main import app

@pytest.mark.asyncio
async def test_settings_get_and_update():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Get settings
        get_resp = await client.get("/api/v1/settings")
        assert get_resp.status_code == 200
        data = get_resp.json()
        assert "ai_provider" in data
        assert "gemini_model" in data

        # Update settings
        payload = {
            "ai_provider": "google_translate_free",
            "gemini_api_key": "test_key_123",
            "gemini_model": "gemini-1.5-pro",
            "custom_system_prompt": "Prompt customizado de teste."
        }
        post_resp = await client.post("/api/v1/settings", json=payload)
        assert post_resp.status_code == 200
        assert post_resp.json()["provider"] == "google_translate_free"

@pytest.mark.asyncio
async def test_test_ai_connection_google_translate_free():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "provider": "google_translate_free"
        }
        resp = await client.post("/api/v1/settings/test-connection", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "Google Translate" in data["message"]
