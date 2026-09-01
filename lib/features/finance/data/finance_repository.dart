import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';
import 'finance_models.dart';

// The screens import this file for everything finance; the models moved out
// when there got to be enough of them to deserve their own file, and this
// keeps that a detail of the data layer rather than a churn of imports.
export 'finance_models.dart';
export 'finance_summary.dart';

class FinanceRepository {
  FinanceRepository(this._client);
  final SupabaseClient _client;

  /* ── Streams ─────────────────────────────────────────────── */

  /// Archived rows are included: the summary filters them, and a screen
  /// that offers "show archived" would otherwise need a second query.
  Stream<List<FinanceAccount>> watchAccounts(String pairId) => _client
      .from('finance_accounts')
      .stream(primaryKey: ['id'])
      .eq('pair_id', pairId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(FinanceAccount.fromMap).toList());

  /// **Newest first** — `ascending: false` is spelled out because `.order()`
  /// descends by default and a bare call reads as the opposite.
  Stream<List<FinanceEntry>> watchEntries(String pairId) => _client
      .from('finance_entries')
      .stream(primaryKey: ['id'])
      .eq('pair_id', pairId)
      .order('occurred_on', ascending: false)
      .map((rows) => rows.map(FinanceEntry.fromMap).toList());

  Stream<List<FinanceBudget>> watchBudgets(String pairId) => _client
      .from('finance_budgets')
      .stream(primaryKey: ['id'])
      .eq('pair_id', pairId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(FinanceBudget.fromMap).toList());

  Stream<List<FxRate>> watchRates(String pairId) => _client
      .from('finance_rates')
      .stream(primaryKey: ['id'])
      .eq('pair_id', pairId)
      .map((rows) => rows.map(FxRate.fromMap).toList());

  /* ── Settings ────────────────────────────────────────────── */

  /// The currency every total is shown in. One row per person per pair —
  /// two partners in different countries will not agree on which it is.
  Stream<String> watchMainCurrency(String pairId, String userId) => _client
      .from('finance_settings')
      .stream(primaryKey: ['id'])
      .eq('pair_id', pairId)
      .map((rows) {
        for (final row in rows) {
          if (row['user_id'] == userId) {
            return row['main_currency'] as String? ?? 'PHP';
          }
        }
        return 'PHP';
      });

