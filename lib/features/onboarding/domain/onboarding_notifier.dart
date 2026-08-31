import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/user_repository.dart';

class OnboardingState {
  const OnboardingState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  OnboardingState copyWith({bool? isLoading, String? errorMessage}) =>
      OnboardingState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._ref) : super(const OnboardingState());
  final Ref _ref;

  Future<bool> submit({required String name, required String petName}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = state.copyWith(errorMessage: 'Enter your name.');
      return false;
    }

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(errorMessage: 'You were signed out. Please log in again.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(userRepositoryProvider).createProfile(
            userId: userId,
            displayName: trimmedName,
            petName: petName.trim().isEmpty ? trimmedName : petName.trim(),
          );
      _ref.invalidate(userProfileProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('Onboarding profile creation failed: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final onboardingNotifierProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
        (ref) => OnboardingNotifier(ref));
