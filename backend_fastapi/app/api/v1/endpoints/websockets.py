import asyncio
import json
import logging
from typing import Dict
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from backend_fastapi.app.core.redis_client import progress_hub

logger = logging.getLogger(__name__)
router = APIRouter()

@router.websocket("/ws/progress/{client_id}")
async def websocket_progress_endpoint(websocket: WebSocket, client_id: str):
    """
    WebSocket connection endpoint for real-time document translation progress events.
    Receives JSON events as tasks transition through pending, extracting, translating,
    reconstructing and completed.
    """
    await websocket.accept()
    logger.info(f"WebSocket client connected: {client_id}")

    queue: asyncio.Queue = asyncio.Queue()

    async def _on_event(payload: Dict):
        await queue.put(payload)

    await progress_hub.subscribe(client_id, _on_event)

    # Send initial connection confirmation
    await websocket.send_json({
        "type": "connection_established",
        "client_id": client_id,
        "message": "Conectado ao hub de eventos do PolyGlotDoc AI"
    })

    try:
        while True:
            # We wait either for incoming messages from client (e.g. ping) or outgoing events from queue
            receive_task = asyncio.create_task(websocket.receive_text())
            event_task = asyncio.create_task(queue.get())

            done, pending = await asyncio.wait(
                [receive_task, event_task],
                return_when=asyncio.FIRST_COMPLETED
            )

            for task in pending:
                task.cancel()

            if receive_task in done:
                try:
                    client_msg = receive_task.result()
                    # Handle ping / keepalive
                    if client_msg.strip() in ["ping", '{"type":"ping"}']:
                        await websocket.send_json({"type": "pong"})
                except Exception:
                    break

            if event_task in done:
                payload = event_task.result()
                await websocket.send_json(payload)

    except WebSocketDisconnect:
        logger.info(f"WebSocket client disconnected: {client_id}")
    except Exception as e:
        logger.warning(f"WebSocket connection error for {client_id}: {e}")
    finally:
        progress_hub.unsubscribe(client_id, _on_event)
