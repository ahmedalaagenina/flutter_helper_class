import 'package:idara_esign/features/onboarding/data/datasources/onboarding_local.dart';
import 'package:idara_esign/features/onboarding/domain/repositories/onboarding.dart';

class OnboardingRepo implements IOnboardingRepo {
  OnboardingRepo(this._local);

  final IOnboardingLocalDataSource _local;

  @override
  Future<bool> isSeen() => _local.isSeen();

  @override
  Future<void> complete() => _local.setSeen(true);

  @override
  Future<void> reset() => _local.reset();
}
