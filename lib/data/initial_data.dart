import '../domain/models.dart';

AppData buildEmptyData() {
  return AppData(
    schemaVersion: 2,
    owner: const OwnerProfile(
      id: 'owner',
      displayName: '梦主',
      signature: '',
      avatarColor: 0xFF6A4DFF,
      status: '在线',
    ),
    settings: const AppSettings(
      currentPersonaId: '',
      provider: ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://api.deepseek.com',
        model: '',
      ),
    ),
    personas: const [],
    characters: const [],
    relationships: const [],
    threads: const [],
    messages: const [],
    memories: const [],
    moments: const [],
    worldBooks: const [],
  );
}
