import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/services/legal_links.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../widgets/startup_brand.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StartupSurface(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 720;
          return SingleChildScrollView(
              child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: DayflowerWordmark()),
                    const Spacer(),
                    const SizedBox(height: 28),
                    WelcomeWidgetPreview(height: compact ? 224 : 278),
                    const SizedBox(height: 28),
                    Text('A little closer.\nEvery day.',
                        textAlign: TextAlign.center,
                        style: AppText.display().copyWith(
                            fontSize: compact ? 34 : 40,
                            height: 1.08,
                            letterSpacing: -1.3,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Text(
                        'Share your day. Send a little love.\nRight on each other’s home screen.',
                        textAlign: TextAlign.center,
                        style: AppText.body(AppColors.body)
                            .copyWith(fontSize: 15, height: 1.5)),
                    const SizedBox(height: 28),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.isDark
                            ? AppColors.onDark
                            : AppColors.darkSurface,
                        foregroundColor: AppColors.isDark
                            ? AppColors.darkSurface
                            : AppColors.onDark,
                        minimumSize: const Size.fromHeight(56),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => context.go(Routes.login),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                                child: Text('Continue with email',
                                    textAlign: TextAlign.center,
                                    style: AppText.subtitle(AppColors.isDark
                                        ? AppColors.darkSurface
                                        : AppColors.onDark))),
                            const SizedBox(width: 12),
                            const AppIcon(Icons.arrow_forward, size: 18),
                          ]),
                    ),
                    const SizedBox(height: 12),
                    Text('By continuing, you agree to our',
                        textAlign: TextAlign.center,
                        style: AppText.caption(AppColors.body)),
                    Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        children: [
                          TextButton(
                              onPressed: () =>
                                  openLegalPage(context, ref, LegalPage.terms),
                              child: Text('Terms of Service',
                                  style: AppText.caption(AppColors.body))),
                          TextButton(
                              onPressed: () => openLegalPage(
                                  context, ref, LegalPage.privacy),
                              child: Text('Privacy Policy',
                                  style: AppText.caption(AppColors.body))),
                        ]),
                  ]),
            )),
          ));
        }),
      );
}
