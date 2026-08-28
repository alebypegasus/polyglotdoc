import fitz  # PyMuPDF
import logging
from pathlib import Path
from typing import List, Dict, Any, Callable, Optional, Tuple
from backend_fastapi.app.services.ai_translator import ai_translator, DocumentTranslationContext

logger = logging.getLogger(__name__)

class PDFProcessor:
    def __init__(self):
        pass

    def get_document_info(self, file_path: str) -> Dict[str, Any]:
        """Returns total pages and metadata from PDF."""
        doc = fitz.open(file_path)
        total_pages = len(doc)
        meta = doc.metadata or {}
        doc.close()
        return {
            "total_pages": total_pages,
            "title": meta.get("title") or Path(file_path).stem,
            "author": meta.get("author", "Desconhecido"),
        }

    def render_page_as_png(self, file_path: str, page_num: int, dpi: int = 150) -> bytes:
        """Renders a specific PDF page as high-resolution PNG bytes."""
        doc = fitz.open(file_path)
        try:
            page_idx = max(0, min(page_num - 1, len(doc) - 1))
            page = doc[page_idx]
            pix = page.get_pixmap(dpi=dpi)
            return pix.tobytes("png")
        finally:
            doc.close()

    def _resolve_best_font(self, font_name: str, is_bold: bool = False, is_italic: bool = False) -> str:
        """
        Maps the extracted font name and typography style to the closest matching Base-14 PDF font:
        - Serif (Times, Garamond, Georgia, Minion, Baskerville, Cinzel, Palatino, etc.)
        - Sans-Serif (Helvetica, Arial, Roboto, Inter, Futura, Calibri, etc.)
        - Monospace (Courier, Monaco, Consolas, Menlo, Code, etc.)
        """
        name_lower = (font_name or "").lower()
        
        # Detect bold / italic from name or flags
        if not is_bold:
            is_bold = any(b in name_lower for b in ["bold", "black", "heavy", "medium", "semibold", "demi", "-bd", "bld"])
        if not is_italic:
            is_italic = any(i in name_lower for i in ["italic", "oblique", "-it", "slanted", "ita"])

        # Detect Monospace
        if any(m in name_lower for m in ["courier", "mono", "consolas", "code", "menlo", "typewriter"]):
            if is_bold and is_italic:
                return "cobi"
            elif is_bold:
                return "cobo"
            elif is_italic:
                return "coit"
            return "cour"

        # Detect Serif
        if any(s in name_lower for s in [
            "times", "serif", "garamond", "georgia", "minion", "baskerville",
            "palatino", "cambria", "book", "cinzel", "caslon", "didot", "bodoni",
            "cormorant", "playfair", "merriweather", "lora", "roman", "antiqua", "ptserif"
        ]):
            if is_bold and is_italic:
                return "tibi"
            elif is_bold:
                return "tibo"
            elif is_italic:
                return "tiit"
            return "tiro"

        # Default Sans-Serif
        if is_bold and is_italic:
            return "hebi"
        elif is_bold:
            return "hebo"
        elif is_italic:
            return "heit"
        return "helv"

    def _sample_background_color(self, pix: fitz.Pixmap, bbox: fitz.Rect) -> Tuple[float, float, float]:
        """
        Samples the average background color around the perimeter of a bounding box
        to ensure redaction blends seamlessly on dark, colored or illustrated pages.
        """
        try:
            w, h = pix.width, pix.height
            x0 = max(0, min(int(bbox.x0), w - 1))
            y0 = max(0, min(int(bbox.y0), h - 1))
            x1 = max(0, min(int(bbox.x1), w - 1))
            y1 = max(0, min(int(bbox.y1), h - 1))

            sample_points = [
                (x0, y0), (x1, y0), (x0, y1), (x1, y1),
                (max(0, x0 - 2), max(0, y0 - 2)),
                (min(w - 1, x1 + 2), min(h - 1, y1 + 2)),
            ]

            r_total, g_total, b_total, count = 0, 0, 0, 0
            for px, py in sample_points:
                pixel = pix.pixel(px, py)
                if len(pixel) >= 3:
                    r_total += pixel[0]
                    g_total += pixel[1]
                    b_total += pixel[2]
                    count += 1

            if count > 0:
                return (r_total / (count * 255.0), g_total / (count * 255.0), b_total / (count * 255.0))
            return (1.0, 1.0, 1.0)
        except Exception:
            return (1.0, 1.0, 1.0)

    def extract_blocks_from_page(self, page: fitz.Page) -> List[Dict[str, Any]]:
        """
        Extracts structural text blocks with bounding boxes (x0, y0, x1, y1),
        font sizes, colors, typography styles (serif/sans/mono, bold, italic),
        alignment and merges drop-caps.
        """
        text_dict = page.get_text("dict")
        raw_blocks = []
        block_id = 0

        page_width = page.rect.width

        for b in text_dict.get("blocks", []):
            if b.get("type") == 0:  # Text block
                block_text_parts = []
                font_sizes = []
                font_colors = []
                font_names = []
                is_bold = False
                is_italic = False
                
                for line in b.get("lines", []):
                    line_texts = []
                    for span in line.get("spans", []):
                        text = span.get("text", "")
                        if text:
                            line_texts.append(text)
                            if span.get("size"):
                                font_sizes.append(span.get("size"))
                            if span.get("color"):
                                c = span.get("color")
                                if isinstance(c, int):
                                    r = ((c >> 16) & 255) / 255.0
                                    g = ((c >> 8) & 255) / 255.0
                                    bl = (c & 255) / 255.0
                                    font_colors.append((r, g, bl))
                            if span.get("font"):
                                font_names.append(span.get("font"))
                            flags = span.get("flags", 0)
                            if flags & 2:
                                is_italic = True
                            if flags & 16:
                                is_bold = True
                            
                    if line_texts:
                        block_text_parts.append(" ".join(line_texts))

                full_text = "\n".join(block_text_parts).strip()
                if full_text:
                    bbox = b.get("bbox")  # (x0, y0, x1, y1)
                    avg_size = sum(font_sizes) / len(font_sizes) if font_sizes else 11.0
                    
                    # Dominant font color
                    if font_colors:
                        avg_color = (
                            sum(c[0] for c in font_colors) / len(font_colors),
                            sum(c[1] for c in font_colors) / len(font_colors),
                            sum(c[2] for c in font_colors) / len(font_colors),
                        )
                    else:
                        avg_color = (0.05, 0.05, 0.05)

                    # Dominant font name
                    primary_font = font_names[0] if font_names else "helv"
                    resolved_font = self._resolve_best_font(primary_font, is_bold, is_italic)

                    # Determine alignment (center if horizontally balanced in box/page)
                    box_center = (bbox[0] + bbox[2]) / 2.0
                    is_centered = abs(box_center - (page_width / 2.0)) < 40 and len(full_text) < 80

                    raw_blocks.append({
                        "id": block_id,
                        "text": full_text,
                        "bbox": list(bbox),
                        "font_size": avg_size,
                        "font_name": resolved_font,
                        "font_color": avg_color,
                        "align": 1 if is_centered else 0,
                    })
                    block_id += 1

        # Post-process: Merge drop caps (e.g. single large initial letter "A", "T", "Y", "M", etc.)
        merged_blocks = []
        i = 0
        while i < len(raw_blocks):
            curr = raw_blocks[i]
            if (len(curr["text"].strip()) == 1 and curr["text"].strip().isalpha() 
                and i + 1 < len(raw_blocks)):
                nxt = raw_blocks[i + 1]
                if nxt["bbox"][1] <= curr["bbox"][3] + 15 and nxt["bbox"][0] >= curr["bbox"][0] - 10:
                    combined_text = curr["text"].strip() + nxt["text"]
                    combined_bbox = [
                        min(curr["bbox"][0], nxt["bbox"][0]),
                        min(curr["bbox"][1], nxt["bbox"][1]),
                        max(curr["bbox"][2], nxt["bbox"][2]),
                        max(curr["bbox"][3], nxt["bbox"][3])
                    ]
                    merged_blocks.append({
                        "id": curr["id"],
                        "text": combined_text,
                        "bbox": combined_bbox,
                        "font_size": nxt["font_size"],
                        "font_name": nxt["font_name"],
                        "font_color": nxt["font_color"],
                        "align": nxt["align"],
                    })
                    i += 2
                    continue
            merged_blocks.append(curr)
            i += 1

        return merged_blocks

    def _insert_autofit_text(
        self,
        page: fitz.Page,
        rect: fitz.Rect,
        text: str,
        base_font_size: float,
        font_color: Tuple[float, float, float],
        font_name: str = "helv",
        align: int = 0
    ):
        """
        Iteratively scales font size down to ensure translated text fits perfectly inside bounding box
        while using the exact matching font typography (Serif / Sans / Mono / Bold / Italic).
        """
        scales = [1.0, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.60, 0.55, 0.50]
        r, g, b = font_color
        text_color = (r, g, b)

        # 1. Try with the matching font family
        for scale in scales:
            font_size = max(5.0, base_font_size * scale)
            try:
                rc = page.insert_textbox(
                    rect,
                    text,
                    fontsize=font_size,
                    fontname=font_name,
                    color=text_color,
                    align=align
                )
                if rc >= 0:
                    return
            except Exception:
                break

        # 2. Fallback to helv if custom font name had issue
        if font_name != "helv":
            for scale in scales:
                font_size = max(5.0, base_font_size * scale)
                try:
                    rc = page.insert_textbox(
                        rect,
                        text,
                        fontsize=font_size,
                        fontname="helv",
                        color=text_color,
                        align=align
                    )
                    if rc >= 0:
                        return
                except Exception:
                    pass

        # Final minimum size fallback
        try:
            page.insert_textbox(
                rect,
                text,
                fontsize=5.0,
                fontname="helv",
                color=text_color,
                align=align
            )
        except Exception as e:
            logger.warning(f"Failed to insert text in bbox {rect}: {e}")

    async def process_pdf(
        self,
        input_path: str,
        output_path: str,
        target_language: str,
        source_language: str = "auto",
        progress_callback: Optional[Callable[[Dict[str, Any]], Any]] = None
    ) -> Dict[str, Any]:
        """
        Processes each page of the PDF: extracts text, translates with AI,
        samples background color to redact cleanly, writes translated text with auto-fit,
        exact color matching and typography preservation (Serif, Sans, Mono, Bold, Italic),
        and saves the reconstructed PDF.
        """
        doc = fitz.open(input_path)
        total_pages = len(doc)
        context = DocumentTranslationContext(source_language=source_language, target_language=target_language)
        
        pages_data = []

        try:
            for page_index in range(total_pages):
                current_page_num = page_index + 1
                page = doc[page_index]

                # 1. Notify Extracting
                if progress_callback:
                    await progress_callback({
                        "status": "extracting",
                        "current_page": current_page_num,
                        "total_pages": total_pages,
                        "percentage": round(((page_index) / total_pages) * 100, 1),
                        "message": f"Extraindo layout e tipografia da página {current_page_num}/{total_pages}"
                    })

                blocks = self.extract_blocks_from_page(page)

                # Render page pixmap to sample accurate background colors
                pix = page.get_pixmap(dpi=72)

                # 2. Notify Translating
                if progress_callback:
                    await progress_callback({
                        "status": "translating",
                        "current_page": current_page_num,
                        "total_pages": total_pages,
                        "percentage": round(((page_index + 0.4) / total_pages) * 100, 1),
                        "message": f"Traduzindo conteúdo da página {current_page_num}/{total_pages}"
                    })

                translated_blocks = await ai_translator.translate_blocks(
                    blocks=blocks,
                    context=context,
                    page_num=current_page_num,
                    total_pages=total_pages
                )

                # 3. Notify Reconstructing
                if progress_callback:
                    await progress_callback({
                        "status": "reconstructing",
                        "current_page": current_page_num,
                        "total_pages": total_pages,
                        "percentage": round(((page_index + 0.8) / total_pages) * 100, 1),
                        "message": f"Reconstruindo página {current_page_num}/{total_pages} com fonte original"
                    })

                # Redact old text blocks using sampled background color
                for b in blocks:
                    rect = fitz.Rect(b["bbox"])
                    bg_color = self._sample_background_color(pix, rect)
                    page.add_redact_annot(rect, fill=bg_color)
                
                page.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)

                # Draw translated text with typography preservation and auto-fit
                for tb in translated_blocks:
                    rect = fitz.Rect(tb["bbox"])
                    trans_text = tb.get("translated_text", "")
                    font_size = tb.get("font_size", 10.0)
                    font_name = tb.get("font_name", "helv")
                    font_color = tb.get("font_color", (0.05, 0.05, 0.05))
                    align = tb.get("align", 0)

                    self._insert_autofit_text(
                        page=page,
                        rect=rect,
                        text=trans_text,
                        base_font_size=font_size,
                        font_color=font_color,
                        font_name=font_name,
                        align=align
                    )

                pages_data.append({
                    "page_number": current_page_num,
                    "original_blocks": blocks,
                    "translated_blocks": translated_blocks
                })

            # Save the final translated PDF with optimization
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)
            doc.save(output_path, garbage=4, deflate=True)
            
            return {
                "total_pages": total_pages,
                "pages_data": pages_data,
                "output_path": output_path
            }
        finally:
            doc.close()

pdf_processor = PDFProcessor()
