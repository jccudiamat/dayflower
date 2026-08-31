import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/pair.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/pair_repository.dart';

class PairingState {
  const PairingState({
    this.isLoading = true,
    this.myInvite,
    this.errorMessage,
    this.isSubmittingCode = false,
  });

  final bool isLoading;
  final Pair? myInvite;
  final String? errorMessage;
  final bool isSubmittingCode;

  bool get isLinked => myInvite?.isLinked ?? false;

  PairingState copyWith({
    bool? isLoading,
    Pair? myInvite,
    String? errorMessage,
    bool clearError = false,
    bool? isSubmittingCode,
  }) {
    return PairingState(
      isLoading: isLoading ?? this.isLoading,
      myInvite: myInvite ?? this.myInvite,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmittingCode: isSubmittingCode ?? this.isSubmittingCode,
    );
  }
}

class PairingNotifier extends StateNotifier<PairingState> {
  PairingNotifier(this._ref) : super(const PairingState()) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<Pair?>? _sub;

  Future<void> _init() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final repo = _ref.read(pairRepositoryProvider);
      final invite = await repo.ensureMyInvite(userId);
      state = state.copyWith(isLoading: false, myInvite: invite);
      if (!invite.isLinked) {
        _sub = repo.watchMyInvite(userId).listen((pair) {
          if (pair != null) state = state.copyWith(myInvite: pair);
        });
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load your invite code.',
      );
    }
  }

  Future<bool> submitCode(String code) async {
    if (code.trim().isEmpty) return false;
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return false;

    state = state.copyWith(isSubmittingCode: true, clearError: true);
    try {
      final pair = await _ref
          .read(pairRepositoryProvider)
          .acceptInvite(code: code, userId: userId);
      state = state.copyWith(isSubmittingCode: false, myInvite: pair);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmittingCode: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final pairingNotifierProvider =
    StateNotifierProvider.autoDispose<PairingNotifier, PairingState>(
        (ref) => PairingNotifier(ref));
