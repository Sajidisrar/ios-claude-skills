---
name: ios-dependency-assessment
description: Assess a third-party Swift package or SDK before adding it to this iOS project, as a supplier decision rather than a convenience. Use when asked to add a library, evaluate a package, replace hand-written code with an SDK, or when someone proposes Alamofire, Firebase, a networking, analytics, crash-reporting or UI library. Also use when reviewing an existing dependency at upgrade time.
---

# Assess a dependency

This project ships with **no third-party dependencies** (`docs/DECISIONS.md`
D14). That is a deliberate position, not an accident, and the burden of proof sits
with the addition. Under ISO 27001 a dependency is a supplier: it needs assessing,
recording, and reviewing, not just adding.

## 1. Establish what it replaces

Write down the specific problem, and how much of our own code it removes. Then
check honestly:

- Does the platform already do this? `URLSession`, `Codable`, `Security`,
  `Network`, `CryptoKit`, `os.Logger`, `Charts` (iOS 16) and SwiftUI cover a great
  deal of what libraries are habitually added for.
- Is this template already solving it? A networking library replaces
  `Core/Networking` — about five hundred lines that are already tested and that we
  fully understand. That is rarely a good trade.
- Is the need real now, or anticipated? Do not add for a requirement that has not
  arrived.

If it replaces fewer than a few hundred lines we would otherwise write, stop
here and write the code.

## 2. Assess the supplier

| Question | Why it matters |
| --- | --- |
| Licence — MIT, Apache 2.0, BSD? | GPL and AGPL are unacceptable in a shipped client app. Record the licence. |
| Who maintains it, and how actively? | Last release date, open issue count, response times, bus factor. A single-maintainer package is a risk to state, not necessarily a blocker. |
| Transitive dependencies? | Each one is another supplier. A package pulling in six others is really seven decisions. |
| Binary or source? | A binary XCFramework cannot be reviewed or audited. Strong preference for source. |
| Does it phone home? | Analytics, crash reporting or "telemetry" in a dependency is a data-processing decision, not a technical one — and may need a DPIA. |
| What does it access? | Keychain, contacts, location, clipboard, pasteboard, device identifiers. Read the code, not the README. |
| Size and launch cost | Binary size and any launch-time initialisation. |
| iOS 16 support | Confirm the minimum target, and that it will not force the floor upwards. |
| Upgrade history | Has it shipped breaking changes casually? How were they communicated? |

## 3. Assess the integration cost

- Does it fit behind one of our protocols (`HTTPSession`, `CacheStore`,
  `TokenStorage`), so it can be replaced later without touching features? If it
  cannot be wrapped, it will spread through the codebase and become permanent.
- Does it impose its own concurrency model? A library built on completion handlers
  or Combine fights the project's Swift Concurrency convention.
- Does it need a change to the architecture, or an exception to a rule in
  `CLAUDE.md`? That is a strong signal to decline.

## 4. Recommend

Present a short recommendation with the trade-off explicit, not a conclusion
dressed up as a fact. Include: what it buys, what it costs, the licence, the
maintenance risk, and how we would remove it if it went bad. If the answer is
"write it ourselves", say that plainly with the estimate.

If it is adopted:

- Pin an exact version. No `upToNextMajor` on anything security-relevant.
- Wrap it behind one of our own protocols at a single seam.
- Record it: what it is, why, licence, version, who owns the upgrade decision,
  and what it has access to. That record is what an ISO 27001 audit asks for.
- Add it to the review cycle — an unupgraded dependency becomes a vulnerability
  on someone else's schedule.

## Verification

- [ ] Platform alternative considered and named.
- [ ] Licence identified and acceptable for a shipped app.
- [ ] Transitive dependencies listed.
- [ ] Data access and any network calls it makes established from the source.
- [ ] It sits behind one of our protocols, at one seam.
- [ ] Version pinned exactly.
- [ ] Recommendation states the trade-off both ways, and the removal path.
- [ ] Flag that adding a dependency needs sign-off, and that anything processing
      client or personal data may need a DPIA — point to your organisation's
      data-protection documentation rather than guessing the process.
