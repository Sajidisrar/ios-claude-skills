---
name: ios-coreml-apple-intelligence
description: Integrate on-device machine learning via Core ML or Apple's Foundation Models framework (Apple Intelligence) — model loading and compute-unit selection, availability gating by device/OS, and the privacy framing that comes with doing inference on-device versus server-side. Use when asked to add an ML feature, integrate a Core ML model, use the Foundation Models framework, add a Writing Tools/Apple Intelligence integration, or decide whether a feature needs on-device AI at all.
---

# Add on-device ML or Apple Intelligence

Two distinct frameworks live under this skill: **Core ML** (you supply/convert a trained model, you own its accuracy and size) and the **Foundation Models framework** (Apple's on-device large language model, exposed through a system API — you don't train or ship a model at all). Pick the right one before writing any code.

## 1. Which one actually fits

| Need | Framework |
|---|---|
| Classification, detection, or a custom trained model you've converted (`.mlmodel`/`.mlpackage`) | Core ML |
| General text generation, summarization, or tool-calling backed by Apple's on-device LLM, without shipping or hosting a model yourself | Foundation Models framework |
| Something that needs to run on hardware without the on-device model's availability (older devices, Apple Intelligence disabled, or the feature needs to be deterministic/auditable) | Core ML, or a server-side call — not Foundation Models |
| On-device Speech/Vision/NaturalLanguage tasks (transcription, text recognition, sentiment) that already have a dedicated system framework | The specific system framework (`Speech`, `Vision`, `NaturalLanguage`) — don't reach for Core ML or Foundation Models for something Apple already ships a purpose-built API for |

## 2. Core ML integration

- Load the compiled model once and reuse the `MLModel` instance — compiling/loading on every inference call is the single most common Core ML performance bug.
- Choose `computeUnits` deliberately: `.all` lets the OS pick CPU/GPU/Neural Engine per-operation (the right default for most models); `.cpuOnly` forces a slower but fully deterministic path, useful mainly for debugging a result discrepancy against a non-Neural-Engine reference; don't hardcode `.cpuAndGPU` or similar without a specific reason, since it removes the Neural Engine from consideration unconditionally.
- Model size and launch cost are an `ios-dependency-assessment`-style question even though it's not a third-party package: a multi-hundred-MB model bundled into the app affects install size and (if loaded eagerly) launch time. Lazily load it on first use of the feature that needs it, not during `AppEnvironment.bootstrap()`.
- Converting a model (PyTorch/TensorFlow → Core ML) happens via `coremltools` outside the app target — this skill covers integrating an already-converted `.mlpackage`, not the conversion/training pipeline itself.
- Run inference off the main actor; a model invocation that takes more than a few milliseconds on the calling thread reproduces the exact "expensive work on the main thread" symptom `ios-performance-tuning` already covers.

## 3. Foundation Models framework

- Check availability before offering the feature at all — the framework reports whether the on-device model is available on this device/OS/region/Apple-Intelligence-enabled-state combination; a feature built on it needs a real fallback (hide the entry point, or route to a server-side equivalent) for the "not available" case, not a crash or a silently broken button.
- Sessions carry conversational context; a new session per independent task, not one long-lived session accumulating unrelated context across features — context that doesn't belong together degrades the quality of generations for all of it.
- Guardrails are enforced by the system model itself (it can refuse or produce a flagged response) — handle that outcome explicitly in the UI rather than assuming every generation request succeeds with usable content.
- Structured generation (asking the model to produce a value conforming to a `Generable` type) is preferable to asking for free text and parsing it yourself wherever the output needs to be machine-consumed — parsing free-form model output is its own source of silent failures.

## 4. Privacy framing — the actual differentiator

Both frameworks run inference **on-device**: no request payload leaves the device for the inference itself. This matters for the privacy-manifest and App Store privacy answers this app gives (see `ios-privacy-compliance`) — on-device inference is not the same data-handling story as calling a server-side ML endpoint, and the privacy copy/consent flow should say which one a given feature actually does. Don't let marketing copy imply "on-device AI" for a feature that actually calls a backend model; don't let privacy disclosures imply "nothing leaves the device" for a feature that also logs inputs/outputs server-side for quality monitoring.

## 5. Testing

- Core ML: test the integration (does the app call the model correctly, handle a low-confidence result, handle a model-load failure) rather than the model's own accuracy — accuracy is a data-science concern validated outside the app, not something a unit test should assert a specific score for.
- Foundation Models: test against the availability-unavailable path explicitly (simulators and CI machines often can't run the on-device model at all) — a test suite that only exercises the happy path on a capable device leaves the fallback UI completely unverified.

## Verification

- [ ] The right framework was chosen for the actual need (§1), not defaulted to Core ML or Foundation Models out of familiarity.
- [ ] Availability (device/OS/Apple-Intelligence-enabled) is checked explicitly, with a real fallback UI for the unavailable case.
- [ ] A Core ML model is loaded once and reused, with a deliberately chosen `computeUnits`.
- [ ] Inference runs off the main actor.
- [ ] Privacy copy and App Store privacy answers accurately describe whether this specific feature's data ever leaves the device.
- [ ] The unavailable/fallback path has a test, not just the happy path.
