import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../components/dt_controls.dart';
import '../components/dt_sheet.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class AgeGatePage extends ConsumerStatefulWidget {
  const AgeGatePage({super.key});

  @override
  ConsumerState<AgeGatePage> createState() => _AgeGatePageState();
}

class _AgeGatePageState extends ConsumerState<AgeGatePage> {
  DtButtonStatus _status = DtButtonStatus.idle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF191713), DtColors.darkBg]
                : const [DtColors.canvasSoft, DtColors.canvas],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        DtColors.violet.withValues(alpha: dark ? 0.11 : 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: DtStagger(
                      offset: 12,
                      child: Column(
                        children: [
                          Container(
                            width: 94,
                            height: 94,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: DtShadows.floating(dark),
                            ),
                            child: Image.asset(
                              'assets/brand/app_icon_1024.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'SillyTavern APP',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '属于自己的私人梦境恋爱宇宙',
                            style: TextStyle(
                              fontSize: 14,
                              color: dark
                                  ? const Color(0xFFA79F93)
                                  : DtColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 34),
                          DtSurface(
                            level: DtSurfaceLevel.floating,
                            padding: const EdgeInsets.all(22),
                            borderRadius: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    _AgeBadge(),
                                    SizedBox(width: 9),
                                    Text(
                                      '仅限成年人',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'SillyTavern 是本地优先的虚构角色恋爱与角色扮演空间，包含成人向文字内容。所有性相关内容仅限明确成年、自愿的虚构角色。',
                                  style: TextStyle(fontSize: 14, height: 1.65),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '继续即表示你已达到所在地区的法定成年年龄，并同意只使用自己有权创建的虚构人物与内容。',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.55,
                                    color: dark
                                        ? const Color(0xFF9B9388)
                                        : DtColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          DtButton(
                            label: '我已成年，进入梦境',
                            status: _status,
                            loadingText: '正在确认…',
                            successText: '已成年，正在进入',
                            onPressed: () async {
                              if (_status != DtButtonStatus.idle) return;
                              setState(() => _status = DtButtonStatus.loading);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 180),
                              );
                              if (!mounted) return;
                              setState(() => _status = DtButtonStatus.success);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 280),
                              );
                              if (!mounted) return;
                              ref
                                  .read(appControllerProvider.notifier)
                                  .confirmAdult();
                            },
                          ),
                          const SizedBox(height: 10),
                          DtActionButton(
                            onPressed: () => showDtSheet<void>(
                              context: context,
                              builder: (context) => SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '无法继续',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'SillyTavern APP 不面向未成年人提供。请关闭应用。',
                                      ),
                                      const SizedBox(height: 16),
                                      DtButton(
                                        label: '返回',
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            child: const Text('我未满 18 岁'),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '数据默认只保存在你的设备或浏览器中 · BYOK',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: dark
                                  ? const Color(0xFF756E64)
                                  : DtColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgeBadge extends StatelessWidget {
  const _AgeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: DtColors.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Text(
        '18+',
        style: TextStyle(
          color: DtColors.coral,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