  Future<void> setMainCurrency({
    required String pairId,
    required String userId,
    required String currency,
  }) async {
    await _client.from('finance_settings').upsert(
      {
        'pair_id': pairId,
        'user_id': userId,
        'main_currency': currency,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'pair_id,user_id',
    );
  }

  /* ── Accounts ────────────────────────────────────────────── */

  Future<void> saveAccount({
    String? id,
    required String pairId,
    required String? ownerId,
    required String name,
    required AccountClass accountClass,
    required AccountKind kind,
    String? subkind,
    required double openingBalance,
    required String currency,
    required String emoji,
    double? targetAmount,
    DateTime? targetDate,
    double? creditLimit,
    double? interestRate,
    required bool visibleToPartner,
    bool includeInNetWorth = true,
    bool archived = false,
    required String userId,
  }) async {
    final values = {
      'owner_id': ownerId,
      'name': name.trim(),
      'class': accountClass.name,
      'kind': kind.name,
      'subkind': subkind,
      'opening_balance': openingBalance,
      'currency': currency,
      'emoji': emoji,
      'target_amount': targetAmount,
      'target_date': targetDate == null ? null : dateOnly(targetDate),
      'credit_limit': creditLimit,
      'interest_rate': interestRate,
      // A shared account is forced visible by a trigger in 0016; sending
      // the honest value here keeps the client and the DB telling the same
      // story rather than relying on the trigger to paper over a lie.
      'visible_to_partner': ownerId == null ? true : visibleToPartner,
      'include_in_net_worth': includeInNetWorth,
      'archived': archived,
    };
    if (id == null) {
      await _client.from('finance_accounts').insert({
        ...values,
        'pair_id': pairId,
        'created_by': userId,
      });
    } else {
      await _client.from('finance_accounts').update(values).eq('id', id);
    }
  }

  /// Entries that referenced it survive with a null `account_id`
  /// (`on delete set null` in 0016) — the spending history outlives the
  /// bank you closed.
  Future<void> deleteAccount(String id) async {
    await _client.from('finance_accounts').delete().eq('id', id);
  }

  /* ── Budgets ─────────────────────────────────────────────── */

  Future<void> saveBudget({
    String? id,
    required String pairId,
    required String? ownerId,
    required BudgetScope scope,
    required String name,
    String? category,
    required String emoji,
    required double limitAmount,
    required String currency,
    required FinancePeriod period,
    String? fundingAccountId,
    bool rollover = false,
    DateTime? startsOn,
    bool archived = false,
    required String userId,
  }) async {
    final values = {
      'owner_id': ownerId,
      'scope': scope.name,
      'name': name.trim(),
      // The DB rejects a category budget with no category, so normalise
      // here rather than trusting the form's leftover state.
      'category': scope == BudgetScope.category ? category : null,
      'emoji': emoji,
      'limit_amount': limitAmount,
      'currency': currency,
      'period': period.name,
      'funding_account_id': fundingAccountId,
      'rollover': rollover,
      'starts_on': dateOnly(startsOn ?? DateTime.now()),
      'archived': archived,
    };
    if (id == null) {
      await _client.from('finance_budgets').insert({
        ...values,
        'pair_id': pairId,
        'created_by': userId,
      });
    } else {
      await _client.from('finance_budgets').update(values).eq('id', id);
    }
  }

  Future<void> deleteBudget(String id) async {
    await _client.from('finance_budgets').delete().eq('id', id);
  }

  /* ── Entries ─────────────────────────────────────────────── */

  Future<void> saveEntry({
    String? id,
    required String pairId,
    required String? ownerId,
    required String? accountId,
    required String? toAccountId,
    String? budgetId,
    required EntryKind kind,
    required String category,
    required double amount,
    required String currency,
    double? fxRate,
    String? note,
    required DateTime occurredOn,
    required String userId,
  }) async {
    final trimmed = note?.trim();
    final values = {
      'owner_id': ownerId,
      'account_id': accountId,
      // Both of these are rejected by DB checks in the wrong combination,
      // so normalise rather than trusting the form.
      'to_account_id': kind == EntryKind.transfer ? toAccountId : null,
      'budget_id': kind == EntryKind.expense ? budgetId : null,
      'kind': kind.name,
      'category': category,
      'amount': amount,
      'currency': currency,
      'fx_rate': fxRate,
      'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'occurred_on': dateOnly(occurredOn),
    };
    if (id == null) {
      await _client.from('finance_entries').insert({
        ...values,
        'pair_id': pairId,
        'created_by': userId,
      });
    } else {
      await _client.from('finance_entries').update(values).eq('id', id);
    }
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('finance_entries').delete().eq('id', id);
  }

  /* ── Recurring ───────────────────────────────────────────── */

  Stream<List<RecurringRule>> watchRecurring(String pairId) => _client
      .from('finance_recurring')
      .stream(primaryKey: ['id'])
      .eq('pair_id', pairId)
      .order('next_due', ascending: true)
      .map((rows) => rows.map(RecurringRule.fromMap).toList());

  Future<void> saveRecurring({
    String? id,
    required String pairId,
    required String? ownerId,
    required String name,
    required EntryKind kind,
    required String category,
    required String emoji,
    required double amount,
    required String currency,
    String? accountId,
    String? toAccountId,
    String? budgetId,
    required RecurringInterval interval,
    required DateTime nextDue,
    DateTime? endsOn,
    required bool autoPost,
    bool active = true,
    required String userId,
  }) async {
    final values = {
      'owner_id': ownerId,
      'name': name.trim(),
      'kind': kind.name,
      'category': category,
      'emoji': emoji,
      'amount': amount,
      'currency': currency,
      'account_id': accountId,
      'to_account_id': kind == EntryKind.transfer ? toAccountId : null,
      'budget_id': kind == EntryKind.expense ? budgetId : null,
      'interval': interval.name,
      'next_due': dateOnly(nextDue),
      'ends_on': endsOn == null ? null : dateOnly(endsOn),
      'auto_post': autoPost,
      'active': active,
    };
    if (id == null) {
      await _client.from('finance_recurring').insert({
        ...values,
        'pair_id': pairId,
        'created_by': userId,
      });
    } else {
      await _client.from('finance_recurring').update(values).eq('id', id);
    }
  }

  Future<void> deleteRecurring(String id) async {
    await _client.from('finance_recurring').delete().eq('id', id);
  }

  /// Turns one due occurrence of [rule] into a real entry and advances the
  /// rule to its next date.
  ///
  /// The entry is dated the day it was *due*, not today: a subscription that
  /// billed on the 1st belongs in the 1st's numbers even if the app was not
  /// opened until the 9th. That is also what makes catching up on several
  /// missed periods produce a correct month rather than a pile of entries
  /// all dated today.
  Future<void> postOccurrence({
    required RecurringRule rule,
    required String userId,
  }) async {
    await saveEntry(
      pairId: rule.pairId,
      ownerId: rule.ownerId,
      accountId: rule.accountId,
      toAccountId: rule.toAccountId,
      budgetId: rule.budgetId,
      kind: rule.kind,
      category: rule.category,
      amount: rule.amount,
      currency: rule.currency,
      note: rule.name,
      occurredOn: rule.nextDue,
      userId: userId,
    );

    final next = rule.interval.next(rule.nextDue);
    await _client.from('finance_recurring').update({
      'next_due': dateOnly(next),
      // A rule that has run past its end date stops rather than being
      // deleted — the entries it already posted still refer to it.
      'active': rule.endsOn == null || !next.isAfter(rule.endsOn!),
    }).eq('id', rule.id);
  }

  /// Posts every occurrence that has come due for the rules that opted into
  /// [RecurringRule.autoPost], catching up one period at a time.
  ///
  /// Returns how many entries were written. Rules that need confirming are
  /// left alone for the screen to surface.
  ///
  /// The loop is capped: a yearly rule left dormant for a decade should
  /// produce ten entries, but a corrupt date must not spin forever.
  Future<int> postDueAutomatic({
    required List<RecurringRule> rules,
    required String userId,
  }) async {
    final now = DateTime.now();
    var posted = 0;
    for (final rule in rules) {
      if (!rule.active || !rule.autoPost || rule.isFinished) continue;
      var current = rule;
      var guard = 0;
      while (current.isDue(now) && !current.isFinished && guard++ < 60) {
        await postOccurrence(rule: current, userId: userId);
        posted++;
        // Walk forward locally rather than re-reading: the stream will
        // catch up on its own, and re-querying inside the loop would race
        // with it.
        current = RecurringRule(
          id: current.id,
          pairId: current.pairId,
          ownerId: current.ownerId,
          name: current.name,
          kind: current.kind,
          category: current.category,
          emoji: current.emoji,
          amount: current.amount,
          currency: current.currency,
          accountId: current.accountId,
          toAccountId: current.toAccountId,
          budgetId: current.budgetId,
          interval: current.interval,
          nextDue: current.interval.next(current.nextDue),
          endsOn: current.endsOn,
          autoPost: current.autoPost,
          active: current.active,
          createdBy: current.createdBy,
        );
      }
    }
    return posted;
  }

  /* ── Holdings ────────────────────────────────────────────── */

  Stream<List<Holding>> watchHoldings(String pairId) => _client
      .from('finance_holdings')
      .stream(primaryKey: ['id'])
      .eq('pair_id', pairId)
      .map((rows) => rows.map(Holding.fromMap).toList());

  Future<void> saveHolding({
    String? id,
    required String pairId,
    required String accountId,
    required String symbol,
    String? label,
    required double quantity,
    required double unitCost,
    required double unitPrice,
    required String currency,
    required String userId,
  }) async {
    final values = {
      'account_id': accountId,
      'symbol': symbol.trim().toUpperCase(),
      'label': label?.trim().isEmpty ?? true ? null : label!.trim(),
      'quantity': quantity,
      'unit_cost': unitCost,
      'unit_price': unitPrice,
      'currency': currency,
      // Stamped on every save: a price is only meaningful next to the date
      // it was true, and this is the only moment we know it was current.
      'price_as_of': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await _client.from('finance_holdings').insert({
        ...values,
        'pair_id': pairId,
        'created_by': userId,
      });
    } else {
      await _client.from('finance_holdings').update(values).eq('id', id);
    }
  }

  Future<void> deleteHolding(String id) async {
    await _client.from('finance_holdings').delete().eq('id', id);
  }

  /* ── Exchange rates ──────────────────────────────────────── */

  Future<void> saveRate({
    required String pairId,
    required String currency,
    required double usdRate,
    required bool pinned,
    required String userId,
  }) async {
    await _client.from('finance_rates').upsert(
      {
        'pair_id': pairId,
        'currency': currency,
        'usd_rate': usdRate,
        'source': 'manual',
        'pinned': pinned,
        'as_of': DateTime.now().toUtc().toIso8601String(),
        'updated_by': userId,
      },
      onConflict: 'pair_id,currency',
    );
  }

  Future<void> deleteRate(String pairId, String currency) async {
    await _client
        .from('finance_rates')
        .delete()
        .eq('pair_id', pairId)
        .eq('currency', currency);
  }

  /// Pulls today's rates and writes the ones nobody has pinned.
  ///
  /// `open.er-api.com` is used because it needs no API key — a key would
  /// have to be bundled into the APK, where anyone who unzips it can read
  /// it. Returns how many rows were updated, or throws so the caller can
  /// say *why* nothing happened; a refresh that silently does nothing is
  /// worse than one that fails out loud.
  Future<int> refreshLiveRates({
    required String pairId,
    required String userId,
    required List<String> currencies,
    required Set<String> pinned,
  }) async {
    final wanted = currencies
        .where((c) => c != 'USD' && !pinned.contains(c))
        .toSet();
    if (wanted.isEmpty) return 0;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    Map<String, dynamic> rates;
    try {
      final request = await client
          .getUrl(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('rates returned ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      rates = (decoded['rates'] as Map?)?.cast<String, dynamic>() ?? {};
    } finally {
      client.close(force: true);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <Map<String, dynamic>>[];
    for (final currency in wanted) {
      final value = toDoubleOrNull(rates[currency]);
      if (value == null || value <= 0) continue;
      rows.add({
        'pair_id': pairId,
        'currency': currency,
        'usd_rate': value,
        'source': 'live',
        'pinned': false,
        'as_of': now,
        'updated_by': userId,
      });
    }
    if (rows.isEmpty) return 0;

    await _client
        .from('finance_rates')
        .upsert(rows, onConflict: 'pair_id,currency');
    return rows.length;
  }

  /// `occurred_on` and friends are `date` columns, so send a date — a full
  /// timestamp gets truncated by Postgres in whatever zone it felt like.
  static String dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/* ── Providers ──────────────────────────────────────────────── */

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(supabaseClientProvider)),
);

final financeAccountsProvider =
    StreamProvider.autoDispose<List<FinanceAccount>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchAccounts(pair.id);
});

final financeEntriesProvider =
    StreamProvider.autoDispose<List<FinanceEntry>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchEntries(pair.id);
});

