import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vortex/theme/app_theme.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back Button ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),

              // ── Hero Section with Concentric Vortex Arcs & Typography ─────
              SizedBox(
                height: 220,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Concentric Vortex Rings (Upper Right)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _VortexArcsPainter(
                          accentColor: AppTheme.accentLime,
                        ),
                      ),
                    ),
                    // Giant "Vortex" Heading + Subtitle
                    const Positioned(
                      left: 20,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vortex',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'File manager and transfer',
                            style: TextStyle(
                              color: Color(0xFF78828A),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Details Section ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDivider(),
                    _buildDetailRow('Created by', 'Dark'),
                    _buildDivider(),
                    _buildDetailRow('Made with', 'Flutter & love'),
                    _buildDivider(),
                    _buildDetailRow('Version', '1.0.0'),
                    _buildDivider(),
                    _buildDetailRow('Framework', 'Flutter'),
                    _buildDivider(),
                    _buildDetailRow('Platform', 'Android & Linux'),
                    _buildDivider(),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Features Section ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Features',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDivider(),
                    _buildFeatureItem('01', 'Smart file management'),
                    _buildDivider(),
                    _buildFeatureItem('02', 'Wi-Fi file transfer'),
                    _buildDivider(),
                    _buildFeatureItem('03', 'USB tethering support'),
                    _buildDivider(),
                    _buildFeatureItem('04', 'QR code pairing'),
                    _buildDivider(),
                    _buildFeatureItem('05', 'High-speed transfers'),
                    _buildDivider(),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78828A),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String number, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Text(
            number,
            style: const TextStyle(
              color: Color(0xFF5A626A),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: const Color(0xFF16191E),
    );
  }
}

/// Custom painter for the concentric radar/vortex spiral arcs
class _VortexArcsPainter extends CustomPainter {
  final Color accentColor;

  const _VortexArcsPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.82;
    final cy = 76.0;

    // Center focal point dot
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 4.5, dotPaint);

    // Arcs specification: (radius, startAngle, sweepAngle, alpha)
    final arcs = [
      (22.0, -0.6 * pi, 1.65 * pi, 1.0),
      (40.0, 0.1 * pi, 1.55 * pi, 0.95),
      (62.0, 0.35 * pi, 1.45 * pi, 0.88),
      (88.0, 0.50 * pi, 1.35 * pi, 0.80),
      (118.0, 0.60 * pi, 1.25 * pi, 0.70),
      (152.0, 0.68 * pi, 1.15 * pi, 0.55),
      (190.0, 0.75 * pi, 1.05 * pi, 0.40),
    ];

    for (final (radius, startAngle, sweepAngle, alpha) in arcs) {
      final arcPaint = Paint()
        ..color = accentColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VortexArcsPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
