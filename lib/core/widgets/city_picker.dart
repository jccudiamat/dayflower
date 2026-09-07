import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/city_search.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Opens the city picker. Resolves to the chosen place, or null.
Future<CityResult?> showCityPicker(BuildContext context) {
  return showModalBottomSheet<CityResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CityPickerSheet(),
  );
}

/// Search a town or city by name and pick it.
///
/// ⚠️ Every keystroke could be a network call, so it isn't one. [_debounce]
/// holds the request until the typing pauses — somebody spelling out
/// "Tuguegarao" makes one request, not ten, and the endpoint being free is
/// not a reason to hammer it.
///
/// ⚠️ Results are also **sequenced**. A slow request for "Tug" landing after
/// a fast one for "Tuguegarao" would replace the right answers with older,
/// vaguer ones; [_generation] makes a late response for a stale query
/// arrive to a closed door.
class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({super.key});

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  Timer? _debounce;
  var _generation = 0;
  var _query = '';
  var _searching = false;
  List<CityResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();

    if (value.trim().length < CitySearch.minQueryLength) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String value) async {
    final mine = ++_generation;
    final found = await CitySearch.search(value);
    if (!mounted || mine != _generation) return;
    setState(() {
      _results = found;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: AppSpace.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Where you are', style: AppText.title())),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.xmark, color: AppColors.muted),
              ),
            ],
          ),
          Text(
            'Your town or city — it sets the distance between you and the '
            'clock on their side.',
            style: AppText.caption(),
          ),
          const SizedBox(height: AppSpace.sm),
          TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (v) {
              _debounce?.cancel();
              _run(v);
            },
            decoration: const InputDecoration(
              hintText: 'e.g. Tuguegarao City',
              prefixIcon: Icon(CupertinoIcons.search, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _body(),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_query.trim().length < CitySearch.minQueryLength) {
      return _hint('Start typing a town or city.');
    }

    if (_results.isEmpty) {
      // Deliberately covers both "no such place" and "the lookup failed" —
      // they are the same thing to somebody staring at an empty list, and
      // the honest advice for both is to try the spelling again.
      return _hint(
        'Nothing found. Check the spelling, or try the nearest bigger town.',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final city = _results[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(city.name, style: AppText.body(AppColors.ink)),
          subtitle: Text(
            [
              if (city.region != null && city.region!.isNotEmpty) city.region!,
              if (city.country != null && city.country!.isNotEmpty)
                city.country!,
            ].join(', '),
            style: AppText.caption(),
          ),
          trailing: Text(
            city.timezone.split('/').last.replaceAll('_', ' '),
            style: AppText.caption(),
          ),
          onTap: () => Navigator.of(context).pop(city),
        );
      },
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Text(text, style: AppText.caption()),
      );
}