final financeBudgetsProvider =
    StreamProvider.autoDispose<List<FinanceBudget>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchBudgets(pair.id);
});

final financeRecurringProvider =
    StreamProvider.autoDispose<List<RecurringRule>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchRecurring(pair.id);
});

final financeHoldingsProvider =
    StreamProvider.autoDispose<List<Holding>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchHoldings(pair.id);
});

/// Every rate on file, indexed for conversion. Empty is a valid state and
/// means "single currency" — nothing needs converting until a second
/// currency exists.
final financeRatesProvider = StreamProvider.autoDispose<FxTable>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(FxTable.empty);
  return ref.watch(financeRepositoryProvider).watchRates(pair.id).map(
        (rates) => FxTable({for (final r in rates) r.currency: r}),
      );
});

/// The currency totals are shown in. Defaults to PHP until the user picks.
final financeMainCurrencyProvider = StreamProvider.autoDispose<String>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  final userId = ref.watch(currentUserIdProvider);
  if (pair == null || !pair.isLinked || userId == null) {
    return Stream.value('PHP');
  }
  return ref
      .watch(financeRepositoryProvider)
      .watchMainCurrency(pair.id, userId);
});

/// Currencies in play across every account and budget — what the rate
/// screen needs to offer, and what a live refresh should fetch.
final financeCurrenciesInUseProvider =
    Provider.autoDispose<List<String>>((ref) {
  final accounts = ref.watch(financeAccountsProvider).valueOrNull ?? const [];
  final budgets = ref.watch(financeBudgetsProvider).valueOrNull ?? const [];
  final main = ref.watch(financeMainCurrencyProvider).valueOrNull ?? 'PHP';
  final set = <String>{main, for (final a in accounts) a.currency};
  for (final b in budgets) {
    set.add(b.currency);
  }
  return set.toList()..sort();
});

/// A short list of currencies the pickers offer up front. Free text in the
/// DB, so this is convenience, not a constraint.
const kCommonCurrencies = <String>[
  'PHP', 'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'SGD',
  'HKD', 'KRW', 'CNY', 'AED', 'INR', 'MYR', 'THB', 'IDR', 'NZD', 'CHF',
];

/// Debug helper for the rate refresh, which is the one call here that can
/// fail for reasons outside the database.
void logFinanceError(String what, Object error) {
  debugPrint('finance $what failed: $error');
}
