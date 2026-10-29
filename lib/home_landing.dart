import 'package:flutter/material.dart';

import 'website_theme.dart';

class HomeLanding extends StatelessWidget {
  final String? welcome;
  final VoidCallback onBrowse;
  final VoidCallback? onLogin;

  const HomeLanding({
    super.key,
    this.welcome,
    required this.onBrowse,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/child_reading.webp',
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          excludeFromSemantics: true,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                websiteBackground,
                Color(0xf0f6f8f4),
                Color(0x55f6f8f4),
                Color(0x00f6f8f4),
              ],
              stops: [0, 0.24, 0.6, 1],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: websiteBackground.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (welcome != null && welcome!.isNotEmpty) ...[
                          Text(
                            welcome!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'NORTHEAST GEORGIA',
                          style: TextStyle(
                            color: websiteTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Find the resources and support you need',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: websiteInk,
                                fontWeight: FontWeight.bold,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Connecting families with local services, trusted providers, and a supportive community.',
                          style: TextStyle(
                            color: Color(0xff52686b),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onBrowse,
                            icon: const Icon(Icons.business),
                            label: const Text('Browse providers'),
                          ),
                        ),
                        if (onLogin != null) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: onLogin,
                            child: const Text('Login'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
