import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.autoFocus = true,
    this.dark = false,
  });

  final int length;
  final bool autoFocus;
  final bool dark;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  String get _current => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (i) => FocusNode());
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onType(int index, String value) {
    if (value.isEmpty) {
      // Backspace
      _controllers[index].clear();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].clear();
      }
    } else {
      // Accept only last character in case of paste
      final char = value.characters.last;
      _controllers[index].text = char;
      _controllers[index].selection = TextSelection.collapsed(
        offset: _controllers[index].text.length,
      );
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    widget.onChanged?.call(_current);
    if (_current.length == widget.length) {
      widget.onCompleted(_current);
    }
  }

  /// Allow pasting full code
  void _onPaste(String pasted) {
    final digits = pasted.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (int i = 0; i < widget.length && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    final last = (digits.length - 1).clamp(0, widget.length - 1);
    _focusNodes[last].requestFocus();
    widget.onChanged?.call(_current);
    if (_current.length == widget.length) {
      widget.onCompleted(_current);
    }
  }

  /// The box, at its most comfortable. Boxes shrink from here when the
  /// space will not take six of them; they never grow past it, because a
  /// wide screen should not turn a PIN row into six billboards.
  static const _maxBox = 46.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    // 🔴 **Sized from the space it is actually given.** These were a fixed
    // 46 wide with 5 of margin either side — 336px for six of them — which
    // is fine full-bleed and overflows the moment the row is inside a card.
    // On the reset-password screen it ran the sixth box off the edge, and
    // an overflow in release does not draw the yellow stripes: it just
    // silently clips, so the field looked broken rather than too big.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final box = available.isFinite
            ? (((available - _gap * (widget.length - 1)) / widget.length)
                .clamp(30.0, _maxBox))
            : _maxBox;
        // Keeps the boxes' proportions as they shrink rather than leaving
        // tall thin slots.
        final height = box * (56 / _maxBox);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = _controllers[i].text.isNotEmpty;
            return Container(
              width: box,
              height: height,
              margin: EdgeInsets.only(right: i == widget.length - 1 ? 0 : _gap),
              child: TextFormField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 2, // allow 2 so we can detect new char
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: widget.dark ? AppColors.onDark : AppColors.ink,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: widget.dark
                      ? AppColors.darkSurface
                      : AppColors.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: filled
                          ? AppColors.secondary
                          : (widget.dark
                              ? AppColors.darkBorder
                              : Colors.transparent),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: filled
                          ? AppColors.secondary
                          : (widget.dark
                              ? AppColors.darkBorder
                              : Colors.transparent),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.secondary,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (val) => _onType(i, val),
                // Handle paste
                onTap: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null &&
                      data!.text!.length >= widget.length) {
                    _onPaste(data.text!);
                  }
                },
              ),
            );
          }),
        );
      },
    );
  }
}
