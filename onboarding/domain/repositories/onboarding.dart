abstract class IOnboardingRepo {
  Future<bool> isSeen();
  Future<void> complete();
  Future<void> reset();
}
