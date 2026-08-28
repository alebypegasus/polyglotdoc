<div align="center">

<img src="frontend_flutter/assets/icon/app_icon_256.png" alt="PolyGlotDoc AI Logo" width="128" height="128" style="border-radius: 24px;" />

# PolyGlotDoc AI

### Reconstrução Editorial e Tradução de Documentos de Alta Performance com IA

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://www.python.org)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20Windows%20|%20Linux%20|%20Android%20|%20iOS%20|%20Web-lightgrey.svg)](#-distribuição-e-instaladores)

**PolyGlotDoc AI** é uma plataforma de código aberto para tradução, leitura lado a lado e reconstrução tipográfica de livros, eBooks (EPUB/MOBI) e PDFs complexos, preservando com rigor cirúrgico a formatação original, vetores, ilustrações e famílias de fontes (*Serif, Sans-Serif, Monospace*).

[Instalação Rápida](#-instalação-e-execução) • [Modelos Suportados](#-ecossistema-de-modelos-de-ia) • [Instaladores](#-distribuição-e-instaladores) • [Documentação da API](#-documentação-da-api-backend)

</div>

---

## Principais Recursos

- **Preservação Tipográfica Avançada:** Mapeamento inteligente de fontes (*Times-Roman, Helvetica, Courier, Garamond, Baskerville, Palatino*) preservando pesos (*Regular, Bold, Italic, Bold-Italic*).
- **Tradução com Respeito a Bounding Boxes:** Algoritmo dinâmico de auto-fit que calibra o tamanho dos caracteres para que o texto traduzido nunca estoure as caixas delimitadoras originais.
- **Leitor Dividido Lado a Lado (Split Reader):** Visualização sincronizada da página original e traduzida com zoom e troca instantânea de documentos da fila.
- **Multi-Provedor de IA com Proteção de Cota (429 Fallback):**
  - **Google Gemini:** Suporte aos modelos `gemini-3.5-flash`, `gemini-3.5-flash-lite`, `gemini-3.6-flash`, `gemini-3.1-pro-preview`.
  - **OpenAI:** `gpt-4o`, `gpt-4o-mini`, `o3-mini`, `o1`, `gpt-4.5-preview`.
  - **DeepSeek:** `deepseek-chat` (V3), `deepseek-reasoner` (R1 com extração limpa de raciocínio).
  - **Groq LPU:** `llama-3.3-70b-versatile`, `llama-3.1-8b-instant` (>1.000 tokens/s).
  - **OpenRouter:** Centenas de modelos, incluindo opções 100% gratuitas (`:free`).
  - **Ollama Local:** 100% gratuito e privado, rodando localmente sem enviar dados para a nuvem.
  - **Google Translate Engine Nativo:** Gratuito, sem necessidade de chaves de API e sem limites de cota.
- **Diagnóstico com Modais:** Teste de latência e conexão em tempo real com mensagens de diagnóstico detalhadas e botão de cópia de logs.
- **Diálogo Nativo de Salvamento:** Salve os documentos traduzidos exatamente na pasta desejada com extensão `.pdf` / `.epub` garantida.

---

## Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    POLYGLOTDOC FRONTEND                     │
│    Flutter Multiplataforma (macOS, Windows, Linux, Mobile)  │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP / WebSockets Bidirecional
┌──────────────────────────────▼──────────────────────────────┐
│                    POLYGLOTDOC BACKEND                      │
│                  FastAPI Assíncrono (Python)                │
└───────┬──────────────────────┬──────────────────────┬───────┘
        │                      │                      │
┌───────▼────────┐     ┌───────▼────────┐     ┌───────▼───────┐
│ PyMuPDF Engine │     │ Redis / Memory │     │ AI Translator │
│  - OCR & Text  │     │  - Queue Task  │     │ - Gemini 3.5  │
│  - Typography  │     │  - Progress WS │     │ - DeepSeek R1 │
│  - Redactions  │     │                │     │ - OpenAI / O3 │
│  - Auto-fit    │     │                │     │ - Local Ollama│
└────────────────┘     └────────────────┘     └───────────────┘
```

---

## Ecossistema de Modelos de IA

### Opções Gratuitas e de Baixo Custo
| Provedor | Modelo | Categoria | Destaque |
| :--- | :--- | :---: | :--- |
| **Google Gemini** | `gemini-3.5-flash-lite` | Gratuito / Pago | Mais rápido da geração 3.5 com alto limite de requisições. |
| **Google Gemini** | `gemini-3.5-flash` | Gratuito / Pago | Modelo recomendado para equilíbrio entre raciocínio e velocidade. |
| **OpenRouter** | `deepseek/deepseek-r1:free` | 100% Gratuito | Raciocínio avançado sem custos. |
| **OpenRouter** | `meta-llama/llama-3.3-70b-instruct:free` | 100% Gratuito | Modelo 70B de alta capacidade. |
| **Groq** | `llama-3.1-8b-instant` | Gratuito / Pago | Inferência ultrarrápida (>1.000 tokens/s). |
| **Ollama** | `llama3.3:latest`, `deepseek-r1:8b`, `qwen2.5:7b` | 100% Local / Grátis | Privacidade total executada na sua máquina. |
| **Nativo** | `google_translate_free` | 100% Gratuito | Sem necessidade de API Key nem instalação local. |

### Opções Frontier e Raciocínio Profundo
| Provedor | Modelo | Destaque |
| :--- | :--- | :--- |
| **OpenAI** | `o3-mini`, `o1`, `gpt-4o`, `gpt-4.5-preview` | Raciocínio matemático e tradução editorial técnica. |
| **Anthropic** | `claude-3-7-sonnet-20250219`, `claude-3-5-sonnet-latest` | Raciocínio híbrido e tom literário natural. |
| **DeepSeek** | `deepseek-reasoner` (R1), `deepseek-chat` (V3) | Raciocínio estruturado com custo mínimo por token. |

---

## Distribuição e Instaladores

Para conveniência dos usuários, scripts automatizados e arquivos de instalador estão disponíveis na pasta `packaging/`:

### macOS (Universal DMG)
Compile o arquivo `.dmg` com link para a pasta `/Applications`:
```bash
./packaging/macos/build_dmg.sh
# O arquivo gerado estará em: dist/macos/PolyGlotDoc_AI_macOS_Universal.dmg
```

### Windows (Instalador .exe & Portable .zip)
Compile a versão portátil e o instalador Inno Setup:
```powershell
pwsh ./packaging/windows/build_windows.ps1
# O instalador InnoSetup pode ser compilado com:
iscc ./packaging/windows/installer.iss
```

### Linux (Pacotes .deb e .tar.gz)
```bash
./packaging/linux/build_linux.sh
# Os pacotes gerados estarão em: dist/linux/
```

### Android (APKs e AAB)
```bash
./packaging/android/build_apk.sh
# APKs por arquitetura (arm64-v8a, armeabi-v7a, x86_64) gerados em: dist/android/
```

---

## Instalação e Execução

### Opção 1: Via Docker Compose (Mais Rápido)
```bash
git clone https://github.com/alebypegasus/polyglotdoc.git
cd polyglotdoc
docker-compose up --build -d
```
O backend estará rodando em `http://localhost:8000`.

---

### Opção 2: Execução Local para Desenvolvimento

#### 1. Backend (FastAPI)
```bash
cd backend_fastapi
python3 -m venv .venv
source .venv/bin/activate  # No Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn backend_fastapi.main:app --reload --host 0.0.0.0 --port 8000
```

#### 2. Frontend (Flutter)
```bash
cd frontend_flutter
flutter pub get
flutter run -d macos  # Ou: windows, linux, chrome
```

---

## Documentação da API Backend

A API do PolyGlotDoc é 100% assíncrona e documentada via Swagger/OpenAPI. Ao iniciar o servidor, acesse:
- **Swagger UI:** `http://localhost:8000/docs`
- **ReDoc:** `http://localhost:8000/redoc`

### Endpoints Principais:
- `POST /api/v1/documents/upload` - Envio de arquivos (PDF/EPUB) com seleção de idioma alvo.
- `GET /api/v1/tasks` - Listagem de tarefas na fila com percentual de progresso.
- `GET /api/v1/tasks/{task_id}/download` - Download seguro do documento reconstruído.
- `GET /api/v1/tasks/{task_id}/pages/{page_num}/preview` - Visualização em imagem da página original/traduzida.
- `GET /api/v1/settings` - Consulta das configurações de IA ativas.
- `POST /api/v1/settings/test-connection` - Teste de latência e credenciais da API de IA.
- `WS /ws/progress/{client_id}` - Canal WebSocket de progresso em tempo real por página.

---

## Contribuição

Contribuições são muito bem-vindas! Consulte o nosso [Guia de Contribuição](CONTRIBUTING.md) e nosso [Código de Conduta](CODE_OF_CONDUCT.md) antes de enviar Pull Requests.

---

## Licença

Distribuído sob a licença **MIT**. Consulte o arquivo [LICENSE](LICENSE) para obter mais informações.
