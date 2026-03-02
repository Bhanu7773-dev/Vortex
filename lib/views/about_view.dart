import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AboutView extends StatefulWidget {
  const AboutView({Key? key}) : super(key: key);

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView>
    with SingleTickerProviderStateMixin {
  late AnimationController _starsController;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade900.withOpacity(0.4),
                      Colors.purple.shade900.withOpacity(0.3),
                      Colors.black,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Revolving stars background
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _starsController,
                        builder: (context, _) => CustomPaint(
                          painter: _StarsPainter(_starsController.value),
                        ),
                      ),
                    ),
                    // Logo + text content
                    SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/app_logo.png',
                                width: 88,
                                height: 88,
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                          const SizedBox(height: 20),
                          const Text(
                            'Vortex',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                          const SizedBox(height: 8),
                          Text(
                            'File Manager & Transfer',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                        ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Developer Section
                  _buildSectionHeader('Developer', Icons.person_rounded, Colors.teal),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    children: [
                      _buildInfoRow(
                        icon: Icons.code_rounded,
                        iconColor: Colors.blue,
                        title: 'Created by',
                        value: 'Dark',
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      _buildInfoRow(
                        icon: Icons.favorite_rounded,
                        iconColor: Colors.red.shade400,
                        title: 'Made with',
                        value: 'Flutter & Love',
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 500.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // App Info Section
                  _buildSectionHeader('App Info', Icons.info_rounded, Colors.orange),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    children: [
                      _buildInfoRow(
                        icon: Icons.tag_rounded,
                        iconColor: Colors.purple,
                        title: 'Version',
                        value: '1.0.0',
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      _buildInfoRow(
                        icon: Icons.flutter_dash,
                        iconColor: Colors.blue.shade300,
                        title: 'Framework',
                        value: 'Flutter',
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      _buildInfoRow(
                        icon: Icons.devices_rounded,
                        iconColor: Colors.green,
                        title: 'Platform',
                        value: 'Android & Linux',
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 500.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // Features Section
                  _buildSectionHeader('Features', Icons.star_rounded, Colors.amber),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    children: [
                      _buildFeatureRow(Icons.folder_rounded, Colors.blue, 'Smart File Management'),
                      const Divider(color: Colors.white10, height: 16),
                      _buildFeatureRow(Icons.wifi_rounded, Colors.green, 'Wi-Fi File Transfer'),
                      const Divider(color: Colors.white10, height: 16),
                      _buildFeatureRow(Icons.usb_rounded, Colors.orange, 'USB Tethering Support'),
                      const Divider(color: Colors.white10, height: 16),
                      _buildFeatureRow(Icons.qr_code_rounded, Colors.purple, 'QR Code Pairing'),
                      const Divider(color: Colors.white10, height: 16),
                      _buildFeatureRow(Icons.speed_rounded, Colors.red, 'High-Speed Transfers'),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 500.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Thank you for using Vortex',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copyright_rounded, color: Colors.white.withOpacity(0.3), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '2026 Dark. All rights reserved.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 700.ms, duration: 500.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    
        ],
    ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, one full revolution cycle

  _StarsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // (count, radius, speed multiplier, star size, baseOpacity)
    const rings = [
      (20, 120.0, 1.0, 1.8, 0.5),
      (14, 85.0, 1.6, 2.5, 0.65),
      (8, 50.0, 2.2, 3.2, 0.8),
      (30, 160.0, 0.6, 1.2, 0.3),
    ];

    for (final (count, radius, speed, starSize, opacity) in rings) {
      for (int i = 0; i < count; i++) {
        final baseAngle = 2 * pi * i / count;
        final angle = baseAngle - 2 * pi * progress * speed;
        final x = cx + radius * cos(angle);
        final y = cy + radius * sin(angle);

        // Subtle twinkle per star
        final twinkle = 0.5 + 0.5 * sin(baseAngle * 3 + progress * 2 * pi);
        final paint = Paint()
          ..color = _starColor(i, opacity * twinkle)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), starSize, paint);
      }
    }
  }

  Color _starColor(int index, double opacity) {
    const colors = [
      Color(0xFF60B4FF), // blue
      Color(0xFFBB86FC), // purple
      Color(0xFFFFFFFF), // white
      Color(0xFF80DEEA), // cyan
    ];
    return colors[index % colors.length].withOpacity(opacity.clamp(0.05, 1.0));
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.progress != progress;
}
