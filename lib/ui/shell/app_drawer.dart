import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final owner = state.data.owner;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currentPersona = ref.watch(currentPersonaProvider);
    final width = MediaQuery.sizeOf(context).width;

    return Drawer(
      width: width.clamp(300, 380).toDouble(),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? DtColors.darkBg : DtColors.canvasSoft,
          border: Border(
            right: BorderSide(color: dark ? DtColors.darkLine : DtColors.line),
          ),
          boxShadow: DtShadows.floating(dark),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  children: [
                    DtStagger(
                      child: _ProfileCard(
                        owner: owner,
                        persona: currentPersona,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/profile');
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    DtStagger(
                      index: 1,
                      child: _DrawerGroup(
                        children: [
                          _DrawerRow(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: DtColors.violet,
                            title: '切换用户人设',
                            subtitle: currentPersona?.name ?? '未选择',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/personas');
                            },
                          ),
                          _DrawerRow(
                            icon: Icons.photo_library_outlined,
                            iconColor: const Color(0xFFE6A43B),
                            title: '剧情相册',
                            subtitle: '聊天图片已开放；剧情相册将在 V2.3 提供',
                            onTap: () => _comingSoon(context),
                          ),
                          _DrawerRow(
                            icon: Icons.bookmark_border_rounded,
                            iconColor: DtColors.mint,
                            title: '收藏与记忆',
                            subtitle: '查看角色真正记住的事',
                            onTap: () {
                              Navigator.of(context).pop();
                              final relationship =
                                  state.data.relationships.firstOrNull;
                              if (relationship != null) {
                                context.push('/memory/${relationship.id}');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DtStagger(
                      index: 2,
                      child: _DrawerGroup(
                        children: [
                          _DrawerRow(
                            icon: Icons.shield_outlined,
                            iconColor: DtColors.coral,
                            title: '隐私与安全',
                            subtitle: '内容上限、边界与安全词',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/safety');
                            },
                          ),
                          _DrawerRow(
                            icon: Icons.cloud_sync_outlined,
                            iconColor: DtColors.brand,
                            title: '数据与备份',
                            subtitle: '本地导出与恢复',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/backup');
                            },
                          ),
                          _DrawerRow(
                            icon: Icons.settings_outlined,
                            iconColor: const Color(0xFF6C7C92),
                            title: '设置',
                            subtitle: '模型、外观与存储',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/settings');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DtStagger(
                      index: 3,
                      child: _DrawerGroup(
                        children: [
                          _DrawerRow(
                            icon: dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            iconColor: dark
                                ? const Color(0xFFF0B64D)
                                : const Color(0xFF5F6B80),
                            title: dark ? '切换浅色模式' : '切换夜间模式',
                            onTap: () => controller.setTheme(
                              dark ? AppThemeMode.light : AppThemeMode.dark,
                            ),
                          ),
                          _DrawerRow(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF8090A8),
                            title: '关于 SillyTavern',
                            subtitle: 'V2.1.3 · 本地 LLM 前端',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/about');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Text(
                      'SillyTavern APP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? const Color(0xFF80796F)
                            : DtColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '18+ · BYOK',
                      style: TextStyle(
                        fontSize: 10,
                        color: dark
                            ? const Color(0xFF80796F)
                            : DtColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('剧情相册将在 V2.3 开放')));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.owner,
    required this.persona,
    required this.onTap,
  });

  final OwnerProfile owner;
  final UserPersona? persona;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtPressable(
      onTap: onTap,
      semanticLabel: '编辑个人资料',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [DtColors.darkElevated, DtColors.darkSurface]
                : const [DtColors.surface, DtColors.canvasSoft],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dark ? DtColors.darkLine : const Color(0xFFE6E0D7),
          ),
          boxShadow: DtShadows.floating(dark),
        ),
        child: Row(
          children: [
            DtAvatar(
              name: owner.displayName,
              reference: owner.avatarReference,
              color: owner.avatarColor,
              size: 62,
              showStatus: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          owner.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: DtColors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          '用户',
                          style: TextStyle(
                            color: DtColors.brand,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    owner.signature,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: dark
                          ? const Color(0xFFB8B0A4)
                          : DtColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    persona == null ? '尚未选择用户人设' : '当前用户人设 · ${persona!.name}',
                    style: const TextStyle(
                      color: DtColors.violet,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: dark ? const Color(0xFF6E7891) : const Color(0xFFAFB8C9),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerGroup extends StatelessWidget {
  const _DrawerGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtSurface(
      level: DtSurfaceLevel.raised,
      padding: EdgeInsets.zero,
      borderRadius: 12,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Divider(
                  color: dark ? DtColors.darkLine : const Color(0xFFEDE8E0),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtPressable(
      onTap: onTap,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: dark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: dark
                            ? const Color(0xFF938B80)
                            : DtColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: dark ? const Color(0xFF716A60) : const Color(0xFFB7B0A6),
            ),
          ],
        ),
      ),
    );
  }
}
