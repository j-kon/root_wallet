# Root Wallet: App Store & Google Play Store Readiness Checklist

**Status:** PRE-RELEASE EVALUATION  
**Constraint:** Do NOT configure production signing or identifiers in this milestone.

---

## Overview

This checklist tracks the technical, operational, legal, and creative requirements needed to publish Root Wallet to the **Apple App Store (iOS)** and **Google Play Store (Android)** for beta testing (TestFlight / Internal Testing) and eventual public release.

Status Indicators:
- **`READY`:** Completed and verified in the repository.
- **`TODO`:** Defined and actionable, pending execution in a subsequent milestone.
- **`BLOCKED`:** Dependent on another milestone (e.g. security audit or domain deployment).
- **`NEEDS OWNER DECISION`:** Requires explicit business, legal, or administrative decisions by the repository owner.

---

## 1. Universal / Cross-Platform Requirements

| Requirement | Current Status | Category | Details & Actions Needed |
|---|---|---|---|
| **Privacy Policy Web URL** | Draft written (`docs/privacy_policy_draft.md`) | `BLOCKED` | Must be published as a live public web URL (e.g. `https://rootwallet.app/privacy`) for both App Store Connect and Google Play Console. |
| **Support Contact URL / Email** | Pending owner configuration | `NEEDS OWNER DECISION` | Official support email or public support desk URL required for store listings. |
| **Marketing Website URL** | Spec complete (`docs/website_content_spec.md`) | `TODO` | Official landing page (`https://rootwallet.app`) must be deployed before public release. |
| **Production App Icons** | Branded assets generated | `READY` | Native splash and icons configured via `flutter_native_splash` with Root Wallet brand mark. |
| **Store Marketing Descriptions** | Product positioning defined | `TODO` | Draft 4000-character long description, 80-character short description, and feature bullet points. |
| **Store Screenshot Assets** | Golden UI baselines established | `TODO` | Render 6.7" / 6.5" / 5.5" iOS displays and 7" / 10" Android tablet screenshots without status bar drift. |
| **Version & Build Numbering Strategy** | `1.0.0+1` declared in `pubspec.yaml` | `READY` | Use SemVer (`major.minor.patch+buildNumber`) incremented via CI/CD on release tags. |
| **Mainnet Safety Block** | Enforced via `AppConstants.isMainnetAllowed = false` | `READY` | Protects users from real fund exposure during initial TestFlight/Play beta periods. |

---

## 2. iOS (Apple App Store & TestFlight) Checklist

| Requirement | Current State | Category | Details & Actions Needed |
|---|---|---|---|
| **Production Bundle Identifier** | Currently `com.example.rootWallet` | `NEEDS OWNER DECISION` | Must update to official production identifier (e.g. `com.rootwallet.app`) in `project.pbxproj`. |
| **Apple Developer Account Enrollment** | Pending verification | `NEEDS OWNER DECISION` | Active Apple Developer Program organization or individual account required. |
| **App Store Connect App Record** | Not yet created | `TODO` | Create application record, upload SKU, and assign primary category (Finance/Utilities). |
| **Code Signing & Provisioning Profiles** | Uses automatic debug signing | `NEEDS OWNER DECISION` | Provision Apple Distribution Certificate and TestFlight App Store Provisioning Profile. |
| **App Store Privacy Nutrition Labels** | Mapped from Privacy Policy | `READY` | Declare: "Data Not Collected" for analytics/tracking. Declare local storage of diagnostics/user content if applicable. |
| **Export Compliance Documentation (Encryption)** | Uses cryptography & BDK | `TODO` | Root Wallet uses standard encryption (AES, SHA-256, Secp256k1). Submit Year-End Self-Classification Report or declare standard exemptions under EAR Category 5 Part 2. |
| **TestFlight External Beta Review** | Not yet submitted | `BLOCKED` | Requires production bundle ID and clean beta archive upload. |
| **Guideline 3.1.5 (Cryptocurrencies)** | Bitcoin-only non-custodial wallet | `READY` | Conforms to Apple App Store Review Guidelines 3.1.5: Non-custodial storage and direct transmission of approved cryptocurrencies (Bitcoin). |

---

## 3. Android (Google Play Store) Checklist

| Requirement | Current State | Category | Details & Actions Needed |
|---|---|---|---|
| **Production Application ID & Namespace** | Currently `com.example.root_wallet` | `NEEDS OWNER DECISION` | Update `applicationId` and `namespace` to `com.rootwallet.app` in `android/app/build.gradle.kts`. |
| **Google Play Console Account** | Pending verification | `NEEDS OWNER DECISION` | Registered Google Play Developer account required. |
| **Release Keystore & Play App Signing** | Release uses debug signing config | `NEEDS OWNER DECISION` | Generate dedicated release upload keystore (`upload-keystore.jks`) and store safely in offline hardware. Enroll in Google Play App Signing. |
| **Target SDK & API Level Compliance** | `compileSdk = 35`, `targetSdk = 34` | `READY` | Meets current Google Play target API level requirements. |
| **Google Play Data Safety Form** | Mapped from Privacy Policy | `READY` | Disclose zero data collection, zero third-party sharing, and on-device processing of camera data (QR codes). |
| **Financial Services / Crypto Policy** | Bitcoin-only non-custodial | `READY` | Conforms to Google Play Financial Services policy: non-custodial wallet with no custodial exchange operations. |
| **App Bundle Generation (.aab)** | Tested locally | `READY` | Verified standard `flutter build appbundle --release` packaging. |
| **Google Play Internal Testing Track** | Not yet published | `BLOCKED` | Requires updated `applicationId` and signed release AAB. |

---

## 4. Immediate Blockers to Public Store Release

The following 4 items represent hard blockers that must be resolved in dedicated future milestones:

1. **Owner Selection of Production Identifiers:** Formal selection of `com.rootwallet.app` (or chosen alternative) across iOS and Android configurations.
2. **Developer Program Accounts & Signing Credentials:** Enrollment in Apple Developer and Google Play Console, with secure CI secret provisioning.
3. **Public Deployment of Legal URLs:** Hosting `https://rootwallet.app/privacy` and official support channel.
4. **Third-Party Security Audit Sign-off:** Independent cryptographic review prior to removing the testnet safety lock.
