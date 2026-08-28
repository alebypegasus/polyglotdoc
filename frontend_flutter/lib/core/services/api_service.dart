import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/document_task.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Uploads single or multiple document files to the backend
  Future<List<DocumentTask>> uploadFiles({
    required List<PlatformFile> files,
    required String targetLanguage,
    String sourceLanguage = 'auto',
    bool preserveLayout = true,
    required String clientId,
  }) async {
    final uri = Uri.parse(AppConstants.uploadUrl);
    final request = http.MultipartRequest('POST', uri);

    request.fields['target_language'] = targetLanguage;
    request.fields['source_language'] = sourceLanguage;
    request.fields['preserve_layout'] = preserveLayout.toString();
    request.fields['client_id'] = clientId;

    for (final file in files) {
      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path!,
            filename: file.name,
          ),
        );
      }
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final batchId = data['batch_id'] as String?;
      final tasksRaw = data['tasks'] as List<dynamic>;

      return tasksRaw.map((t) {
        return DocumentTask(
          taskId: t['task_id'],
          clientId: clientId,
          batchId: batchId,
          filename: t['filename'],
          outputFilename: t['output_filename'],
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
          preserveLayout: preserveLayout,
          status: TaskStatus.fromString(t['status'] ?? 'pending'),
          totalPages: t['total_pages'] ?? 1,
        );
      }).toList();
    } else {
      throw Exception('Falha no upload (${response.statusCode}): ${response.body}');
    }
  }

  /// Fetches all active tasks
  Future<List<DocumentTask>> fetchAllTasks() async {
    final uri = Uri.parse(AppConstants.tasksUrl);
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final list = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list.map((item) => DocumentTask.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Erro ao buscar tarefas: ${response.statusCode}');
    }
  }

  /// Fetches page comparison preview data for split reader
  Future<Map<String, dynamic>> fetchTaskPreview(String taskId) async {
    final uri = Uri.parse(AppConstants.taskPreviewUrl(taskId));
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Erro ao carregar prévia: ${response.statusCode}');
    }
  }

  /// Downloads file bytes for saving to disk
  Future<Uint8List> downloadFileBytes(String taskId) async {
    final uri = Uri.parse(AppConstants.taskDownloadUrl(taskId));
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Erro ao baixar documento: ${response.statusCode}');
    }
  }

  /// Retries a failed task
  Future<void> retryTask(String taskId) async {
    final uri = Uri.parse(AppConstants.taskRetryUrl(taskId));
    final response = await _client.post(uri);
    if (response.statusCode != 200) {
      throw Exception('Erro ao reiniciar tarefa: ${response.statusCode}');
    }
  }

  /// Fetches current AI settings
  Future<Map<String, dynamic>> getSettings() async {
    final uri = Uri.parse(AppConstants.settingsUrl);
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Erro ao carregar configurações: ${response.statusCode}');
    }
  }

  /// Updates AI settings
  Future<void> saveSettings(Map<String, dynamic> settingsData) async {
    final uri = Uri.parse(AppConstants.settingsUrl);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(settingsData),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao salvar configurações: ${response.statusCode}');
    }
  }

  /// Tests AI Provider connection
  Future<Map<String, dynamic>> testAIConnection(Map<String, dynamic> requestData) async {
    final uri = Uri.parse(AppConstants.testConnectionUrl);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );
    return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
