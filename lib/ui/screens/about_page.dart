import 'package:flutter/material.dart';

import '../components/dt_detail_page.dart';
import '../components/dt_controls.dart';
import '../theme/dt_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtDetailPage(
      title: '关于 Dreamtide',
      subtitle: 'V2.0.7 · 本地优先 AI 梦境恋爱 IM',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DtColors.brand, DtColors.violet, Color(0xFFC184C7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.nightlight_round, color: Colors.white, size: 36),
                SizedBox(height: 18),
                Text(
                  '触梦 · Dreamtide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '属于自己的私人梦境恋爱宇宙',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 16),
                Text(
                  '本地优先、BYOK、纯本地 AI 社交的梦境恋爱 IM。用梦设、长期记忆、关系成长、导演模式和梦境空间，经营一段持续存在的虚构关系。',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '产品边界',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _Line(text: '18+，仅面向自愿的成年用户', color: DtColors.coral),
                _Line(
                  text: '真实用户社交、Lorebook、SillyTavern 卡库明确不做',
                  color: DtColors.mint,
                ),
                _Line(text: '不提供官方角色、会员次数制或自有云端会话', color: DtColors.brand),
                _Line(
                  text: '群聊作为唯一重新开放的旧排除能力，计划于 V2.2 上线',
                  color: DtColors.violet,
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
                  '路线图',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _RoadmapRow(version: 'V2.0', text: '三栏 IM、梦设、关系、记忆、导演、边界、文字动态'),
                _RoadmapRow(version: 'V2.1', text: '生活状态、关系日历、主动消息、本地通知'),
                _RoadmapRow(version: 'V2.2', text: '多角色群聊、独立与共享记忆、发言调度'),
                _RoadmapRow(version: 'V2.3', text: '动态图片视频、AI 图像、剧情相册与分支'),
                _RoadmapRow(version: 'V2.4', text: '实时语音、视频剧情、触觉场景编排'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '技术与隐私',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
                Text(
                  'Flutter 三端 UI + 原生平台模块。原生端使用系统安全存储保存 API Key，本地数据库使用 SQLite；Web 使用浏览器本地存储。Dreamtide 不收集遥测，不经过自有服务器转发请求。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: dark
                        ? const Color(0xFFA2ABBD)
                        : const Color(0xFF5E6677),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'MIT License · © 2026 DearLicy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: dark ? const Color(0xFF697287) : const Color(0xFF98A0AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapRow extends StatelessWidget {
  const _RoadmapRow({required this.version, required this.text});

  final String version;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: DtColors.brand.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              version,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DtColors.brand,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
