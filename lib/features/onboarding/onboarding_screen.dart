import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/preferences_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      title: 'Welcome to Smart Hydroponics',
      description: 'Revolutionary soil-less farming technology that grows plants faster and healthier using nutrient-rich water solutions.',
      icon: Icons.eco,
      color: const Color(0xFF00B4D8),
    ),
    OnboardingItem(
      title: 'Intelligent Monitoring System',
      description: 'Advanced sensors track water levels, pH balance, nutrients, and environmental conditions in real-time.',
      icon: Icons.sensors,
      color: const Color(0xFF00B4D8),
    ),
    OnboardingItem(
      title: 'Plant Growth Analytics',
      description: 'Monitor lettuce growth stages with detailed analytics, progress tracking, and automated care recommendations.',
      icon: Icons.analytics,
      color: const Color(0xFF16A34A),
    ),
    OnboardingItem(
      title: 'Smart Alerts & Care',
      description: 'Receive timely notifications for watering, nutrient adjustments, and maintenance to ensure optimal plant health.',
      icon: Icons.notifications_active,
      color: const Color(0xFFF59E0B),
    ),
    OnboardingItem(
      title: 'Sustainable Agriculture',
      description: 'Conserve water and reduce chemical use while achieving higher yields through precision farming technology.',
      icon: Icons.spa,
      color: const Color(0xFF16A34A),
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _completeOnboarding() async {
    await PreferencesHelper.setHasSeenOnboarding(true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _nextPage() {
    if (_currentPage < _onboardingItems.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE9FFF4), Color(0xFFBFF3D8), Color(0xFF77D9AA)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _onboardingItems.length,
                    itemBuilder: (context, index) {
                      return OnboardingPage(
                        item: _onboardingItems[index],
                      );
                    },
                  ),
                ),

                // Bottom indicators and button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Page indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingItems.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == index
                                  ? _onboardingItems[_currentPage].color
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Next/Get Started button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _onboardingItems[_currentPage].color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: _onboardingItems[_currentPage].color.withValues(alpha: 0.3),
                          ),
                          child: Text(
                            _currentPage == _onboardingItems.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingItem item;

  const OnboardingPage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with animated background
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withValues(alpha: 0.1),
              border: Border.all(
                color: item.color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              item.icon,
              size: 60,
              color: item.color,
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}