from fastapi import APIRouter
from backend_fastapi.app.api.v1.endpoints import documents, websockets, settings

api_router = APIRouter()
api_router.include_router(documents.router, prefix="/documents", tags=["Documents"])
api_router.include_router(documents.router, tags=["Tasks"])
api_router.include_router(settings.router, prefix="/settings", tags=["Settings"])
api_router.include_router(websockets.router, tags=["WebSockets"])
