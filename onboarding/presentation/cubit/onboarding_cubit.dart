import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idara_esign/features/onboarding/domain/repositories/onboarding.dart';

class OnboardingCubit extends Cubit<bool?> {
  OnboardingCubit(this._repo) : super(null);

  final IOnboardingRepo _repo;

  Future<void> load() async {
    final seen = await _repo.isSeen();
    emit(seen);
  }

  Future<void> complete() async {
    await _repo.complete();
    emit(true);
  }

  Future<void> reset() async {
    await _repo.reset();
    emit(false);
  }
}
