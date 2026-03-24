import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'client_tracking_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildCompatibilityCheck(),
                  _buildOnboardingPage(
                    title: 'Track from anywhere',
                    description:
                        'Monitor your entire herd in real-time using high-precision satellite telemetry, even in remote grazing sectors.',
                    icon: Icons.satellite_alt_outlined,
                  ),
                  _buildRoleSelection(),
                ],
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityCheck() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync,
              color: AppColors.onPrimaryContainer,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Initializing System',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Checking hardware requirements...',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                _buildCheckItem('Android Version', true),
                const SizedBox(height: 16),
                _buildCheckItem('GPS Availability', true),
                const SizedBox(height: 16),
                _buildCheckItem('Network Connection', true),
                const SizedBox(height: 16),
                _buildCheckItem('Permissions', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isDone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: isDone ? AppColors.onSurface : AppColors.onSurfaceVariant,
          ),
        ),
        isDone
            ? const Icon(
                Icons.check_circle,
                color: AppColors.primaryContainer,
                size: 24,
              )
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
      ],
    );
  }

  Widget _buildOnboardingPage({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Center(
              child: Icon(icon, size: 120, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Setup Profile',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'How will you use BovineTrack today?',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 48),
          _buildRoleCard(
            title: 'Server (Tracker Monitor)',
            description:
                'Best for Ranch Managers. View dashboards, manage geofences, and receive herd alerts.',
            icon: Icons.grid_view_rounded,
            color: AppColors.primary,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
          ),
          const SizedBox(height: 24),
          _buildRoleCard(
            title: 'Client (Tracked Device)',
            description:
                'Install this on ruggedized handhelds or tags to broadcast location data to the ranch hub.',
            icon: Icons.sensors,
            color: AppColors.secondaryContainer,
            iconColor: AppColors.onSecondaryContainer,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ClientTrackingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    if (_currentPage == 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => _pageController.jumpToPage(2),
            child: Text(
              'Skip',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Row(children: List.generate(3, (index) => _buildDot(index))),
          ElevatedButton(
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 56)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Next'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      height: 8,
      width: _currentPage == index ? 24 : 8,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: _currentPage == index
            ? AppColors.primary
            : AppColors.outlineVariant,
      ),
    );
  }
}
