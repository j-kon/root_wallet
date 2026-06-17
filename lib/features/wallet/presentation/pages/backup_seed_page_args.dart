class BackupSeedPageArgs {
  const BackupSeedPageArgs({
    this.requireReauth = true,
    this.isOnboardingFlow = false,
    this.recoveryPhrase,
  });

  final bool requireReauth;
  final bool isOnboardingFlow;
  final String? recoveryPhrase;
}
