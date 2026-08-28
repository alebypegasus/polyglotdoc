from backend_fastapi.app.engine.naming import generate_translated_filename, get_target_language_suffix

def test_naming_rule_ptbr():
    filename = "Clean_Code.pdf"
    res = generate_translated_filename(filename, "pt-br")
    assert res == "Clean_Code - Traduzido PTBR.pdf"

def test_naming_rule_en():
    filename = "Manual_Usuario.epub"
    res = generate_translated_filename(filename, "en")
    assert res == "Manual_Usuario - Translated EN.epub"

def test_naming_rule_es():
    filename = "Relatorio_2026.docx"
    res = generate_translated_filename(filename, "es")
    assert res == "Relatorio_2026 - Traducido ES.docx"

def test_naming_rule_fr():
    filename = "Architecture_Guide.pdf"
    res = generate_translated_filename(filename, "fr")
    assert res == "Architecture_Guide - Traduit FR.pdf"

def test_naming_rule_de():
    filename = "System_Design.pdf"
    res = generate_translated_filename(filename, "de")
    assert res == "System_Design - Übersetzt DE.pdf"

def test_suffix_helper():
    word, code = get_target_language_suffix("pt-br")
    assert word == "Traduzido"
    assert code == "PTBR"
