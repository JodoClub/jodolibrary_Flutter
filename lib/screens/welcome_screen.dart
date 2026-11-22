import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/custom_button.dart';
import 'enquiry_screen.dart';

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
              const BrandLogo(height: 52),
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
                        children: [
                          Expanded(child: _buildStatItem('100+', 'Libraries')),
                          Expanded(child: _buildStatItem('4.9', 'Avg. rating')),
                          Expanded(child: _buildStatItem('24×7', 'Support')),
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
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnquiryScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_business_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Want to list your library in your city?',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 1),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.slate600,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                                children: [
                                  TextSpan(text: 'Or have any enquiry? '),
                                  TextSpan(
                                    text: 'Contact Us →',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ],
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.indigo300,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
