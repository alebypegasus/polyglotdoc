import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List, Dict

BASE_DIR = Path(__file__).resolve().parent.parent.parent

DEFAULT_EDITORIAL_PROMPT = """Você é um Tradutor Editorial Sênior, Localizador Técnico e Especialista em Engenharia de Diagramação (Desktop Publishing).

Sua missão é traduzir o conteúdo textual fornecido do idioma [IDIOMA_ORIGEM] para [IDIOMA_DESTINO], respeitando com rigor cirúrgico a formatação original, a densidade de caracteres e o layout da página.

---

### 1. REGRAS CRÍTICAS DE DIAGRAMAÇÃO E FORMATAÇÃO:
- Preservação Estrutural: Mantenha intactas todas as quebras de linha (\\n, \\r), marcações estruturais, tags de formatação (HTML/Markdown/XML) e placeholders de substituição (ex: {{var}}, %s, [REF-1]).
- Restrição de Espaço (Text Expansion/Shrinkage): Adequar o vocabulário e a sintaxe para que o volume do texto traduzido não estoure a caixa delimitadora (bounding box) original. Evite redundâncias se o idioma de destino tender a expandir (ex: EN -> PTBR).
- Elementos Inalteráveis: NÃO traduza nomes próprios de marcas, variáveis de código, URLs, caminhos de arquivo, siglas técnicas consagradas ou fórmulas matemáticas.

---

### 2. CONSISTÊNCIA EDITORIAL:
- Registro e Tom: Mantenha o tom da obra original (técnico, literário, acadêmico ou corporativo).
- Glossário Contextual: Mantenha consistência com os termos traduzidos nas páginas anteriores:
  [INSERIR_GLOSSARIO_OU_CONTEXTO_ANTERIOR]

---

### 3. FORMATO DE SAÍDA OBRIGATÓRIO:
- Responda ESTRITAMENTE em formato JSON válido, sem blocos de código Markdown adicionais, sem preâmbulos, sem cumprimentos e sem explicações.
- Mantenha a mesma estrutura de chaves/IDs recebida na entrada.

Exemplo de Entrada:
{
  "page_number": 12,
  "blocks": [
    {"id": "b1", "text": "Chapter 1: Quantum Dynamics\\nIntroduction to wave functions."}
  ]
}

Exemplo de Saída Esperada:
{
  "page_number": 12,
  "blocks": [
    {"id": "b1", "text": "Capítulo 1: Dinâmica Quântica\\nIntrodução às funções de onda."}
  ]
}"""

class Settings(BaseSettings):
    PROJECT_NAME: str = "PolyGlotDoc AI"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Storage settings
    STORAGE_DIR: Path = BASE_DIR / "storage"
    UPLOADS_DIR: Path = BASE_DIR / "storage" / "uploads"
    PROCESSED_DIR: Path = BASE_DIR / "storage" / "processed"
    
    # Redis configuration
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_CHANNEL_PROGRESS: str = "polyglotdoc:progress"
    
    # AI Translation configuration
    AI_PROVIDER: str = "gemini"  # gemini, openai, claude, deepseek, groq, openrouter, ollama, google_translate_free
    
    # Google Gemini Models (Oficiais: gemini-3.6-flash, gemini-3.5-flash, gemini-3.5-flash-lite, gemini-3.1-pro-preview, gemini-3.1-flash-lite, gemini-2.5-flash, gemini-2.5-pro)
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.5-flash"
    GEMINI_TIER: str = "medium"  # low, medium, high
    
    # OpenAI Models (gpt-4o, o3-mini, o1)
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o-mini"
    OPENAI_REASONING_EFFORT: str = "medium"  # low, medium, high
    
    # Anthropic Claude
    CLAUDE_API_KEY: str = ""
    CLAUDE_MODEL: str = "claude-3-7-sonnet-20250219"
    
    # DeepSeek
    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_MODEL: str = "deepseek-chat"
    
    # Groq (Ultra-fast / Free tier)
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    
    # OpenRouter
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_MODEL: str = "google/gemini-2.0-flash-001"
    
    # Ollama Local (Offline / Free)
    OLLAMA_HOST: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3.3"
    
    CUSTOM_SYSTEM_PROMPT: str = DEFAULT_EDITORIAL_PROMPT

    # CORS
    BACKEND_CORS_ORIGINS: List[str] = ["*"]
    
    # Limits
    MAX_UPLOAD_SIZE_MB: int = 500
    
    # Supported Languages & Suffix Code Map
    LANGUAGE_SUFFIX_MAP: Dict[str, str] = {
        "pt-br": "PTBR",
        "pt": "PTBR",
        "portuguese": "PTBR",
        "en-us": "EN",
        "en": "EN",
        "english": "EN",
        "es": "ES",
        "es-es": "ES",
        "spanish": "ES",
        "fr": "FR",
        "french": "FR",
        "de": "DE",
        "german": "DE",
        "it": "IT",
        "italian": "IT",
        "ja": "JA",
        "japanese": "JA",
        "zh": "ZH",
        "chinese": "ZH",
        "ru": "RU",
        "russian": "RU",
        "ko": "KO",
        "korean": "KO",
    }
    
    # Language prefix word map
    LANGUAGE_WORD_MAP: Dict[str, str] = {
        "PTBR": "Traduzido",
        "EN": "Translated",
        "ES": "Traducido",
        "FR": "Traduit",
        "DE": "Übersetzt",
        "IT": "Tradotto",
        "JA": "Translated",
        "ZH": "Translated",
    }

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

settings = Settings()

# Ensure storage directories exist
os.makedirs(settings.STORAGE_DIR, exist_ok=True)
os.makedirs(settings.UPLOADS_DIR, exist_ok=True)
os.makedirs(settings.PROCESSED_DIR, exist_ok=True)
