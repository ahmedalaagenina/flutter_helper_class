import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme.dart';
import 'package:idara_esign/features/onboarding/presentation/widgets/floating_badge.dart';

class WelcomePageIconAnimation extends StatelessWidget {
  const WelcomePageIconAnimation({super.key, required this.isSmallScreen});

  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background blur effect
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFFC7D2FE), const Color(0xFF99F6E4)],
              ),
              borderRadius: BorderRadius.circular(110),
            ),
            child: BackdropFilter(
              filter: const ColorFilter.mode(
                Colors.transparent,
                BlendMode.srcOver,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(110),
                ),
              ),
            ),
          ),

          // Document illustration stack
          Positioned(
            top: 10,
            right: isSmallScreen ? 20 : 40,
            child: Transform.rotate(
              angle: 0.1, // ~6 degrees
              child: DocumentCard(
                color: Theme.of(context).colorScheme.surface,
                borderColor: const Color(0xFFE2E8F0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 120,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main document card
          Positioned(
            top: 20,
            left: isSmallScreen ? 20 : 40,
            child: Transform.rotate(
              angle: -0.05, // ~-3 degrees
              child: DocumentCard(
                color: Theme.of(context).colorScheme.surface,
                borderColor: const Color(0xFFE2E8F0),
                shadowColor: AppColors.primary.withOpacity(0.1),
                elevation: 8,
                child: Column(
                  children: [
                    // Document header
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: const Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: const Color(0xFF34D399),
                          ),
                        ],
                      ),
                    ),

                    // Document content
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              Container(
                                width: 100,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 80,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // Signature area (original - no icon inside)
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFC7D2FE),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFEEF2FF).withOpacity(0.3),
                            ),
                            child: const Center(
                              child: Text(
                                'SIGN HERE',
                                style: TextStyle(
                                  color: Color(0xFF818CF8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Verified badge
          Positioned(
            top: 60,
            right: 0,
            child: FloatingBadge(
              icon: Icons.verified,
              color: const Color(0xFF10B981),
              delay: 0,
            ),
          ),

          // Pen badge - positioned above "SIGN HERE"
          Positioned(
            bottom: 90,
            right: isSmallScreen ? 0 : 15,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradientOf(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF4F46E5).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.create,
                size: 16,
                color: Colors.white, // Changed to white
              ),
            ),
          ),
          // Lock badge
          Positioned(
            bottom: 40,
            left: isSmallScreen ? 0 : 20,
            child: FloatingBadge(
              icon: Icons.lock,
              color: const Color(0xFF8B5CF6),
              delay: 1000,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom document card widget
class DocumentCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  final Color? shadowColor;
  final double elevation;

  const DocumentCard({
    super.key,
    required this.child,
    required this.color,
    required this.borderColor,
    this.shadowColor,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? Colors.grey.withOpacity(0.1),
            blurRadius: elevation * 4,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      child: child,
    );
  }
}
