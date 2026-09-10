## Description

Briefly describe the change and the problem it solves.

---

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Security hardening / vulnerability remediation
- [ ] Refactoring / clean architecture improvement
- [ ] Documentation update
- [ ] CI / build toolchain update

---

## Security Impact Assessment

Please categorize the security sensitivity of this change:

- [ ] **None:** Pure UI, layout, copy, or non-sensitive documentation.
- [ ] **Security-Sensitive:** Touches cryptography, secure storage, PIN handling, biometrics, mnemonic lifecycle, network requests, BDK descriptors, or transaction signing.
- [ ] **Requires Additional Architecture Review:** Structural modifications to network isolation guards, wallet erasure procedures, or external dependency toolchains.

*If Security-Sensitive, describe how you verified that secret key material, descriptors, or PIN verifiers remain protected:*

---

## Design System Compliance

Root Wallet enforces an absolute **SOLID COLORS ONLY** policy:

- [ ] I verified that this PR introduces **NO gradients**, **NO blur / glassmorphism**, and **NO glow effects**.
- [ ] All UI modifications use official tokens from `RootBrandColors`.
- [ ] Tested and verified in **both Light Mode and Dark Mode**.
- [ ] Tested on compact mobile screen sizes to ensure no layout overflows.

---

## Contributor Checklist

- [ ] My code follows the clean architecture and Riverpod patterns documented in `docs/architecture.md`.
- [ ] I have executed `flutter analyze` locally and verified that **zero issues** are found.
- [ ] I have executed `flutter test test/security/` and verified all security tests pass.
- [ ] I have executed `flutter test --exclude-tags golden` and verified all tests pass.
- [ ] I have confirmed that **NO recovery phrases, private keys, descriptors, or secrets** are included in code, logs, or commits.
- [ ] Documentation has been updated to reflect any behavioral changes.
- [ ] *(If UI changed)* I have attached before-and-after screenshots or screen recordings below.

---

## Screenshots / Evidence (If applicable)

| Light Mode | Dark Mode |
|---|---|
| *(attach image)* | *(attach image)* |
