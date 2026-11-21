part of 'app_controller.dart';

extension MediaTools on AppController {
  Future<(String, String)> _toolCredentials() async {
    if (_providerChanges > 0) {
      throw const AiClientException('供应商配置正在更新，请稍后重试。');
    }
    final epoch = _lifecycleGeneration;
    final providerEpoch = _providerGeneration;
    final config = _snapshot.data.settings.provider;
    final key = await _keyStore.read(persistent: config.rememberKey);
    if (!mounted ||
        epoch != _lifecycleGeneration ||
        providerEpoch != _providerGeneration) {
      throw const AiClientException('操作已取消。');
    }
    if (key == null || key.trim().isEmpty) {
      throw const AiClientException('请先配置 DeepSeek 官方 API Key。');
    }
    return (config.baseUrl, key);
  }

  Future<String> transcribeAudio(
    Uint8List bytes, {
    Future<void>? abortTrigger,
  }) async {
    final (url, key) = await _toolCredentials();
    return _tools.transcribe(
      baseUrl: url,
      apiKey: key,
      audio: bytes,
      abortTrigger: abortTrigger,
    );
  }

  Future<Uint8List> synthesizeSpeech(
    String text, {
    String voice = 'stella',
    Future<void>? abortTrigger,
  }) async {
    final (url, key) = await _toolCredentials();
    return _tools.synthesize(
      baseUrl: url,
      apiKey: key,
      text: text,
      voice: voice,
      abortTrigger: abortTrigger,
    );
  }

  Future<OcrResult> recognizeImage(
    ImageContent image, {
    Future<void>? abortTrigger,
  }) async {
    final (url, key) = await _toolCredentials();
    return _tools.recognize(
      baseUrl: url,
      apiKey: key,
      image: image,
      abortTrigger: abortTrigger,
    );
  }
}
