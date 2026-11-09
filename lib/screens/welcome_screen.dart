import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/custom_button.dart';

class WelcomeScreen extends StatelessWidget {
  final ValueChanged<UserRole> onSelectRole;

  const WelcomeScreen({super.key, required this.onSelectRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(),
              const SizedBox(height: 24),

              // Indigo Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.indigo950,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigo950.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.auto_awesome, color: AppColors.orange400, size: 24),
                    ),
                    const SizedBox(height: 24),
                    RichText(
                      text: const TextSpan(
                        text: 'Study spaces,\n',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                          letterSpacing: -1,
                        ),
                        children: [
                          TextSpan(
                            text: 'made simple.',
                            style: TextStyle(
                              color: AppColors.orange400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Discover the right desk or manage your library—all in one place.',
                      style: TextStyle(
                        color: AppColors.indigo200,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('100+', 'Libraries'),
                          _buildStatItem('4.9', 'Avg. rating'),
                          _buildStatItem('24×7', 'Support'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              const Center(
                child: Text(
                  'Choose how you want to continue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate400,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              CustomButton(
                label: 'Student Login / Signup',
                leading: const Icon(Icons.school, color: Colors.white, size: 20),
                onPressed: () => onSelectRole(UserRole.student),
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Library Owner Login / Signup',
                variant: ButtonVariant.secondary,
                leading: const Icon(Icons.apartment, color: AppColors.slate800, size: 20),
                onPressed: () => onSelectRole(UserRole.admin),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'By continuing, you agree to Jodo’s Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.slate400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.indigo300,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
