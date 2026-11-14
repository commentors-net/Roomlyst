# Roomlyst Project Agent Instructions

## 1. Purpose and product scope
- Roomlyst is a mobile-first interior design and renovation application. Users can capture or upload room photos or video and receive AI-assisted decoration, layout, and renovation ideas.
- Support devices without LiDAR. Detect LiDAR availability where technically possible and offer enhanced functionality when supported; never make LiDAR a prerequisite for the core experience.
- Keep the browser/web and backend architecture aligned with the actual repository and documented project plan; do not assume a particular stack or invent APIs.

## 2. Target users (priority order)
1. Homeowners seeking design inspiration.
2. People actively renovating.
3. Interior designers.
4. Furniture sellers.
5. Contractors.
6. Property agents.
7. Cross-segment combinations.

## 3. Source of truth and milestones
- Read the repository's current phase/milestone plan, requirements, architectural decisions, and test documentation before planning changes. Preserve the existing six-phase plan; do not silently reorder or redefine phases.
- Determine the current checkpoint from verified deliverables, tests, documentation, and Git history, not from assumptions or an agent's prior chat history.
- Work only on the user's requested task or the next explicitly approved milestone. Stop and report when its acceptance criteria are met; do not automatically start later milestones.
- If project documents conflict, report the conflict and avoid making irreversible assumptions.

## 4. Engineering expectations
- Inspect relevant code and existing conventions before editing. Make the smallest coherent change that satisfies the task.
- Maintain separation between UI, capture/upload flow, AI processing, application state, persistence, and platform-specific capabilities, according to the repository's established architecture.
- Handle camera/storage permissions explicitly, provide graceful error and offline/limited-connectivity states, and avoid unnecessary data collection.
- Keep photo/video uploads, generated assets, and any user data subject to appropriate authorization, validation, retention, and privacy controls.
- Treat AI-generated design output as suggestions; never imply structural, electrical, or other safety-critical renovation advice is professionally certified.
- Do not add new paid services, external integrations, deployment dependencies, or architectural rewrites without explaining the tradeoffs and receiving approval.

## 5. Testing and release safety
- Run relevant lint, typecheck, build, and automated tests after changes; report exactly which checks ran, their results, and checks that could not be run.
- Cover supported device paths, including devices with and without LiDAR where applicable, using mocks or device testing as appropriate. Do not claim physical-device testing unless it occurred.
- Keep test and production configurations separate. Do not deploy, publish, spend money, delete data, or change production settings without explicit authorization.
- Preserve existing functionality and investigate regressions before marking a milestone complete.

## 6. Agy CLI / Codex CLI continuity
- These instructions apply equally to Agy and Codex. The CLI currently in use is the sole writer for its assigned task; never assume the other agent's chat history is available.
- At the start of a task: read this file, inspect `git status`, relevant current milestone documents, recent commits, and affected source files. Identify the last verified checkpoint.
- If there are uncommitted or unexplained changes, preserve them. Do not reset, clean, overwrite, or commit someone else's work without authorization.
- Before implementing: state the narrowly scoped task, relevant acceptance criteria, and any blocking uncertainty. Do not spend tokens re-explaining stable background already in repository documents.
- At task completion: run relevant checks, write the mandatory per-prompt report described in Section 8, and update the existing progress/milestone documentation with a short entry linking to that report. Do not create a competing milestone tracker.
- Do not create Git commits, switch branches, merge, or deploy unless the user's instructions or established project workflow authorize it.
- When switching from Agy to Codex or back, continue from the repository's verified state and handoff, not from an assumed conversational memory.
- If instructed to review only, do not modify files.

## 7. Communication
- Prefer concise, evidence-based progress reports. Distinguish implemented, tested, partially complete, blocked, and unverified work.
- Ask only for a decision that truly blocks safe progress; otherwise follow existing conventions and document reasonable choices.
- Respect the user's instruction to work through the existing phase plan before broad user testing; this does not prohibit automated checks and developer verification within each phase.


## 8. Mandatory report after every prompt
- Every executed development, audit, stabilization, testing, documentation, or research prompt must produce exactly one standalone Markdown summary report under `docs/ai/task-reports/`. This applies equally to Agy CLI and Codex CLI.
- Name reports using the matching prompt identifier, for example `01-report.md` for `01.md`, `02-report.md` for `02.md`. If a prompt ID follows a different existing naming convention, preserve that ID consistently. Never overwrite an earlier report for a different run.
- Create the report directory if needed; this is a report archive, not an alternative project milestone tracker. Keep the existing `docs/progress.md` / milestone documentation as the authoritative chronological history and link to the report from a concise progress entry.
- The report must state: prompt ID and objective; date; starting Git branch/status and checkpoint; files inspected; actions taken; files added/modified; findings by severity with file/line evidence; exact test/build/lint commands and results (including tests not run); whether physical-device or live integration tests actually occurred; blockers and risks; remaining tasks; suggested next prompt; ending Git status; and whether a commit/deployment occurred.
- Distinguish `verified`, `implemented but not tested`, `documented only`, `blocked`, and `not inspected`. Never convert a historical reported test result into a newly verified result.
- If the prompt is strictly read-only, the report file and a small progress-log link are the only permitted writes, unless the user explicitly forbids even documentation writes; in that case return the report in the CLI response without writing it.
- End the CLI response with a brief summary and the exact path of the saved report. Do not start the suggested next prompt automatically.


## 9. Secret management and credential safety
- **Fail-closed secret architecture:** Never hardcode backend secrets, JWT signing keys, private keys, database passwords, or provider API tokens in application code, Docker Compose files, documentation, or reports.
- **No working default signing secrets:** Required secrets (such as `SECRET_KEY`) must fail closed with an explicit configuration error when missing; never provide a working fallback secret in source code.
- **Safe templates only:** Commit only safe `.env.example` templates containing descriptive, non-functional placeholders. Never commit `.env` or any `.env.*` file variants.
- **Repository exclusions:** Maintain `.gitignore` to strictly exclude all environment files (`.env*` except `!.env.example`), private keys (`*.key`, `*.pem`), Android release keystores (`*.keystore`, `*.jks`, `key.properties`), credentials files, and certificates.
- **Client configuration vs. Backend secrets:** Client identifiers (such as Firebase API keys and Google OAuth Client IDs in `google-services.json`) are packaged into mobile/web client binaries by design. They must be protected using Google Cloud console restrictions (e.g. Android package name `com.roomlyst.app` and SHA-1 certificate fingerprint; API restriction to Firebase Auth / Identity Toolkit) and never confused with private backend credentials. Never send private provider API keys (OpenAI, Anthropic, Replicate, Gemini) to client applications, browser storage, screenshots, or client-facing logs.
- **Redaction in all outputs:** Never print actual secret values in console logs, task reports, CI output, generated files, or chat. Report only credential category, location, risk, and remediation status.
- **Automated scanning:** Maintain automated secret scanning (`.gitleaks.toml`, `.pre-commit-config.yaml`, `.github/workflows/secret-scan.yml`, and `scripts/scan_secrets.py`). All PRs and commits must pass secret scanning. Justified, narrowly scoped false positives (such as client identifiers and synthetic test placeholders) must be documented in `.gitleaks.toml`.
- **Controlled credential rotation:** Never rotate active production/staging credentials, invalidate user sessions, rewrite Git history, or alter cloud permissions without explicit user approval. Every rotation plan must include a verified backup, session impact analysis, rollback procedure, and post-rotation verification.
