# Root Wallet: Open-Source License Analysis & Decision Document

**Status:** APPROVED  
**License Adopted:** MIT OR Apache-2.0  
**Approval Date:** 2026-09-10  
**Target Milestone:** Open Source + Public Launch Foundation  
**Recommendation:** Dual Licensing (MIT OR Apache-2.0)  

> [!NOTE]
> This document is a technical project licensing comparison and is not legal advice.

---

## 1. Overview

Root Wallet is an open-source, self-custodial Bitcoin wallet application written in Flutter/Dart and powered by the Rust-based Bitcoin Dev Kit (`bdk_dart` / BDK). As part of the public launch foundation, the project owner approved adopting a dual-licensing structure (`MIT OR Apache-2.0`).

This document evaluates three prominent licensing structures:
1. **MIT License**
2. **Apache License, Version 2.0 (Apache-2.0)**
3. **Dual Licensing: MIT OR Apache-2.0**

---

## 2. Dependency & Ecosystem Compatibility Matrix

Root Wallet sits at the intersection of the Flutter application framework, the Rust/BDK Bitcoin ecosystem, and mobile operating system ecosystems.

| Ecosystem Component | Primary License | Compatibility with MIT | Compatibility with Apache-2.0 | Compatibility with Dual MIT OR Apache-2.0 |
|---|---|---|---|---|
| **Flutter Framework & Dart SDK** | BSD 3-Clause | Compatible | Compatible | Fully Compatible |
| **Bitcoin Dev Kit (`bdk` core)** | MIT OR Apache-2.0 | Compatible | Compatible | **Native 1:1 Alignment** |
| **`bdk_dart` FFI bindings** | MIT OR Apache-2.0 | Compatible | Compatible | **Native 1:1 Alignment** |
| **Bitcoin Core** | MIT | Compatible | Compatible | Fully Compatible |
| **Rust Ecosystem / Toolchain** | Common MIT OR Apache-2.0 | Compatible | Compatible | Strong Convention |
| **Mobile App Stores (Apple App Store / Google Play)** | N/A (Distribution Terms) | No copyleft friction | Explicit patent grant | Maximum legal flexibility |

*Note: Upstream licensing for BDK and `bdk_dart` should be verified directly against their official repository license files. Many Rust ecosystem projects, including major components of the Rust toolchain, commonly use MIT OR Apache-2.0, but individual dependency licenses must be reviewed separately.*

---

## 3. Detailed License Comparison

### Option A: MIT License

The MIT License is the most widely adopted permissive open-source license in the Bitcoin development community (used by Bitcoin Core, Electrum, and Secp256k1).

- **Advantages:**
  - **Extreme Simplicity:** Under 20 lines of plain legal text; universally recognized and understood without legal review.
  - **Frictionless Adoption:** Allows anyone to view, modify, distribute, embed, or integrate Root Wallet code into any private, commercial, or open-source tool.
  - **Tradition in Bitcoin:** Aligns with Satoshi Nakamoto's original licensing choice for Bitcoin.
- **Disadvantages:**
  - **Silent on Patent Rights:** MIT provides no express patent license or patent defense termination clause. If a contributor later claims a patent on their contributed code, the community lacks explicit contractual patent protection.
  - **Silent on Trademarks:** MIT does not explicitly forbid using the project's trademarks or branding in forks (though trademark law generally applies independently).

---

### Option B: Apache License, Version 2.0 (Apache-2.0)

Apache-2.0 is a modern, enterprise-grade permissive license designed to protect open-source projects and their users against patent litigation.

- **Advantages:**
  - **Express Patent License (Section 3):** Apache-2.0 includes an express patent license under its terms: each contributor grants users and downstream developers a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable patent license for any patents necessarily infringed by their contributions.
  - **Patent Termination Provisions:** Apache-2.0 contains patent termination provisions. If any entity initiates patent litigation against Root Wallet users or contributors alleging that Root Wallet or a contribution constitutes patent infringement, any patent licenses granted to that entity under Apache-2.0 terminate as of the date such litigation is filed.
  - **Explicit Trademark Reservation (Section 6):** Explicitly states that the license does not grant rights to use the trade names, trademarks, service marks, or product names of the project.
