class LanguageOption {
  final String code;
  final String name;
  final String flag;
  final String suffix;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.flag,
    required this.suffix,
  });

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(code: 'PT-BR', name: 'Português (Brasil)', flag: '🇧🇷', suffix: 'PTBR'),
    LanguageOption(code: 'EN-US', name: 'Inglês (EUA)', flag: '🇺🇸', suffix: 'EN'),
    LanguageOption(code: 'ES', name: 'Espanhol', flag: '🇪🇸', suffix: 'ES'),
    LanguageOption(code: 'FR', name: 'Francês', flag: '🇫🇷', suffix: 'FR'),
    LanguageOption(code: 'DE', name: 'Alemão', flag: '🇩🇪', suffix: 'DE'),
    LanguageOption(code: 'IT', name: 'Italiano', flag: '🇮🇹', suffix: 'IT'),
    LanguageOption(code: 'JA', name: 'Japonês', flag: '🇯🇵', suffix: 'JA'),
    LanguageOption(code: 'ZH', name: 'Mandarim', flag: '🇨🇳', suffix: 'ZH'),
    LanguageOption(code: 'RU', name: 'Russo', flag: '🇷🇺', suffix: 'RU'),
    LanguageOption(code: 'KO', name: 'Coreano', flag: '🇰🇷', suffix: 'KO'),
  ];
}
