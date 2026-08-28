import uuid
from pathlib import Path
from typing import List, Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, status, Response, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel

from backend_fastapi.app.services.task_manager import task_manager, TaskModel
from backend_fastapi.app.engine.pdf_processor import pdf_processor

router = APIRouter()

class UploadTaskResponse(BaseModel):
    task_id: str
    filename: str
    total_pages: int
    output_filename: str
    status: str

class BatchUploadResponse(BaseModel):
    batch_id: str
    tasks: List[UploadTaskResponse]

@router.post("/upload", response_model=BatchUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_documents(
    files: List[UploadFile] = File(...),
    target_language: str = Form("PT-BR"),
    source_language: str = Form("auto"),
    preserve_layout: bool = Form(True),
    client_id: str = Form("default")
):
    """
    Accepts one or more documents (.pdf, .epub, .mobi, .docx) for translation.
    Returns batch_id and list of created tasks with estimated total pages.
    """
    if not files:
        raise HTTPException(status_code=400, detail="Nenhum arquivo enviado.")

    batch_id = str(uuid.uuid4())
    task_responses = []

    for file in files:
        filename = file.filename or "document.pdf"
        file_bytes = await file.read()

        if len(file_bytes) == 0:
            continue

        task = task_manager.create_task(
            filename=filename,
            file_bytes=file_bytes,
            target_language=target_language,
            source_language=source_language,
            preserve_layout=preserve_layout,
            client_id=client_id,
            batch_id=batch_id
        )

        await task_manager.start_task_execution(task.task_id)

        task_responses.append(UploadTaskResponse(
            task_id=task.task_id,
            filename=task.filename,
            total_pages=task.total_pages,
            output_filename=task.output_filename,
            status=task.status
        ))

    if not task_responses:
        raise HTTPException(status_code=400, detail="Arquivos vazios ou inválidos.")

    return BatchUploadResponse(batch_id=batch_id, tasks=task_responses)


@router.get("/tasks/{task_id}/status", response_model=TaskModel)
async def get_task_status(task_id: str):
    """Returns the real-time progress and details of a translation task."""
    task = task_manager.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada.")
    return task


@router.get("/tasks/{task_id}/download")
async def download_translated_document(task_id: str):
    """
    Downloads the translated document with the strictly formatted filename:
    [NomeOriginal] - Traduzido [SIGLA_UPPERCASE].[extensao]
    """
    task = task_manager.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada.")

    if task.status != "completed":
        raise HTTPException(
            status_code=400, 
            detail=f"O documento ainda não está pronto para download. Status atual: {task.status}"
        )

    output_path = Path(task.output_filepath)
    if not output_path.exists():
        raise HTTPException(status_code=404, detail="Arquivo traduzido não encontrado no servidor.")

    return FileResponse(
        path=str(output_path),
        filename=task.output_filename,
        media_type="application/octet-stream"
    )


@router.get("/tasks/{task_id}/pages/{page_num}/image")
async def get_page_image(
    task_id: str, 
    page_num: int, 
    type: str = Query("original", pattern="^(original|translated)$"),
    dpi: int = 150
):

    """
    Renders and returns high-resolution PNG image of a document page
    (either original or translated version) for the visual split reader.
    """
    task = task_manager.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada.")

    target_filepath = task.original_filepath if type == "original" else task.output_filepath
    path_obj = Path(target_filepath)

    if not path_obj.exists():
        raise HTTPException(status_code=404, detail="Arquivo correspondente ainda não gerado ou não encontrado.")

    ext = path_obj.suffix.lower()
    if ext == ".pdf":
        try:
            png_bytes = pdf_processor.render_page_as_png(str(path_obj), page_num=page_num, dpi=dpi)
            return Response(content=png_bytes, media_type="image/png")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Erro ao renderizar imagem da página: {e}")
    else:
        raise HTTPException(status_code=400, detail="Pré-visualização em imagem disponível nativamente para arquivos PDF.")


@router.get("/tasks/{task_id}/preview")
async def get_task_preview(task_id: str):
    """Returns structured page comparison data (original vs translated blocks) for Reader view."""
    task = task_manager.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada.")
    
    return {
        "task_id": task.task_id,
        "filename": task.filename,
        "total_pages": task.total_pages,
        "pages": task.pages_preview
    }


@router.get("/tasks/batch/{batch_id}", response_model=List[TaskModel])
async def get_batch_tasks(batch_id: str):
    return task_manager.get_tasks_by_batch(batch_id)


@router.get("/tasks", response_model=List[TaskModel])
async def list_all_tasks():
    return task_manager.get_all_tasks()


@router.post("/tasks/{task_id}/retry")
async def retry_task(task_id: str):
    task = task_manager.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada.")
    
    task.status = "pending"
    task.error_message = None
    task.percentage = 0.0
    await task_manager.start_task_execution(task.task_id)
    return {"message": "Tarefa reiniciada com sucesso.", "task_id": task_id}