- **Disadvantages:**
  - **GPLv2 Incompatibility:** Apache-2.0 code cannot be directly incorporated into strictly GPLv2-only codebases (though it is compatible with GPLv3).
  - **Length & Perceived Complexity:** Slightly longer and more formal than MIT.

---

### Option C: Dual Licensing (MIT OR Apache-2.0) — *Adopted*

Under dual licensing, Root Wallet code is distributed under the user's choice of **EITHER** the MIT License **OR** the Apache-2.0 License (`SPDX-License-Identifier: MIT OR Apache-2.0`).

- **Advantages:**
  - **Rust and BDK Native Convention:** Both Rust itself and BDK (`bitcoindevkit/bdk`, `bitcoindevkit/bdk-dart`) use the standard `MIT OR Apache-2.0` dual license. Adopting this structure provides absolute parity with our core underlying engine.
  - **Maximum Flexibility for Downstream Users:** Downstream developers can choose the MIT terms if they require maximum simplicity and GPLv2 compatibility, or choose the Apache-2.0 terms if their legal department requires express patent grants and patent retaliation provisions.
  - **Independent Alternatives (MIT OR Apache-2.0):** Apache-2.0 includes an express patent license under its terms and contains patent termination provisions. The user may choose either MIT OR Apache-2.0. Note that the two licenses are independent alternatives, not cumulative grants: choosing the MIT option does NOT automatically grant the Apache-2.0 patent terms.
  - **Trademark Reservation:** Section 6 of Apache-2.0 explicitly preserves trademark and brand ownership without requiring a separate trademark policy.
- **Disadvantages:**
  - Requires maintaining both license files in the repository (`LICENSE-MIT` and `LICENSE-APACHE`) and referencing the choice in documentation.

---

## 4. Comparison Summary Table

| Criterion | MIT | Apache-2.0 | Dual (MIT OR Apache-2.0) |
|---|---|---|---|
| **Ecosystem Familiarity (Bitcoin)** | Very High | Moderate | High |
| **BDK Upstream Parity** | High | High | **Exact Match** |
| **Patent Defense Clause** | None | Strong | Strong (when Apache option is chosen) |
| **Trademark Protection** | Default Common Law | Express Clause | Express (via Apache option / brand notice) |
| **Commercial Reuse Friction** | Minimal | Minimal | Minimal |
| **GPL Compatibility** | GPLv2 + GPLv3 | GPLv3 only | GPLv2 + GPLv3 |

---

## 5. Recommendation & Owner Decision

**Adopted Dual Licensing: MIT OR Apache-2.0.**

**Rationale:**
1. **BDK Ecosystem Alignment:** Root Wallet is a dedicated BDK application. Mirroring BDK's licensing model creates seamless contributor flow between the application layer and upstream libraries.
2. **Corporate & Security Researcher Confidence:** Serious enterprise contributors and security researchers appreciate the express patent grants of Apache-2.0, while individual Bitcoin hackers appreciate the zero-barrier simplicity of MIT.
3. **Tradition & Future-Proofing:** Dual licensing is the recognized gold standard across the modern Rust/Bitcoin development landscape.

---

## 6. Adoption Record

> [!NOTE]
> **FORMAL ADOPTION COMPLETED (2026-09-10)**  
> On 2026-09-10, the project owner approved the dual-license model (`SPDX-License-Identifier: MIT OR Apache-2.0`).  
> The project is now licensed under either the MIT License or the Apache License, Version 2.0, at the user's option.  
> Official license texts are maintained at:  
> - [`LICENSE-MIT`](../LICENSE-MIT)  
> - [`LICENSE-APACHE`](../LICENSE-APACHE)  
> - Root dual-licensing notice: [`LICENSE`](../LICENSE)  

