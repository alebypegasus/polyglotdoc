import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_dialog_helper.dart';

class AISettingsView extends ConsumerStatefulWidget {
  const AISettingsView({super.key});

  @override
  ConsumerState<AISettingsView> createState() => _AISettingsViewState();
}

class _AISettingsViewState extends ConsumerState<AISettingsView> {
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _obscureKey = true;

  String _selectedProvider = 'gemini';
  String _selectedTier = 'medium'; // low, medium, high

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  Map<String, dynamic>? _testResult;

  final Map<String, List<String>> _modelPresets = {
    'gemini': [
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-3.5-flash-lite',
      'gemini-3.1-pro-preview',
      'gemini-3.1-flash-lite',
      'gemini-3-flash-preview',
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-2.5-flash-lite',
    ],
    'openai': [
      'gpt-4o',
      'gpt-4o-mini',
      'o3-mini',
      'o1',
      'o1-mini',
      'gpt-4.5-preview',
      'chatgpt-4o-latest',
    ],
    'claude': [
      'claude-3-7-sonnet-20250219',
      'claude-3-5-sonnet-latest',
      'claude-3-5-haiku-latest',
      'claude-3-opus-latest',
    ],
    'deepseek': [
      'deepseek-chat',
      'deepseek-reasoner',
    ],
    'groq': [
      'llama-3.3-70b-versatile',
      'deepseek-r1-distill-llama-70b',
      'llama-3.1-8b-instant',
      'qwen-2.5-32b',
      'gemma2-9b-it',
      'mixtral-8x7b-32768',
    ],
    'openrouter': [
      'deepseek/deepseek-r1:free',
      'deepseek/deepseek-chat:free',
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemini-2.0-flash-exp:free',
      'anthropic/claude-3.7-sonnet',
      'openai/gpt-4o',
      'openai/o3-mini',
      'deepseek/deepseek-r1',
      'deepseek/deepseek-chat',
      'meta-llama/llama-3.3-70b-instruct',
    ],
    'ollama': [
      'llama3.3:latest',
      'llama3.2:latest',
      'deepseek-r1:8b',
      'deepseek-r1:14b',
      'qwen2.5:7b',
      'qwen2.5:14b',
      'mistral:latest',
      'phi4:latest',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _endpointController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(apiServiceProvider).getSettings();
      setState(() {
        _selectedProvider = data['ai_provider'] ?? 'gemini';
        _selectedTier = data['gemini_tier'] ?? 'medium';
        _modelController.text = data['gemini_model'] ?? 'gemini-2.0-flash';
        _promptController.text = data['custom_system_prompt'] ?? '';
        _apiKeyController.text = data['gemini_api_key'] ?? '';
        _endpointController.text = data['ollama_host'] ?? 'http://localhost:11434';
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onProviderChanged(String provider) {
    setState(() {
      _selectedProvider = provider;
      _testResult = null;
      final presets = _modelPresets[provider];
      if (presets != null && presets.isNotEmpty) {
        _modelController.text = presets.first;
      }
      if (provider == 'ollama') {
        _endpointController.text = 'http://localhost:11434';
      }
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final req = {
        'provider': _selectedProvider,
        'api_key': _apiKeyController.text.trim(),
        'model': _modelController.text.trim(),
        'endpoint': _endpointController.text.trim(),
      };
      final res = await ref.read(apiServiceProvider).testAIConnection(req);
      setState(() {
        _testResult = res;
        _isTesting = false;
      });

      final success = res['success'] == true;
      if (!success && mounted) {
        ErrorDialogHelper.showErrorModal(
          context: context,
          title: 'Diagnóstico de Conexão com IA',
          message: res['message'] ?? 'Falha na comunicação com o provedor de IA selecionado.',
          technicalDetails: res['technical_details'] ?? res['message'],
          actionLabel: _selectedProvider != 'google_translate_free'
              ? 'Usar Google Translate (100% Grátis)'
              : null,
          onAction: _selectedProvider != 'google_translate_free'
              ? () {
                  _onProviderChanged('google_translate_free');
                  _saveSettings();
                }
              : null,
        );
      }
    } catch (e) {
      setState(() {
        _testResult = {
          'success': false,
          'message': 'Erro de rede ou servidor ao testar conexão: $e',
          'latency_ms': 0
        };
        _isTesting = false;
      });

      if (mounted) {
        ErrorDialogHelper.showErrorModal(
          context: context,
          title: 'Erro de Conexão',
          message: 'Não foi possível se comunicar com o backend ou a API externa.',
          technicalDetails: e.toString(),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'ai_provider': _selectedProvider,
        'gemini_api_key': _selectedProvider == 'gemini' ? _apiKeyController.text.trim() : null,
        'gemini_model': _selectedProvider == 'gemini' ? _modelController.text.trim() : 'gemini-2.0-flash',
        'gemini_tier': _selectedTier,
        'openai_api_key': _selectedProvider == 'openai' ? _apiKeyController.text.trim() : null,
        'openai_model': _selectedProvider == 'openai' ? _modelController.text.trim() : 'gpt-4o-mini',
        'openai_reasoning_effort': _selectedTier,
        'claude_api_key': _selectedProvider == 'claude' ? _apiKeyController.text.trim() : null,
        'claude_model': _selectedProvider == 'claude' ? _modelController.text.trim() : 'claude-3-7-sonnet-20250219',
        'deepseek_api_key': _selectedProvider == 'deepseek' ? _apiKeyController.text.trim() : null,
        'deepseek_model': _selectedProvider == 'deepseek' ? _modelController.text.trim() : 'deepseek-chat',
        'groq_api_key': _selectedProvider == 'groq' ? _apiKeyController.text.trim() : null,
        'groq_model': _selectedProvider == 'groq' ? _modelController.text.trim() : 'llama-3.3-70b-versatile',
        'openrouter_api_key': _selectedProvider == 'openrouter' ? _apiKeyController.text.trim() : null,
        'openrouter_model': _selectedProvider == 'openrouter' ? _modelController.text.trim() : 'google/gemini-2.0-flash-001',
        'ollama_host': _endpointController.text.trim(),
        'ollama_model': _modelController.text.trim(),
        'custom_system_prompt': _promptController.text.trim(),
      };

      await ref.read(apiServiceProvider).saveSettings(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                SizedBox(width: 8),
                Text('Configurações de IA salvas com sucesso!'),
              ],
            ),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorDialogHelper.showErrorModal(
          context: context,
          title: 'Erro ao Salvar Configurações',
          message: 'Ocorreu uma falha ao persistir as configurações no servidor.',
          technicalDetails: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent));
    }

    final currentPresets = _modelPresets[_selectedProvider] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.primaryLight, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurações de IA & Modelos Modernos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Configure provedores de última geração (Gemini 2.5/2.0, Claude 3.7, GPT-4o, DeepSeek, Groq)',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Provider Selector Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecione o Provedor de IA:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildProviderChip('gemini', 'Google Gemini (2.0 / 2.5)', Icons.auto_awesome_rounded, isPopular: true),
                    _buildProviderChip('google_translate_free', 'Google Translate (100% Gratuito)', Icons.g_translate_rounded, isFree: true),
                    _buildProviderChip('claude', 'Claude (3.7 Sonnet / Thinking)', Icons.bolt_rounded),
                    _buildProviderChip('openai', 'OpenAI (GPT-4o / o3-mini)', Icons.psychology_rounded),
                    _buildProviderChip('deepseek', 'DeepSeek (V3 / R1)', Icons.hub_rounded),
                    _buildProviderChip('groq', 'Groq (Llama 3.3 70B / Free Tier)', Icons.speed_rounded, isFree: true),
                    _buildProviderChip('openrouter', 'OpenRouter (Multi-IA)', Icons.cloud_sync_rounded),
                    _buildProviderChip('ollama', 'Ollama (Local Offline / Gratuito)', Icons.computer_rounded, isFree: true),
                  ],
                ),

                const SizedBox(height: 20),

                // Reasoning / Performance Tier Selector
                if (_selectedProvider != 'google_translate_free') ...[
                  const Text(
                    'Nível de Precisão & Raciocínio (Thinking Tier):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTierChip('low', 'Baixo / Rápido', 'Ideal para manuais técnicos e tabelas simples'),
                      const SizedBox(width: 8),
                      _buildTierChip('medium', 'Médio / Editorial', 'Equilíbrio perfeito de velocidade e estilo'),
                      const SizedBox(width: 8),
                      _buildTierChip('high', 'Alto / Raciocínio Profundo', 'Máxima fidelidade para livros e literatura'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // API Key input
                if (_selectedProvider != 'google_translate_free' && _selectedProvider != 'ollama') ...[
                  Text(
                    'Chave de API (${_selectedProvider.toUpperCase()} API KEY):',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: _selectedProvider == 'gemini'
                          ? 'Cole sua chave AIzaSy... do Google AI Studio'
                          : 'Cole sua chave de API aqui...',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Ollama Endpoint
                if (_selectedProvider == 'ollama') ...[
                  const Text(
                    'Endpoint Ollama Host:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      hintText: 'http://localhost:11434',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Model input with quick preset chips
                if (_selectedProvider != 'google_translate_free') ...[
                  const Text(
                    'Modelo de Tradução:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      hintText: 'Digite ou clique em um preset abaixo...',
                    ),
                  ),
                  if (currentPresets.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: currentPresets.map((preset) {
                        final isCurrent = _modelController.text.trim() == preset;
                        String displayLabel = preset;
                        IconData iconData = Icons.psychology_outlined;

                        if (preset == 'gemini-3.5-flash-lite') {
                          displayLabel = '3.5 Flash-Lite (Alta Cota)';
                          iconData = Icons.bolt_rounded;
                        } else if (preset == 'gemini-3.5-flash') {
                          displayLabel = '3.5 Flash (Recomendado)';
                          iconData = Icons.star_outline_rounded;
                        } else if (preset == 'gemini-3.6-flash') {
                          displayLabel = '3.6 Flash (Mais Recente)';
                          iconData = Icons.speed_rounded;
                        } else if (preset == 'gemini-3.1-pro-preview') {
                          displayLabel = '3.1 Pro (Raciocínio)';
                          iconData = Icons.auto_awesome_rounded;
                        } else if (preset.endsWith(':free')) {
                          displayLabel = '${preset.replaceAll(':free', '')} (Grátis)';
                          iconData = Icons.card_giftcard_rounded;
                        } else if (preset == 'gpt-4o-mini') {
                          displayLabel = 'gpt-4o-mini (Econômico)';
                          iconData = Icons.electric_bolt_rounded;
                        } else if (preset == 'claude-3-7-sonnet-20250219') {
                          displayLabel = 'claude-3.7-sonnet (Híbrido)';
                          iconData = Icons.science_outlined;
                        }

                        return ActionChip(
                          avatar: Icon(
                            iconData,
                            size: 14,
                            color: isCurrent ? AppColors.cyanAccent : AppColors.textMuted,
                          ),
                          label: Text(
                            displayLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent ? AppColors.cyanAccent : AppColors.textSecondary,
                            ),
                          ),
                          backgroundColor: isCurrent ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                          side: BorderSide(
                            color: isCurrent ? AppColors.primaryLight : AppColors.border,
                          ),
                          onPressed: () => setState(() => _modelController.text = preset),
                        );
                      }).toList(),
                    ),
                    if (_selectedProvider == 'gemini') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.cyanAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Dica de Cota: Para contas gratuitas com limite de requisições por minuto (RPM), use gemini-3.5-flash-lite ou gemini-3.5-flash. O PolyGlotDoc AI possui retry automático com espera e fallback para evitar falhas.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                ],

                // Test Connection Button
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent),
                            )
                          : const Icon(Icons.network_ping_rounded, size: 18),
                      label: Text(_isTesting ? 'Testando Conexão...' : 'Testar Conexão de IA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cyanAccent,
                        side: const BorderSide(color: AppColors.cyanAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),

                if (_testResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_testResult!['success'] == true)
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_testResult!['success'] == true)
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (_testResult!['success'] == true) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: (_testResult!['success'] == true) ? AppColors.success : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_testResult!['message']} (${_testResult!['latency_ms'] ?? 0} ms)',
                            style: TextStyle(
                              fontSize: 13,
                              color: (_testResult!['success'] == true) ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_testResult!['success'] != true)
                          TextButton(
                            onPressed: () {
                              ErrorDialogHelper.showErrorModal(
                                context: context,
                                title: 'Diagnóstico de Conexão com IA',
                                message: _testResult!['message']?.toString() ?? 'Falha ao conectar.',
                                technicalDetails: _testResult!['technical_details']?.toString() ?? _testResult!['message']?.toString(),
                                actionLabel: 'Usar Google Translate (100% Gratuito)',
                                onAction: () {
                                  _onProviderChanged('google_translate_free');
                                  _saveSettings();
                                },
                              );
                            },
                            child: const Text('Ver Modal de Diagnóstico', style: TextStyle(fontSize: 11, color: AppColors.cyanAccent)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Custom System Prompt
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Prompt de Sistema Editorial:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _promptController.text =
                              "Você é um Tradutor Editorial Sênior, Localizador Técnico e Especialista em Engenharia de Diagramação (Desktop Publishing).\n\n"
                              "Sua missão é traduzir o conteúdo textual fornecido do idioma [IDIOMA_ORIGEM] para [IDIOMA_DESTINO], respeitando com rigor cirúrgico a formatação original, a densidade de caracteres e o layout da página.\n\n"
                              "---\n\n"
                              "### 1. REGRAS CRÍTICAS DE DIAGRAMAÇÃO E FORMATAÇÃO:\n"
                              "- Preservação Estrutural: Mantenha intactas todas as quebras de linha (\\n, \\r), marcações estruturais, tags de formatação (HTML/Markdown/XML) e placeholders de substituição (ex: {{var}}, %s, [REF-1]).\n"
                              "- Restrição de Espaço (Text Expansion/Shrinkage): Adequar o vocabulário e a sintaxe para que o volume do texto traduzido não estoure a caixa delimitadora (bounding box) original. Evite redundâncias se o idioma de destino tender a expandir (ex: EN -> PTBR).\n"
                              "- Elementos Inalteráveis: NÃO traduza nomes próprios de marcas, variáveis de código, URLs, caminhos de arquivo, siglas técnicas consagradas ou fórmulas matemáticas.\n\n"
                              "---\n\n"
                              "### 2. CONSISTÊNCIA EDITORIAL:\n"
                              "- Registro e Tom: Mantenha o tom da obra original (técnico, literário, acadêmico ou corporativo).\n"
                              "- Glossário Contextual: Mantenha consistência com os termos traduzidos nas páginas anteriores:\n"
                              "  [INSERIR_GLOSSARIO_OU_CONTEXTO_ANTERIOR]\n\n"
                              "---\n\n"
                              "### 3. FORMATO DE SAÍDA OBRIGATÓRIO:\n"
                              "- Responda ESTRITAMENTE em formato JSON válido, sem blocos de código Markdown adicionais, sem preâmbulos, sem cumprimentos e sem explicações.\n"
                              "- Mantenha a mesma estrutura de chaves/IDs recebida na entrada.\n\n"
                              "Exemplo de Entrada:\n"
                              "{\n"
                              '  "page_number": 12,\n'
                              '  "blocks": [\n'
                              '    {"id": "b1", "text": "Chapter 1: Quantum Dynamics\\nIntroduction to wave functions."}\n'
                              "  ]\n"
                              "}\n\n"
                              "Exemplo de Saída Esperada:\n"
                              "{\n"
                              '  "page_number": 12,\n'
                              '  "blocks": [\n'
                              '    {"id": "b1", "text": "Capítulo 1: Dinâmica Quântica\\nIntrodução às funções de onda."}\n'
                              "  ]\n"
                              "}";
                        });
                      },
                      child: const Text('Restaurar Padrão', style: TextStyle(fontSize: 12, color: AppColors.cyanAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Instruções para o tradutor de IA...',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Save Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Salvar Configurações'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String value, String label, IconData icon, {bool isPopular = false, bool isFree = false}) {
    final isSelected = _selectedProvider == value;

    return InkWell(
      onTap: () => _onProviderChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? AppColors.cyanAccent : AppColors.textMuted, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            if (isFree) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('GRÁTIS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierChip(String tier, String label, String tooltip) {
    final isSelected = _selectedTier == tier;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _selectedTier = tier),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.cyanAccent.withValues(alpha: 0.15) : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.cyanAccent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
