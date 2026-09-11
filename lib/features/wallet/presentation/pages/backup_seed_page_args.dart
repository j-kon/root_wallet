class BackupSeedPageArgs {
  const BackupSeedPageArgs({
    this.walletId,
    this.requireReauth = true,
    this.isOnboardingFlow = false,
    this.recoveryPhrase,
  });

  final String? walletId;
  final bool requireReauth;
  final bool isOnboardingFlow;
  final String? recoveryPhrase;
}
