import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 页面底层：纯净的浅灰背景 + 缓慢上浮的数据粒子。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: SystemTechLayer(),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// 数据流粒子层：40+ 个淡色圆点自底部随机位置缓慢上浮，到顶淡出。
class SystemTechLayer extends StatefulWidget {
  const SystemTechLayer({super.key});

  @override
  State<SystemTechLayer> createState() => _SystemTechLayerState();
}

class _SystemTechLayerState extends State<SystemTechLayer>
    with SingleTickerProviderStateMixin {
  /// 60 秒一个主循环；每颗粒子的往返圈数取整数，循环处无缝衔接。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  late final List<_Particle> _particles = _buildParticles();

  static List<_Particle> _buildParticles() {
    final random = math.Random(2024);
    return List<_Particle>.generate(46, (index) {
      return _Particle(
        x: random.nextDouble(),
        radius: 1.0 + random.nextDouble() * 1.5,
        cycles: 2 + random.nextInt(2),
        phase: random.nextDouble(),
        alpha: 0.1 + random.nextDouble() * 0.1,
        color: random.nextBool()
            ? const Color(0xFFAFC4E0)
            : const Color(0xFFB9C2D0),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(
        controller: _controller,
        particles: _particles,
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.radius,
    required this.cycles,
    required this.phase,
    required this.alpha,
    required this.color,
  });

  /// 水平位置（0～1）。
  final double x;
  final double radius;

  /// 60 秒内上升的完整趟数。
  final int cycles;
  final double phase;

  /// 基础透明度，0.1～0.2。
  final double alpha;
  final Color color;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.controller, required this.particles})
      : super(repaint: controller);

  final Animation<double> controller;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final t = controller.value;
    final paint = Paint();

    for (final particle in particles) {
      final progress = (particle.phase + t * particle.cycles) % 1.0;
      final y = size.height + 12 - progress * (size.height + 24);

      // 底部淡入、顶部淡出，形成连绵不断的循环。
      final fade = progress < 0.1
          ? progress / 0.1
          : progress > 0.85
              ? (1 - progress) / 0.15
              : 1.0;

      paint.color = particle.color.withValues(
        alpha: particle.alpha * fade.clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        Offset(particle.x * size.width, y),
        particle.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.particles != particles;
}
