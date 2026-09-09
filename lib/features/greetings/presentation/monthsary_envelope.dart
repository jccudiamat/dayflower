import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

final pairGreetingProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null) return null;
  return ref.read(supabaseClientProvider).from('pair_greetings').select()
      .eq('pair_id', pair.id).order('created_at', ascending: false).limit(1).maybeSingle();
});

class MonthsaryEnvelope extends ConsumerStatefulWidget {
  const MonthsaryEnvelope({super.key});
  @override
  ConsumerState<MonthsaryEnvelope> createState() => _MonthsaryEnvelopeState();
}

class _MonthsaryEnvelopeState extends ConsumerState<MonthsaryEnvelope> {
  String? _readKey;
  bool _opened = false;

  Future<void> _loadRead(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && _readKey == key) setState(() => _opened = prefs.getBool(key) ?? false);
  }

  Future<void> _open(Map<String, dynamic> card, String key) async {
    setState(() => _opened = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xfffff8ee),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Align(alignment: Alignment.centerRight, child: IconButton(
          tooltip: 'Close greeting', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
        if (card['artwork'] == 'monthsary_53')
          Semantics(label: card['title'] as String, image: true,
            child: Image.asset('assets/images/monthsary_53.png', excludeFromSemantics: true)),
        Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 28), child: Column(children: [
          Text(card['title'] as String, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 25, height: 1.2, fontWeight: FontWeight.bold, color: Color(0xff9d2540))),
          const SizedBox(height: 16),
          Text(card['message'] as String, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.6, color: Color(0xff743441))),
          const SizedBox(height: 20),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep this little moment ♥')),
        ])),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(pairGreetingProvider).valueOrNull;
    final user = ref.watch(currentUserIdProvider);
    if (card == null || user == null) return const SizedBox.shrink();
    final key = 'greeting_opened_${user}_${card['id']}';
    if (_readKey != key) {
      _readKey = key;
      _opened = false;
      _loadRead(key);
    }
    return Padding(padding: const EdgeInsets.only(bottom: 18), child: Material(
      color: const Color(0xffffe4eb),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: () => _open(card, key), child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Stack(alignment: Alignment.center, children: [
            Icon(_opened ? Icons.drafts_rounded : Icons.mail_rounded, size: 66, color: const Color(0xffe7a0b4)),
            const Icon(Icons.favorite_rounded, size: 23, color: Color(0xffae3457)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_opened ? 'A keepsake for us' : 'A little surprise for us',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xff852640))),
            const SizedBox(height: 5),
            Text(_opened ? 'Open our greeting again' : 'Our 53rd monthsary • Tap to open',
              style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xff743441))),
          ])),
          if (!_opened) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.circle, size: 9, color: Color(0xffae3457))),
        ]),
      )),
    ));
  }
}
