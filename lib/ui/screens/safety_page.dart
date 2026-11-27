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
                  '此设置作用于所有角色卡与角色扮演对话。角色卡内容不能覆盖这里的安全约束。',
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
            '用户明确要求停止、跳过或结束场景时，角色必须立即尊重。平台安全约束优先于角色卡、世界书和用户提示词。',
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
