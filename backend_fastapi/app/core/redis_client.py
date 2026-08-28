import json
import logging
import asyncio
from typing import Dict, Set, Callable, Any, Optional
import redis.asyncio as aioredis
from backend_fastapi.app.core.config import settings

logger = logging.getLogger(__name__)

class ProgressHub:
    """
    Pub/Sub hub that uses Redis when available, with an automatic
    in-memory fallback for standalone execution and testing.
    """
    def __init__(self):
        self._redis: Optional[aioredis.Redis] = None
        self._subscribers: Dict[str, Set[Callable[[Dict[str, Any]], Any]]] = {}
        self._is_redis_connected = False
        self._listener_task: Optional[asyncio.Task] = None

    async def initialize(self):
        try:
            self._redis = aioredis.from_url(
                settings.REDIS_URL, 
                encoding="utf-8", 
                decode_responses=True,
                socket_connect_timeout=2.0
            )
            # Test ping
            await self._redis.ping()
            self._is_redis_connected = True
            logger.info("Connected to Redis Pub/Sub successfully.")
            self._listener_task = asyncio.create_task(self._listen_redis_channel())
        except Exception as e:
            self._is_redis_connected = False
            self._redis = None
            logger.warning(f"Redis not available ({e}). Using In-Memory fallback for WebSockets.")

    async def _listen_redis_channel(self):
        """Listens on Redis Pub/Sub channel and broadcasts to local WebSocket clients."""
        try:
            pubsub = self._redis.pubsub()
            await pubsub.subscribe(settings.REDIS_CHANNEL_PROGRESS)
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    client_id = data.get("client_id")
                    payload = data.get("payload", {})
                    await self._notify_subscribers(client_id, payload)
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"Error in Redis listener task: {e}")

    async def publish_progress(self, client_id: str, payload: Dict[str, Any]):
        """Publish a progress event for a client."""
        if self._is_redis_connected and self._redis:
            try:
                msg = json.dumps({"client_id": client_id, "payload": payload})
                await self._redis.publish(settings.REDIS_CHANNEL_PROGRESS, msg)
            except Exception as e:
                logger.error(f"Redis publish failed ({e}). Falling back to local subscribers.")
                await self._notify_subscribers(client_id, payload)
        else:
            await self._notify_subscribers(client_id, payload)

    async def subscribe(self, client_id: str, callback: Callable[[Dict[str, Any]], Any]):
        """Register a subscriber callback for a client_id (or '*' for all)."""
        if client_id not in self._subscribers:
            self._subscribers[client_id] = set()
        self._subscribers[client_id].add(callback)

    def unsubscribe(self, client_id: str, callback: Callable[[Dict[str, Any]], Any]):
        """Unregister a subscriber callback."""
        if client_id in self._subscribers:
            self._subscribers[client_id].discard(callback)
            if not self._subscribers[client_id]:
                del self._subscribers[client_id]

    async def _notify_subscribers(self, client_id: str, payload: Dict[str, Any]):
        """Dispatches message to registered callbacks."""
        targets = []
        if client_id in self._subscribers:
            targets.extend(list(self._subscribers[client_id]))
        if "*" in self._subscribers:
            targets.extend(list(self._subscribers["*"]))
            
        for cb in targets:
            try:
                if asyncio.iscoroutinefunction(cb):
                    await cb(payload)
                else:
                    cb(payload)
            except Exception as e:
                logger.error(f"Failed to dispatch to subscriber: {e}")

    async def close(self):
        if self._listener_task:
            self._listener_task.cancel()
        if self._redis:
            await self._redis.close()

progress_hub = ProgressHub()
