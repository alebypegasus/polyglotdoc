import asyncio
import hashlib
import logging
import time
import uuid
from pathlib import Path
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field

from backend_fastapi.app.core.config import settings
from backend_fastapi.app.core.redis_client import progress_hub
from backend_fastapi.app.engine.naming import generate_translated_filename
from backend_fastapi.app.engine.pdf_processor import pdf_processor
from backend_fastapi.app.engine.docx_processor import docx_processor
from backend_fastapi.app.engine.epub_processor import epub_processor

logger = logging.getLogger(__name__)

class TaskModel(BaseModel):
    task_id: str
    client_id: str = "default"
    batch_id: Optional[str] = None
    filename: str
    original_filepath: str
    output_filename: str
    output_filepath: str
    target_language: str
    source_language: str = "auto"
    preserve_layout: bool = True
    status: str = "pending"  # pending, extracting, translating, reconstructing, completed, failed
    current_page: int = 0
    total_pages: int = 1
    percentage: float = 0.0
    estimated_seconds_remaining: Optional[int] = None
    error_message: Optional[str] = None
    file_size_bytes: int = 0
    checksum: str = ""
    created_at: float = Field(default_factory=time.time)
    updated_at: float = Field(default_factory=time.time)
    pages_preview: List[Dict[str, Any]] = []

class TaskManager:
    def __init__(self):
        self._tasks: Dict[str, TaskModel] = {}
        self._checksum_map: Dict[str, str] = {}  # sha256 -> task_id

    def create_task(
        self,
        filename: str,
        file_bytes: bytes,
        target_language: str,
        source_language: str = "auto",
        preserve_layout: bool = True,
        client_id: str = "default",
        batch_id: Optional[str] = None
    ) -> TaskModel:
        task_id = str(uuid.uuid4())
        checksum = hashlib.sha256(file_bytes).hexdigest()

        # Save uploaded file
        upload_ext = Path(filename).suffix.lower()
        original_filepath = settings.UPLOADS_DIR / f"{task_id}_{filename}"
        with open(original_filepath, "wb") as f:
            f.write(file_bytes)

        # Generate mandatory translated output filename
        output_filename = generate_translated_filename(filename, target_language)
        output_filepath = settings.PROCESSED_DIR / f"{task_id}_{output_filename}"

        # Estimate initial total pages
        total_pages = 1
        try:
            if upload_ext == ".pdf":
                info = pdf_processor.get_document_info(str(original_filepath))
                total_pages = info["total_pages"]
            elif upload_ext in [".epub", ".mobi"]:
                info = epub_processor.get_document_info(str(original_filepath))
                total_pages = info["total_pages"]
            elif upload_ext in [".docx", ".doc"]:
                info = docx_processor.get_document_info(str(original_filepath))
                total_pages = info["total_pages"]
        except Exception as e:
            logger.warning(f"Error inspecting document structure: {e}")

        task = TaskModel(
            task_id=task_id,
            client_id=client_id,
            batch_id=batch_id,
            filename=filename,
            original_filepath=str(original_filepath),
            output_filename=output_filename,
            output_filepath=str(output_filepath),
            target_language=target_language,
            source_language=source_language,
            preserve_layout=preserve_layout,
            status="pending",
            current_page=0,
            total_pages=total_pages,
            percentage=0.0,
            file_size_bytes=len(file_bytes),
            checksum=checksum
        )

        self._tasks[task_id] = task
        self._checksum_map[checksum] = task_id
        return task

    def get_task(self, task_id: str) -> Optional[TaskModel]:
        return self._tasks.get(task_id)

    def get_tasks_by_batch(self, batch_id: str) -> List[TaskModel]:
        return [t for t in self._tasks.values() if t.batch_id == batch_id]

    def get_all_tasks(self) -> List[TaskModel]:
        return sorted(list(self._tasks.values()), key=lambda x: x.created_at, reverse=True)

    async def update_task_progress(
        self,
        task_id: str,
        status: str,
        current_page: int,
        total_pages: int,
        percentage: float,
        error_message: Optional[str] = None
    ):
        task = self._tasks.get(task_id)
        if not task:
            return

        task.status = status
        task.current_page = current_page
        task.total_pages = total_pages
        task.percentage = percentage
        task.updated_at = time.time()
        if error_message:
            task.error_message = error_message

        # Calculate estimated remaining seconds
        elapsed = task.updated_at - task.created_at
        if percentage > 0 and percentage < 100:
            total_estimated = elapsed / (percentage / 100.0)
            task.estimated_seconds_remaining = max(0, int(total_estimated - elapsed))
        elif percentage >= 100:
            task.estimated_seconds_remaining = 0

        # Construct exact WebSocket event payload requested in the prompt specification
        event_payload = {
            "task_id": task.task_id,
            "filename": task.filename,
            "status": task.status,
            "current_page": task.current_page,
            "total_pages": task.total_pages,
            "percentage": task.percentage,
            "target_language": task.target_language,
            "estimated_seconds_remaining": task.estimated_seconds_remaining or 0
        }

        # Broadcast via Redis Hub / WebSockets
        await progress_hub.publish_progress(task.client_id, event_payload)

    async def start_task_execution(self, task_id: str):
        """Starts asynchronous execution of document translation pipeline."""
        asyncio.create_task(self._execute_pipeline(task_id))

    async def _execute_pipeline(self, task_id: str):
        task = self._tasks.get(task_id)
        if not task:
            return

        async def _progress_callback(info: Dict[str, Any]):
            await self.update_task_progress(
                task_id=task.task_id,
                status=info["status"],
                current_page=info["current_page"],
                total_pages=info["total_pages"],
                percentage=info["percentage"]
            )

        try:
            ext = Path(task.filename).suffix.lower()

            if ext == ".pdf":
                res = await pdf_processor.process_pdf(
                    input_path=task.original_filepath,
                    output_path=task.output_filepath,
                    target_language=task.target_language,
                    source_language=task.source_language,
                    progress_callback=_progress_callback
                )
                task.pages_preview = res.get("pages_data", [])
            elif ext in [".docx", ".doc"]:
                await docx_processor.process_docx(
                    input_path=task.original_filepath,
                    output_path=task.output_filepath,
                    target_language=task.target_language,
                    source_language=task.source_language,
                    progress_callback=_progress_callback
                )
            elif ext in [".epub", ".mobi"]:
                await epub_processor.process_epub(
                    input_path=task.original_filepath,
                    output_path=task.output_filepath,
                    target_language=task.target_language,
                    source_language=task.source_language,
                    progress_callback=_progress_callback
                )
            else:
                raise ValueError(f"Formato de arquivo não suportado: {ext}")

            # Mark complete
            await self.update_task_progress(
                task_id=task.task_id,
                status="completed",
                current_page=task.total_pages,
                total_pages=task.total_pages,
                percentage=100.0
            )

        except Exception as e:
            logger.error(f"Execution failed for task {task_id}: {e}", exc_info=True)
            await self.update_task_progress(
                task_id=task.task_id,
                status="failed",
                current_page=task.current_page,
                total_pages=task.total_pages,
                percentage=task.percentage,
                error_message=str(e)
            )

task_manager = TaskManager()
