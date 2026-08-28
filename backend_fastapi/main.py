import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend_fastapi.app.core.config import settings
from backend_fastapi.app.core.redis_client import progress_hub
from backend_fastapi.app.api.v1.api import api_router
from backend_fastapi.app.api.v1.endpoints.websockets import router as ws_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("polyglotdoc")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing PolyGlotDoc AI Backend...")
    await progress_hub.initialize()
    yield
    logger.info("Shutting down PolyGlotDoc AI Backend...")
    await progress_hub.close()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend assíncrono de tradução, leitura e reconstrução inteligente de documentos página a página com IA.",
    lifespan=lifespan
)

# CORS middleware for Flutter (Web, Desktop, Mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(api_router, prefix=settings.API_V1_STR)
app.include_router(ws_router)  # /ws/progress/{client_id}

@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "redis_connected": progress_hub._is_redis_connected
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend_fastapi.main:app", host="0.0.0.0", port=8000, reload=True)
