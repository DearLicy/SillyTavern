import 'dart:async';
import '../components/dt_sheet.dart';
import '../components/dt_edit_sheet.dart';
import '../components/dt_input.dart';
import '../components/dt_voice_sheet.dart';
import '../../data/image_content.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_controller.dart';
import '../../data/attachment_store.dart';
import '../../domain/models.dart';
import '../../domain/dialogue.dart';
import 'package:forui/forui.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _nearBottom = true;
  String _lastContent = '';
  bool _sending = false;
  bool _searchWeb = false;
  bool _toolBusy = false;
  String? _toolStatus;
  final _toolsAbort = Completer<void>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appControllerProvider.notifier).markThreadRead(widget.threadId);
      _jumpToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    if (!_toolsAbort.isCompleted) _toolsAbort.complete();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final near =
        _scrollController.position.maxScrollExtent - _scrollController.offset <
        80;
    if (near != _nearBottom) setState(() => _nearBottom = near);
  }

  void _jumpToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated && !DtMotion.reduced(context)) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final thread = data.threads
        .where((e) => e.id == widget.threadId)
        .firstOrNull;
    if (thread == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('会话不存在')),
        body: const Center(child: Text('这段梦境已经找不到。')),
      );
    }
    final relationship = data.relationshipForThread(thread);
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    if (relationship == null || character == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('会话异常')),
        body: const Center(child: Text('会话缺少角色关系。')),
      );
    }
    final messages =
        data.messages
            .where((e) => e.threadId == thread.id && e.isRenderable)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final content = '${messages.length}:${messages.lastOrNull?.text ?? ''}';
    if (content != _lastContent) {
      _lastContent = content;
      if (_nearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _nearBottom) _jumpToBottom(animated: false);
        });
      }
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final attachmentStore = ref.watch(attachmentStoreProvider);
    final primaryGreeting = character.greeting.trim();
    final greetings = <String>[
      if (primaryGreeting.isNotEmpty) primaryGreeting,
      for (final greeting in character.alternateGreetings)
        if (greeting.trim().isNotEmpty && greeting.trim() != primaryGreeting)
          greeting.trim(),
    ];
    final controller = ref.read(appControllerProvider.notifier);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: dark ? DtColors.darkBg : DtColors.canvas,
      appBar: _ChatAppBar(
        character: character,
        relationship: relationship,
        onBack: context.pop,
        onMenu: () => _showChatMenu(context, data, relationship, character),
      ),
      body: Column(
        children: [
          if (_searchWeb || _toolStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _toolBusy
                        ? Icons.hourglass_top_rounded
                        : Icons.travel_explore,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _toolStatus ?? '联网搜索已开启 · 发送时查询并附上来源',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (!_toolBusy)
                    DtIconButton(
                      icon: Icons.close,
                      tooltip: '关闭联网搜索',
                      onTap: () => setState(() => _searchWeb = false),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                  itemCount:
                      messages.length +
                      (state.generatingThreadId == thread.id ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= messages.length) {
                      return _TypingIndicator(character: character);
                    }
                    final message = messages[index];
                    final previous = index == 0 ? null : messages[index - 1];
                    final showTime =
                        previous == null ||
                        message.createdAt
                                .difference(previous.createdAt)
                                .inMinutes >=
                            12;
                    return DtStagger(
                      key: ValueKey('message-${message.id}'),
                      offset: 8,
                      child: Column(
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? DtColors.darkSurface
                                      : DtColors.surface.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  _timeLabel(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: dark
                                        ? const Color(0xFF817A70)
                                        : DtColors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          _MessageBubble(
                            message: message,
                            character: character,
                            owner: data.owner.copyWith(
                              displayName: data
                                  .personaById(relationship.personaId)
                                  ?.name,
                              avatarReference: data
                                  .personaById(relationship.personaId)
                                  ?.avatarReference,
                            ),
                            attachmentStore: attachmentStore,
                            onLongPress: () => _showMessageActions(
                              context,
                              message,
                              relationship,
                            ),
                          ),
                          if (message.sources.isNotEmpty)
                            DtActionButton(
                              onPressed: () => _showSources(message),
                              child: Text('联网来源 · ${message.sources.length}'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (messages.isEmpty &&
                    state.generatingThreadId != thread.id)
                  Positioned.fill(
                    child: _EmptyChatStart(
                      character: character,
                      greetings: greetings,
                      dark: dark,
                      onStart: (text) => controller.startWithGreeting(
                        thread.id,
                        text,
                      ),
                    ),
                  ),
                if (!_nearBottom && messages.isNotEmpty)
                  Positioned(
                    right: 14,
                    bottom: 12,
                    child: DtPressable(
                      onTap: _jumpToBottom,
                      semanticLabel: '回到最新消息',
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: dark
                              ? DtColors.darkElevated
                              : DtColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: DtShadows.floating(dark),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: dark ? const Color(0xFFF0ECE4) : DtColors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (state.error != null)
            _ChatErrorBar(
              message: state.error!,
              onRetry: () => ref
                  .read(appControllerProvider.notifier)
                  .retryLastTurn(thread.id),
              onDismiss: () =>
                  ref.read(appControllerProvider.notifier).clearError(),
            ),
          _ChatComposer(
            controller: _textController,
            focusNode: _focusNode,
            generating: state.generatingThreadId == thread.id,
            onSend: () async {
              if (_sending) return;
              final text = _textController.text;
              if (text.trim().isEmpty) return;
              _sending = true;
              final controller = ref.read(appControllerProvider.notifier);
              final future = controller.sendMessage(
                thread.id,
                text,
                searchWeb: _searchWeb,
                onAccepted: () {
                  if (!mounted) return;
                  _sending = false;
                  if (_textController.text == text) _textController.clear();
                  _nearBottom = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _jumpToBottom(animated: false);
                  });
                },
              );
              await future;
              if (!mounted) return;
              _sending = false;
            },
            onCancel: () =>
                ref.read(appControllerProvider.notifier).interruptGeneration(),
            onMore: () => _showMoreActions(context, relationship),
            onVoice: _voiceInput,
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return DateFormat('HH:mm').format(value);
    }
    return DateFormat('M月d日 HH:mm').format(value);
  }

  void _showChatMenu(
    BuildContext context,
    AppData data,
    Relationship relationship,
    Character character,
  ) {
    final thread = data.threadForRelationship(relationship.id);
    final threadMessages = thread == null
        ? const <Message>[]
        : (data.messages
              .where((message) => message.threadId == thread.id)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    final latest = threadMessages.lastOrNull;
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (thread != null)
                DtSettingRow(
                  icon: Icons.manage_history_rounded,
                  title: '聊天与数据',
                  subtitle: '查找记录、清空聊天或重新开始',
                  onTap: () {
                    Navigator.pop(context);
                    this.context.push('/chat-data/${thread.id}');
                  },
                ),
              DtSettingRow(
                icon: Icons.person_outline_rounded,
                title: '查看角色资料',
                subtitle: character.intro,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/character/${character.id}');
                },
              ),
              if (thread != null && latest != null)
                DtSettingRow(
                  icon: Icons.refresh_rounded,
                  iconColor: DtColors.mint,
                  title: latest.fromAi ? '重新生成上一条' : '重试上一条',
                  subtitle: latest.fromAi ? '替换最后一条角色回复' : '重新发送上一条消息',
                  onTap: () async {
                    Navigator.pop(context);
                    final controller = ref.read(appControllerProvider.notifier);
                    if (latest.fromAi) {
                      await controller.regenerateLastReply(thread.id);
                    } else {
                      await controller.retryLastTurn(thread.id);
                    }
                  },
                ),
              DtSettingRow(
                icon: Icons.psychology_alt_outlined,
                title: '记忆管理',
                subtitle: '角色真正记住的事',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/memory/${relationship.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.movie_filter_outlined,
                title: '导演模式',
                subtitle: '节奏、旁白与剧情推进',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/director/${relationship.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.shield_outlined,
                title: '内容与边界',
                subtitle:
                    '${relationship.consent.ceiling.label} · 安全词 ${relationship.consent.safeWord}',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/consent/${relationship.id}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreActions(BuildContext context, Relationship relationship) {
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.mic_none,
                title: '语音转文字',
                subtitle: '录音后识别，确认草稿再发送',
                onTap: () {
                  Navigator.pop(context);
                  _voiceInput();
                },
              ),
              DtSettingRow(
                icon: Icons.document_scanner_outlined,
                title: '识别图片文字',
                subtitle: 'DeepSeek OCR，识别后可编辑',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, ocr: true);
                },
              ),
              DtSettingRow(
                icon: Icons.travel_explore,
                title: _searchWeb ? '关闭联网搜索' : '开启联网搜索',
                subtitle: '仅本聊天发送时检索，附上真实来源',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _searchWeb = !_searchWeb);
                },
              ),
              DtSettingRow(
                icon: Icons.photo_library_outlined,
                iconColor: DtColors.violet,
                title: '从相册发送图片',
                subtitle: 'JPG、PNG、WebP 或 GIF，最大 10MB',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              DtSettingRow(
                icon: Icons.photo_camera_outlined,
                iconColor: DtColors.brand,
                title: '拍照发送',
                subtitle: '调用系统相机，不会后台拍摄',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              DtSettingRow(
                icon: Icons.movie_filter_outlined,
                iconColor: DtColors.brand,
                title: '当前场景',
                subtitle: relationship.scene.location,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/scene/${relationship.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.psychology_outlined,
                iconColor: DtColors.mint,
                title: '添加一条记忆',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/memory/${relationship.id}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, {bool ocr = false}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2048,
      );
      if (picked == null) return;
      final length = await picked.length();
      if (length > 10 * 1024 * 1024) {
        _showImageError('图片超过 10MB，请先压缩后再发送');
        return;
      }
      final mimeType = picked.mimeType ?? _imageMimeType(picked.name);
      if (!_supportedImageTypes.contains(mimeType.toLowerCase())) {
        _showImageError('仅支持 JPG、PNG、WebP 和 GIF 图片');
        return;
      }
      final bytes = await picked.readAsBytes();
      final image = ImageContent.parse(bytes);
      if (!mounted) return;
      if (ocr) {
        await _recognize(image);
        return;
      }
      final store = ref.read(attachmentStoreProvider);
      final reference = await store.saveImage(
        id: const Uuid().v4(),
        bytes: bytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      _showImageComposer(reference, bytes);
    } catch (error) {
      _showImageError('无法读取图片：$error');
    }
  }

  Future<void> _voiceInput() async {
    final text = await showVoiceInput(context);
    if (!mounted || text == null) return;
    _textController.text = _textController.text.trim().isEmpty
        ? text
        : '${_textController.text}\n$text';
    _focusNode.requestFocus();
  }

  Future<void> _recognize(ImageContent image) async {
    if (_toolBusy) return;
    final thread = ref
        .read(appControllerProvider)
        .data
        .threads
        .where((t) => t.id == widget.threadId)
        .firstOrNull;
    setState(() {
      _toolBusy = true;
      _toolStatus = '正在识别图片文字…';
    });
    try {
      final result = await ref
          .read(appControllerProvider.notifier)
          .recognizeImage(image, abortTrigger: _toolsAbort.future);
      if (!mounted ||
          !identical(
            thread,
            ref
                .read(appControllerProvider)
                .data
                .threads
                .where((t) => t.id == widget.threadId)
                .firstOrNull,
          )) {
        return;
      }
      if (result.text.isEmpty) {
        _showImageError('图片中没有识别到文字。');
        return;
      }
      await showDtEditSheet(
        context: context,
        title: '识别结果',
        description: result.incomplete
            ? '部分内容达到识别上限，请检查补全后再使用。'
            : '检查文字后填入草稿，不会自动发送。',
        initialText: result.text,
        actionLabel: '填入输入框',
        onSubmit: (text) async {
          _textController.text = text;
          _focusNode.requestFocus();
        },
      );
    } catch (error) {
      if (mounted) _showImageError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _toolBusy = false;
          _toolStatus = null;
        });
      }
    }
  }

  void _showSources(Message message) {
    showDtSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '联网来源',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              for (var i = 0; i < message.sources.length; i++)
                DtSettingRow(
                  icon: Icons.open_in_new,
                  title: '[${i + 1}] ${message.sources[i].title}',
                  subtitle: message.sources[i].url,
                  onTap: () async {
                    final uri = Uri.tryParse(message.sources[i].url);
                    if (uri == null ||
                        !['https', 'http'].contains(uri.scheme) ||
                        uri.userInfo.isNotEmpty) {
                      return;
                    }
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法打开来源链接')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showImageComposer(String reference, Uint8List bytes) {
    final caption = TextEditingController();
    final store = ref.read(attachmentStoreProvider);
    var handedOff = false;
    showDtSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '发送图片',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 12),
            DtTextField(
              controller: caption,
              minLines: 1,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(hintText: '加一句话，或者直接发送……'),
            ),
            const SizedBox(height: 12),
            DtButton(
              label: '发送',
              icon: Icons.arrow_upward_rounded,
              onPressed: () async {
                final text = caption.text.trim();
                handedOff = true;
                Navigator.pop(sheetContext);
                var accepted = false;
                await ref
                    .read(appControllerProvider.notifier)
                    .sendMessage(
                      widget.threadId,
                      text,
                      kind: MessageKind.image,
                      localPath: reference,
                      onAccepted: () => accepted = true,
                    );
                if (!accepted) await store.delete(reference);
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() async {
      caption.dispose();
      if (!handedOff) await store.delete(reference);
    });
  }

  static const _supportedImageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  String _imageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _showMessageActions(
    BuildContext context,
    Message message,
    Relationship relationship,
  ) {
    final threadMessages =
        ref
            .read(appControllerProvider)
            .data
            .messages
            .where((item) => item.threadId == message.threadId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final isLatest = threadMessages.lastOrNull?.id == message.id;
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLatest)
                DtSettingRow(
                  icon: Icons.refresh_rounded,
                  iconColor: DtColors.mint,
                  title: message.fromAi ? '重新生成这条回复' : '重试生成',
                  subtitle: message.fromAi ? '替换这条角色回复' : '重新请求角色回复',
                  onTap: () async {
                    Navigator.pop(context);
                    final controller = ref.read(appControllerProvider.notifier);
                    if (message.fromAi) {
                      await controller.regenerateLastReply(message.threadId);
                    } else {
                      await controller.retryLastTurn(message.threadId);
                    }
                  },
                ),
              DtSettingRow(
                icon: Icons.edit_outlined,
                title: '编辑消息',
                subtitle: '保存到本机并用于后续对话',
                onTap: () {
                  Navigator.pop(context);
                  showDtEditSheet(
                    context: this.context,
                    title: '编辑消息',
                    description: '将重新整理自动摘要和自动记忆；手动记忆与关系数值保留，不会自动重发。',
                    initialText: message.text,
                    allowEmpty: message.kind == MessageKind.image,
                    actionLabel: '保存修改',
                    onSubmit: (text) => ref
                        .read(appControllerProvider.notifier)
                        .editMessage(message.id, text),
                  );
                },
              ),
              DtSettingRow(
                icon: Icons.delete_outline_rounded,
                title: '删除消息',
                onTap: () {
                  Navigator.pop(context);
                  showDtEditSheet(
                    context: this.context,
                    title: '删除这条消息？',
                    description:
                        '删除消息及不再使用的图片，并重新整理自动摘要和自动记忆。手动记忆与关系数值保留。此操作无法撤销。',
                    actionLabel: '删除消息',
                    danger: true,
                    onSubmit: (_) => ref
                        .read(appControllerProvider.notifier)
                        .deleteMessage(message.id),
                  );
                },
              ),
              DtSettingRow(
                icon: Icons.volume_up_outlined,
                title: '朗读消息',
                onTap: () {
                  Navigator.pop(context);
                  showReadAloud(this.context, message.text);
                },
              ),
              if (message.kind == MessageKind.image &&
                  message.localPath != null)
                DtSettingRow(
                  icon: Icons.document_scanner_outlined,
                  title: '识别图片文字',
                  onTap: () async {
                    Navigator.pop(context);
                    final bytes = await ref
                        .read(attachmentStoreProvider)
                        .readImage(message.localPath!);
                    if (!mounted) return;
                    if (bytes == null) {
                      _showImageError('图片已失效，请重新发送。');
                      return;
                    }
                    await _recognize(ImageContent.parse(bytes));
                  },
                ),
              if (message.sources.isNotEmpty)
                DtSettingRow(
                  icon: Icons.travel_explore,
                  title: '查看联网来源',
                  onTap: () {
                    Navigator.pop(context);
                    _showSources(message);
                  },
                ),
              DtSettingRow(
                icon: Icons.copy_rounded,
                title: '复制文本',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制')));
                },
              ),
              DtSettingRow(
                icon: Icons.bookmark_add_outlined,
                iconColor: DtColors.violet,
                title: '存为记忆',
                onTap: () {
                  Navigator.pop(context);
                  _showMemoryDialog(context, message, relationship);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemoryDialog(
    BuildContext context,
    Message message,
    Relationship relationship,
  ) {
    showDtEditSheet(
      context: this.context,
      title: '添加长期记忆',
      description: '从这条对话提炼需要记住的事实，可在记忆管理中继续编辑。',
      initialText: message.text,
      actionLabel: '保存记忆',
      onSubmit: (content) async {
        final controller = ref.read(appControllerProvider.notifier);
        if (!ref
            .read(appControllerProvider)
            .data
            .messages
            .any((m) => m.id == message.id)) {
          throw StateError('这条消息已删除，请关闭后重试。');
        }
        controller.upsertMemory(
          MemoryItem(
            id: const Uuid().v4(),
            relationshipId: relationship.id,
            type: MemoryType.experience,
            title: '对话记忆',
            content: content,
            createdAt: DateTime.now(),
            sourceThreadId: message.threadId,
            sourceMessageId: message.id,
            pinned: true,
          ),
        );
        await controller.flush();
      },
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.character,
    required this.relationship,
    required this.onBack,
    required this.onMenu,
  });

  final Character character;
  final Relationship relationship;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: dark ? DtColors.darkSurface : DtColors.surface,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 44,
      leading: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: DtIconButton(
          onTap: onBack,
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: '返回',
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          DtAvatar(
            name: character.name,
            reference: character.avatarReference,
            color: character.avatarColor,
            size: 39,
            showStatus: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${relationship.stage} · ${relationship.consent.ceiling.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: dark
                        ? const Color(0xFF8A93A7)
                        : const Color(0xFF8B94A5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        DtIconButton(onTap: onMenu, icon: Icons.menu_rounded, tooltip: '更多'),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.7),
        child: Divider(
          height: 0.7,
          color: dark ? DtColors.darkLine : const Color(0xFFE9E3DA),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.character,
    required this.owner,
    required this.attachmentStore,
    required this.onLongPress,
  });
  final Message message;
  final Character character;
  final OwnerProfile owner;
  final AttachmentStore attachmentStore;
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) {
    if (!message.isRenderable) return const SizedBox.shrink();
    final mine = !message.fromAi;
    if (message.kind == MessageKind.image && message.localPath != null) {
      return _ImageMessageBubble(
        message: message,
        character: character,
        owner: owner,
        attachmentStore: attachmentStore,
        onLongPress: onLongPress,
      );
    }
    final segments = mine
        ? [
            DialogueSegment(
              kind: DialogueSegmentKind.speech,
              text: message.text,
            ),
          ]
        : DialogueParser.parse(message.text);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        if (message.editedAt != null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '已编辑',
              style: TextStyle(fontSize: 10, color: DtColors.textSecondary),
            ),
          ),
        for (final segment in segments)
          if (segment.kind == DialogueSegmentKind.narration)
            DtPressable(
              onLongPress: onLongPress,
              child: Padding(
                key: const ValueKey('message-narration'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                child: Text(
                  segment.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: DtColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: mine
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine) ...[
                    DtAvatar(
                      name: character.name,
                      reference: character.avatarReference,
                      color: character.avatarColor,
                      size: 36,
                    ),
                    const SizedBox(width: 9),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .73,
                      ),
                      child: DtPressable(
                        onLongPress: onLongPress,
                        semanticLabel: '长按消息操作',
                        child: Container(
                          key: const ValueKey('message-speech'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? DtColors.violet
                                : (dark
                                      ? DtColors.darkSurface
                                      : DtColors.surface),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            segment.text,
                            style: TextStyle(
                              color: mine
                                  ? Colors.white
                                  : (dark
                                        ? const Color(0xFFEEEEF2)
                                        : DtColors.ink),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 9),
                    DtAvatar(
                      name: owner.displayName,
                      reference: owner.avatarReference,
                      color: owner.avatarColor,
                      size: 36,
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}

class _ImageMessageBubble extends StatelessWidget {
  const _ImageMessageBubble({
    required this.message,
    required this.character,
    required this.owner,
    required this.attachmentStore,
    required this.onLongPress,
  });

  final Message message;
  final Character character;
  final OwnerProfile owner;
  final AttachmentStore attachmentStore;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = !message.fromAi;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            DtAvatar(
              name: character.name,
              reference: character.avatarReference,
              color: character.avatarColor,
              size: 36,
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .73,
              ),
              child: DtPressable(
                onLongPress: onLongPress,
                semanticLabel: '图片消息，长按操作',
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? DtColors.darkSurface : DtColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StoredImage(
                        store: attachmentStore,
                        reference: message.localPath!,
                      ),
                      if (message.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: dark ? Colors.white : DtColors.ink,
                              fontSize: 15.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 9),
            DtAvatar(
              name: owner.displayName,
              reference: owner.avatarReference,
              color: owner.avatarColor,
              size: 36,
            ),
          ],
        ],
      ),
    );
  }
}

class _StoredImage extends StatefulWidget {
  const _StoredImage({required this.store, required this.reference});

  final AttachmentStore store;
  final String reference;

  @override
  State<_StoredImage> createState() => _StoredImageState();
}

class _StoredImageState extends State<_StoredImage> {
  late Future<Uint8List?> _image = widget.store.readImage(widget.reference);

  @override
  void didUpdateWidget(covariant _StoredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.store != widget.store) {
      _image = widget.store.readImage(widget.reference);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _image,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.memory(
            key: const ValueKey('message-image'),
            bytes,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return Container(
        width: 220,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: const Text('图片已失效', style: TextStyle(fontSize: 12)),
      );
    },
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.character});
  final Character character;
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      '正在输入…',
      style: TextStyle(fontSize: 12, color: DtColors.textSecondary),
    ),
  );
}

class _ChatErrorBar extends StatelessWidget {
  const _ChatErrorBar({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF342127) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? const Color(0xFF5E343D) : const Color(0xFFF4C9CF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: Color(0xFFD85566),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ),
          const SizedBox(width: 6),
          DtActionButton(onPressed: onRetry, child: const Text('重试')),
          IconButton(
            tooltip: '关闭错误提示',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.generating,
    required this.onSend,
    required this.onCancel,
    required this.onMore,
    required this.onVoice,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onMore;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? DtColors.darkSurface : DtColors.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DtIconButton(icon: Icons.mic_none, tooltip: '语音输入', onTap: onVoice),
            DtIconButton(icon: FIcons.plus, tooltip: '更多功能', onTap: onMore),
            Expanded(
              child: DtTextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '说点什么……',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final empty = value.text.trim().isEmpty;
                return DtIconButton(
                  icon: generating
                      ? empty
                            ? Icons.stop_rounded
                            : FIcons.send
                      : FIcons.send,
                  tooltip: generating
                      ? empty
                            ? '停止生成'
                            : '发送并打断当前回复'
                      : '发送',
                  onTap: generating
                      ? empty
                            ? onCancel
                            : onSend
                      : empty
                      ? null
                      : onSend,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatStart extends StatelessWidget {
  const _EmptyChatStart({
    required this.character,
    required this.greetings,
    required this.dark,
    required this.onStart,
  });

  final Character character;
  final List<String> greetings;
  final bool dark;
  final ValueChanged<String> onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Center(
          child: DtAvatar(
            name: character.name,
            reference: character.avatarReference,
            color: character.avatarColor,
            size: 72,
            showStatus: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          character.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (character.intro.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            character.intro.trim(),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: dark ? const Color(0xFF97A2B5) : DtColors.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (greetings.isEmpty)
          const DtSurface(
            child: Text(
              '直接发一条消息，开始这段对话。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
          )
        else
          for (var i = 0; i < greetings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DtSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i == 0 ? '默认开场' : '备选开场 $i',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? const Color(0xFF8E99AD)
                            : DtColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      greetings[i],
                      style: const TextStyle(fontSize: 13.5, height: 1.65),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DtButton(
                        label: '用这个开场',
                        variant: DtButtonVariant.secondary,
                        onPressed: () => onStart(greetings[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
