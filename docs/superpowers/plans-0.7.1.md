# Implementation plan — macOS 0.7.1

Spec: superpowers/specs/2026-10-30-macos-stabilization-design.md.

1. Add silence/evidence regressions, run RED, implement tracker silence handling and
   whole-track confidence, verify all core tests and supplied-file comparison.
2. Add a local corpus executable and manifest/reference evaluator with tests, explicit
   missing labels, deterministic results, per-file errors, strict optional accuracy gate.
3. Profile hour-long decoding/analysis and cancellation; fix demonstrated resource issues
   with regression coverage; test large-folder enumeration and real MP3 export preservation.
4. Improve report evidence wording and keyboard timeline navigation/accessibility; verify
   hosted tests and native Release UI against supplied MP3s.
5. Fresh independent whole-branch review, fix material findings with regressions; full suites.
6. Update roadmap/validation/full release notes, version/build, build/sign/notarize/check,
   integrate with remote main, push main/tag, publish verified GitHub assets.

Shared interfaces: tracker changes feed existing AnalysisResult confidence and timelines;
corpus runner consumes public AnalysisEngine and AnalysisResult without changing schema;
report consumes confidence with the same numeric [0,1] contract. No new app storage schema.
