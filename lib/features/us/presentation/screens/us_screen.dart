import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav.dart';

class UsScreen extends StatefulWidget {
  const UsScreen({super.key});

  @override
  State<UsScreen> createState() => _UsScreenState();
}

class _UsScreenState extends State<UsScreen> {
  final _meCtrl = TextEditingController(text: 'Jessie');
  final _herCtrl = TextEditingController(text: 'Sheena');
  final _myPetCtrl = TextEditingController(text: 'Hubby');
  final _herPetCtrl = TextEditingController(text: 'Wifey');
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _myPetCtrl.addListener(_onPetChange);
    _herPetCtrl.addListener(_onPetChange);
  }

  void _onPetChange() => setState(() {});

  @override
  void dispose() {
    _myPetCtrl.removeListener(_onPetChange);
    _herPetCtrl.removeListener(_onPetChange);
    _meCtrl.dispose();
    _herCtrl.dispose();
    _myPetCtrl.dispose();
    _herPetCtrl.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _AppHeader(onSettingsTap: () => context.go(Routes.settings)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Couple card
                    _DsCard(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 84,
                            height: 48,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: _Avatar(
                                      initials: 'L',
                                      color: AppColors.brand,
                                      size: 48),
                                ),
                                Positioned(
                                  left: 36,
                                  child: _Avatar(
                                      initials: 'S',
                                      color: AppColors.sage,
                                      size: 48),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_myPetCtrl.text} & ${_herPetCtrl.text}',
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF160810),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Together 182 days · Day 47 streak 🔥',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Stats row
                    Row(
                      children: [
                        for (final stat in const [
                          ('🌷', '47', 'Tulips'),
                          ('🔥', '47', 'Streak'),
                          ('💗', '312', 'Hearts'),
                          ('🗓', '182', 'Days'),
                        ]) ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1228),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Text(stat.$1,
                                      style: const TextStyle(fontSize: 22)),
                                  const SizedBox(height: 4),
                                  Text(
                                    stat.$2,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stat.$3.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brand,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (stat.$3 != 'Days') const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _SectionLabel(text: 'Endearments'),
                    const SizedBox(height: 8),
                    // Endearments card
                    _DsCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _EditField(
                                  label: 'Your name',
                                  controller: _meCtrl,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _EditField(
                                  label: "Partner's name",
                                  controller: _herCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _EditField(
                                  label: 'They call you',
                                  controller: _myPetCtrl,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _EditField(
                                  label: 'You call them',
                                  controller: _herPetCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _PrimaryButton(
                            label: _saved ? '✓ Saved!' : 'Save endearments',
                            onTap: _save,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Premium card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF160810), Color(0xFF2D0A20)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dayflower Premium',
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                                  Text(
                                    r'$4.99 / month per couple',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: .4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final f in const [
                            '🌷 Rare & seasonal flower variants',
                            '🌿 Full garden view',
                            '📷 Unlimited photo strips',
                            '📸 Flower recognition (TFLite)',
                            '🔥 Streak repair',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: .5),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          _PrimaryButton(
                            label: 'Unlock Premium 💗',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}

// ── Shared atoms ─────────────────────────────────────────────────────────────

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.onSettingsTap});
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_florist_rounded,
                size: 30,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: '2',
                  style: TextStyle(color: AppColors.brand),
                ),
                TextSpan(
                  text: 'Lip',
                  style: TextStyle(color: Color(0xFF5C1828)),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSettingsTap,
            child: const Text('⚙️', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.color, this.size = 48});
  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .18), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: size * .38,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
          letterSpacing: 1.2,
          height: 1.2,
        ),
      ),
    );
  }
}

class _DsCard extends StatelessWidget {
  const _DsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF160810),
            height: 1.6,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            filled: true,
            fillColor: AppColors.background,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brand, AppColors.brandDark],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: .25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
