import '../components/dt_input.dart';
import '../components/dt_avatar_editor.dart';
import '../../data/image_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _signature;
  late final TextEditingController _status;
  late int _color;

  AvatarChange? _avatarChange;
  String? _avatarReference;
  DtButtonStatus _saveStatus = DtButtonStatus.idle;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final owner = ref.read(appControllerProvider).data.owner;
    _name = TextEditingController(text: owner.displayName);
    _signature = TextEditingController(text: owner.signature);
    _status = TextEditingController(text: owner.status);
    _color = owner.avatarColor;
    _avatarReference = owner.avatarReference;
  }

  @override
  void dispose() {
    _name.dispose();
    _signature.dispose();
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(appControllerProvider).data.owner;
    return DtDetailPage(
      title: '个人资料',
      subtitle: '本地身份，不会上传到 SillyTavern 服务器',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              children: [
                DtAvatarEditor(
                  name: _name.text,
                  color: _color,
                  reference: _avatarReference,
                  change: _avatarChange,
                  onChanged: (change) => setState(() => _avatarChange = change),
                ),
                const SizedBox(height: 16),
                _AvatarColors(
                  selected: _color,
                  onSelect: (color) => setState(() => _color = color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              children: [
                DtTextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    hintText: '你在 SillyTavern 的显示名',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _signature,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '个性签名',
                    hintText: '写一句个性签名',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _status,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    hintText: '例如：看书中、暂时离开……',
                    helperText: '只作本地资料展示，不表示角色真实在线',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_saveError != null)
            Text(
              _saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          DtButton(
            label: '保存资料',
            status: _saveStatus,
            successText: '已保存',
            onPressed: () async {
              if (_saveStatus != DtButtonStatus.idle) return;
              setState(() {
                _saveStatus = DtButtonStatus.loading;
                _saveError = null;
              });
              try {
                await ref
                    .read(appControllerProvider.notifier)
                    .saveOwnerProfile(
                      owner.copyWith(
                        displayName: _name.text.trim().isEmpty
                            ? owner.displayName
                            : _name.text.trim(),
                        signature: _signature.text.trim(),
                        status: _status.text.trim().isEmpty
                            ? owner.status
                            : _status.text.trim(),
                        avatarColor: _color,
                      ),
                      avatar: _avatarChange,
                    );
                if (!mounted) return;
                setState(() => _saveStatus = DtButtonStatus.success);
                await Future<void>.delayed(const Duration(milliseconds: 240));
                if (mounted) Navigator.pop(this.context);
              } catch (_) {
                if (mounted) {
                  setState(() {
                    _saveStatus = DtButtonStatus.idle;
                    _saveError = '资料保存失败，请重试。';
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AvatarColors extends StatelessWidget {
  const _AvatarColors({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const colors = [
    0xFF5478F6,
    0xFF8E72EA,
    0xFF32A99A,
    0xFFE07168,
    0xFFE590AA,
    0xFF6C7C92,
    0xFFC58B3E,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      children: [
        for (final color in colors)
          InkWell(
            onTap: () => onSelect(color),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == color
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected == color
                    ? [
                        BoxShadow(
                          color: Color(color).withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: selected == color
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
