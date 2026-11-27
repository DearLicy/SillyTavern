import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/app_controller.dart';

final avatarBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, reference) =>
          ref.watch(attachmentStoreProvider).readImage(reference),
    );

class DtAvatar extends ConsumerWidget {
  const DtAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 48,
    this.showStatus = false,
    this.statusColor = const Color(0xFF42C58A),
    this.heroTag,
    this.reference,
  });

  final String? reference;
  final String name;
  final int color;
  final double size;
  final bool showStatus;
  final Color statusColor;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeName = name.trim().isEmpty ? '用' : name.trim();
    final start = Color(color);
    final end = Color.lerp(start, Colors.white, 0.34) ?? start;
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        safeName.characters.first,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
    final stored = reference == null
        ? null
        : ref.watch(avatarBytesProvider(reference!)).valueOrNull;
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        if (stored == null)
          avatar
        else
          ClipOval(
            child: Image.memory(
              stored,
              key: ValueKey('avatar-$reference'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => avatar,
            ),
          ),
        if (showStatus)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
    if (heroTag == null) return content;
    return Hero(tag: heroTag!, child: content);
  }
}
