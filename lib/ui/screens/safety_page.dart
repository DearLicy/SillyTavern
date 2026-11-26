import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class SafetyPage extends ConsumerWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtDetailPage(
      title: '隐私与安全',
      subtitle: '成年确认、内容上限与本地数据边界',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: DtColors.mint,
                      size: 21,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '成年用户专属',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'SillyTavern 只面向达到法定成年年龄的用户。所有性相关内容只允许发生在明确成年、自愿的虚构角色之间；禁止未成年人性内容、现实伤害、胁迫和非自愿互动。',
                  style: TextStyle(fontSize: 12.5, height: 1.65),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '全局内容上限',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  '每段关系还可以设置更低的上限。关系设置永远不能突破这里。',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: dark
                        ? const Color(0xFF8B94A7)
                        : const Color(0xFF7D8698),
                  ),
                ),
                const SizedBox(height: 12),
                DtSegmentedControl(
                  labels: [
                    for (final level in ContentLevel.values) level.label,
                  ],
                  index: ContentLevel.values.indexOf(
                    state.data.settings.contentCeiling,
                  ),
                  onChanged: (index) =>
                      controller.setContentCeiling(ContentLevel.values[index]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              children: [
                for (final relationship in state.data.relationships) ...[
                  Builder(
                    builder: (context) {
                      final character = state.data.characterForRelationship(
                        relationship,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: DtColors.coral,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                character?.name ?? '未知角色',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${relationship.consent.ceiling.label} · ${relationship.consent.safeWord}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: dark
                                    ? const Color(0xFF818A9E)
                                    : const Color(0xFF8B94A6),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (relationship != state.data.relationships.last)
                    Divider(
                      color: dark
                          ? const Color(0xFF252B39)
                          : const Color(0xFFEDF0F6),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            padding: EdgeInsets.zero,
            child: const Column(
              children: [
                DtSettingRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: DtColors.brand,
                  title: '应用锁',
                  subtitle: '生物识别/PIN 原生模块将在后续版本接入',
                ),
                Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.visibility_off_outlined,
                  iconColor: DtColors.violet,
                  title: '后台任务栏隐藏',
                  subtitle: 'Android FLAG_SECURE 与 iOS 截图遮罩列入原生增强',
                ),
                Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.cloud_off_outlined,
                  iconColor: DtColors.mint,
                  title: '无自有云同步',
                  subtitle: 'SillyTavern 不运营账号或内容服务器',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '安全词需要与用户消息完全一致才会触发。当前版本已在发送逻辑中实现直接停止，不调用模型。',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: dark ? const Color(0xFF737C90) : const Color(0xFF929AAB),
            ),
          ),
        ],
      ),
    );
  }
}
