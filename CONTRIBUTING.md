# Guia de Contribuição - PolyGlotDoc AI

Obrigado pelo seu interesse em contribuir com o **PolyGlotDoc AI**! Este é um projeto de código aberto dedicado a fornecer uma experiência de tradução e reconstrução editorial de documentos acessível, precisa e de alto desempenho.

---

## 🛠️ Como Começar

### Pré-requisitos
- **Flutter SDK** (v3.24 ou superior)
- **Python** (v3.11 ou superior)
- **Redis** (Opcional para filas distribuídas; fallback em memória incluído)

### 1. Clonando o Repositório
```bash
git clone https://github.com/alebypegasus/polyglotdoc.git
cd polyglotdoc
```

### 2. Inicializando o Backend
```bash
cd backend_fastapi
python -m venv .venv
source .venv/bin/activate  # No Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn backend_fastapi.main:app --reload --port 8000
```

### 3. Inicializando o Frontend
```bash
cd frontend_flutter
flutter pub get
flutter run -d macos  # ou windows, linux, chrome
```

---

## 📌 Padrões de Commit
Utilizamos a convenção do **Conventional Commits**:
- `feat:` Nova funcionalidade
- `fix:` Correção de bug
- `docs:` Alterações na documentação
- `style:` Formatação e estilo sem alteração de lógica
- `refactor:` Refatoração de código
- `test:` Adição ou correção de testes
- `chore:` Tarefas de manutenção e builds

---

## 🛡️ Fluxo de Pull Requests
1. Crie uma branch para a sua feature: `git checkout -b feature/minha-feature`.
2. Escreva testes ou valide suas alterações.
3. Certifique-se de que não haja linter errors (`flutter analyze` e `pytest`).
4. Abra um Pull Request com uma descrição clara do que foi implementado.
