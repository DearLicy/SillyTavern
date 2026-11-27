part of 'app_controller.dart';

extension PromptManagement on AppController {
  Future<void> savePromptConfig(PromptConfig config) async {
    final errors = RegexTransformer.validateAll(config);
    if (errors.isNotEmpty) throw FormatException(errors.first);
    final before = _snapshot.data;
    if (_snapshot.generatingThreadId != null ||
        _activeGenerationAbort != null) {
      _stopActiveGeneration();
    }
    _cancelPendingSummaries();
    await _saveManagementChange(
      before,
      before.copyWith(settings: before.settings.copyWith(prompts: config)),
    );
  }
}
