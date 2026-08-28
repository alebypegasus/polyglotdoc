from pathlib import Path
from backend_fastapi.app.core.config import settings

def get_target_language_suffix(target_language: str) -> tuple[str, str]:
    """
    Returns (action_word, language_code_uppercase)
    Example:
    'pt-br' -> ('Traduzido', 'PTBR')
    'en-us' -> ('Translated', 'EN')
    'es' -> ('Traducido', 'ES')
    'fr' -> ('Traduit', 'FR')
    'de' -> ('Übersetzt', 'DE')
    'it' -> ('Tradotto', 'IT')
    'ja' -> ('Translated', 'JA')
    'zh' -> ('Translated', 'ZH')
    """
    cleaned = target_language.strip().lower()
    suffix_code = settings.LANGUAGE_SUFFIX_MAP.get(cleaned, cleaned.upper().replace("-", ""))
    
    # Get localized translated word
    action_word = settings.LANGUAGE_WORD_MAP.get(suffix_code, "Traduzido")
    return action_word, suffix_code

def generate_translated_filename(original_filename: str, target_language: str) -> str:
    """
    Generates the standardized translated filename according to the strict rule:
    [NomeOriginal] - Traduzido [SIGLA_UPPERCASE].[extensao]
    
    Examples:
    Clean_Code.pdf + 'pt-br' -> 'Clean_Code - Traduzido PTBR.pdf'
    Manual_Usuario.epub + 'en' -> 'Manual_Usuario - Translated EN.epub'
    Relatorio_2026.docx + 'es' -> 'Relatorio_2026 - Traducido ES.docx'
    """
    path = Path(original_filename)
    stem = path.stem
    ext = path.suffix
    
    # Clean any preexisting translated suffixes if re-translating
    if " - Traduzido " in stem or " - Translated " in stem or " - Traducido " in stem or " - Traduit " in stem:
        stem = stem.split(" - ")[0]
        
    action_word, suffix_code = get_target_language_suffix(target_language)
    
    return f"{stem} - {action_word} {suffix_code}{ext}"
