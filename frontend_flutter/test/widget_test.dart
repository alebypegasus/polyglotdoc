import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter/core/constants/app_constants.dart';
import 'package:frontend_flutter/core/models/document_task.dart';
import 'package:frontend_flutter/core/services/api_service.dart';
import 'package:frontend_flutter/core/services/websocket_service.dart';
import 'package:frontend_flutter/main.dart';

class FakeApiService extends ApiService {
  @override
  Future<List<DocumentTask>> fetchAllTasks() async => [];

  @override
  Future<Map<String, dynamic>> getSettings() async => {
    'ai_provider': 'gemini',
    'gemini_model': 'gemini-1.5-flash',
    'gemini_api_key': 'mock_key',
    'custom_system_prompt': 'Mock prompt',
  };
}

class FakeWebSocketService extends WebSocketService {
  @override
  void connect(String clientId) {}
}

void main() {
  testWidgets('PolyGlotDoc App renders responsive dashboard and navigation tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeApiService()),
          webSocketServiceProvider.overrideWithValue(FakeWebSocketService()),
        ],
        child: const PolyGlotDocApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify App Name and core UI sections are present
    expect(find.text(AppConstants.appName), findsAtLeastNWidgets(1));
    expect(find.text('Configuração de Tradução'), findsAtLeastNWidgets(1));
    expect(find.text('Idioma de Destino:'), findsAtLeastNWidgets(1));

    // Test Navigation to "Configurações de IA"
    final settingsNav = find.text('Configurações de IA');
    expect(settingsNav, findsOneWidget);
    await tester.tap(settingsNav);
    await tester.pumpAndSettle();

    expect(find.text('Configurações de IA & Modelos'), findsOneWidget);
    expect(find.text('Testar Conexão de IA'), findsOneWidget);

    // Test Navigation to "Leitor Dividido"
    final readerNav = find.text('Leitor Dividido');
    expect(readerNav, findsOneWidget);
    await tester.tap(readerNav);
    await tester.pumpAndSettle();

    expect(find.text('Nenhum documento na fila ainda'), findsOneWidget);
  });
}
