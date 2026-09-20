import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../pairing/data/pair_repository.dart';
import '../../tulip/data/flower_repository.dart';

/// Cards are rendered as images and use the existing durable photo delivery.
class MakeCardScreen extends ConsumerStatefulWidget {
  const MakeCardScreen({super.key});
  @override
  ConsumerState<MakeCardScreen> createState() => _MakeCardScreenState();
}

class _MakeCardScreenState extends ConsumerState<MakeCardScreen> {
  final _note = TextEditingController();
  String _occasion = 'Just because';
  bool _sending = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final user = ref.read(currentUserIdProvider);
    if (_sending || pair == null || user == null || _note.text.trim().isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      final bodyStyle =
          AppText.body(const Color(0xFF564A5E)).copyWith(fontSize: 28);
      final bodyPainter = TextPainter(
          text: TextSpan(text: _note.text.trim(), style: bodyStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center)
        ..layout(maxWidth: 560);
      final height =
          (bodyPainter.height + 500).clamp(900, double.infinity).ceil();
      bodyPainter.dispose();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFFCEDF4), BlendMode.src);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(32, 32, 656, height - 64),
              const Radius.circular(32)),
          Paint()..color = Colors.white);
      void line(String text, double top, TextStyle style) {
        final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center)
          ..layout(maxWidth: 560);
        painter.paint(canvas, Offset((720 - painter.width) / 2, top));
        painter.dispose();
      }

      line('DAYFLOWER', 96,
          AppText.label(const Color(0xFF746A80)).copyWith(fontSize: 20));
      line(_occasion, 192,
          AppText.display(const Color(0xFF1C1024)).copyWith(fontSize: 44));
      line(_note.text.trim(), 310,
          AppText.body(const Color(0xFF564A5E)).copyWith(fontSize: 28));
      line('A little something, just for you.', height - 114,
          AppText.caption(const Color(0xFF746A80)).copyWith(fontSize: 20));
      final picture = recorder.endRecording();
      final image = await picture.toImage(720, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (data == null) throw StateError('Card rendering failed');
      await ref.read(flowerRepositoryProvider).sendDayPhoto(
          pairId: pair.id,
          senderId: user,
          bytes: data.buffer.asUint8List(),
          fileExtension: 'png',
          origin: PhotoOrigin.card,
          toWidget: false,
          note: 'Dayflower card · $_occasion\n${_note.text.trim()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Your card is sent and saved in Memories.')));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Your card couldn’t send. Your note is still here.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Make a card')),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.all(AppSpace.screenInset),
                children: [
              Text('Send something from the heart.', style: AppText.title()),
              const SizedBox(height: AppSpace.md),
              Wrap(spacing: AppSpace.xs, children: [
                for (final title in ['Just because', 'I miss you', 'Thank you'])
                  ChoiceChip(
                      label: Text(title),
                      selected: title == _occasion,
                      onSelected: _sending
                          ? null
                          : (_) => setState(() => _occasion = title))
              ]),
              const SizedBox(height: AppSpace.md),
              Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                      color: AppColors.blush,
                      borderRadius: BorderRadius.circular(AppRadius.xl)),
                  child: Column(children: [
                    const AppIcon(CupertinoIcons.heart,
                        size: 48, color: AppColors.brand),
                    const SizedBox(height: AppSpace.sm),
                    Text(_occasion, style: AppText.hero()),
                    const SizedBox(height: AppSpace.sm),
                    TextField(
                        controller: _note,
                        enabled: !_sending,
                        maxLength: 240,
                        minLines: 4,
                        maxLines: 8,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Your note',
                            hintText: 'Something you want them to know…'))
                  ])),
              const SizedBox(height: AppSpace.md),
              ElevatedButton(
                  onPressed:
                      _sending || _note.text.trim().isEmpty ? null : _send,
                  child: Text(_sending ? 'Sending…' : 'Send your card')),
            ])),
      );
}
