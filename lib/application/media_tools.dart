part of 'app_controller.dart';

extension MediaTools on AppController {
  Future<(String, String)> _toolCredentials() async {
    final settings = _snapshot.data.settings;
    final config = settings.tools;
    if (_toolChanges > 0 || (config.useChatKey && _providerChanges > 0)) {
      throw const AiClientException('工具配置正在更新，请稍后重试。');
    }
    if (config.useChatKey && !settings.provider.isOfficialDeepSeek) {
      throw const AiClientException(
        '第三方聊天可继续使用；请在设置的「搜索与语音」中单独配置 DeepSeek 官方 Key。',
      );
    }
    final epoch = _lifecycleGeneration;
    final providerEpoch = _providerGeneration;
    final toolEpoch = _toolGeneration;
    final key = config.useChatKey
        ? await _keyStore.read(persistent: settings.provider.rememberKey)
        : await _toolKeyStore.read(persistent: config.rememberKey);
    if (!mounted ||
        epoch != _lifecycleGeneration ||
        toolEpoch != _toolGeneration ||
        (config.useChatKey && providerEpoch != _providerGeneration)) {
      throw const AiClientException('操作已取消。');
    }
    if (key == null || key.trim().isEmpty) {
      throw const AiClientException('请先在设置的「搜索与语音」中配置 DeepSeek 官方 API Key。');
    }
    return ('https://api.deepseek.com', key.trim());
  }

  Future<void> _changeTools(Future<void> Function(int epoch) action) async {
    final epoch = ++_toolGeneration;
    _toolChanges++;
    // Only interrupt a main reply when it is currently waiting for search.
    // Ordinary chat and its quiet memory request use a different credential.
    if (_activeSearchGeneration == _generation) _stopActiveGeneration();
    _tools.cancelAll();
    try {
      await _serializeCredentials(() => action(epoch));
    } finally {
      _toolChanges--;
    }
  }

  Future<void> saveToolConfig({
    required DeepSeekToolConfig config,
    String? apiKey,
  }) async {
    if (_toolChanges > 0 || _providerChanges > 0) {
      throw const AiClientException('配置正在更新，请稍后重试。');
    }
    await _changeTools((epoch) async {
      if (!mounted || epoch != _toolGeneration) {
        throw const AiClientException('配置已改变，请重试保存。');
      }
      if (config.useChatKey) {
        if (!_snapshot.data.settings.provider.isOfficialDeepSeek ||
            !_snapshot.hasApiKey) {
          throw const AiClientException('当前聊天未配置 DeepSeek 官方 Key，请选择「单独配置」。');
        }
        await _toolKeyStore.clear();
      } else {
        final key = apiKey?.trim().isNotEmpty == true
            ? apiKey!.trim()
            : await _toolKeyStore.read(
                persistent: _snapshot.data.settings.tools.rememberKey,
              );
        if (!mounted || epoch != _toolGeneration) {
          throw const AiClientException('配置已改变，请重试保存。');
        }
        if (key?.isNotEmpty != true) {
          throw const AiClientException('请填写 DeepSeek 官方 API Key。');
        }
        await _toolKeyStore.write(key!, persistent: config.rememberKey);
      }
      if (!mounted || epoch != _toolGeneration) {
        throw const AiClientException('配置已改变，请重试保存。');
      }
      _commit(
        _snapshot.data.copyWith(
          settings: _snapshot.data.settings.copyWith(tools: config),
        ),
      );
      _snapshot = _snapshot.copyWith(hasToolApiKey: !config.useChatKey);
      await flush();
    });
  }

  Future<void> clearToolKey() async {
    await _changeTools((_) async {
      await _toolKeyStore.clear();
      if (mounted) _snapshot = _snapshot.copyWith(hasToolApiKey: false);
    });
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
