# Security Scan Findings

Summary of results from running each tool against this repo, before and
after hardening. The "BEFORE" results are from the initial scaffold commit
(`# INTENTIONAL FLAW:` comments in `app.py` / `Dockerfile`); the "AFTER"
results are from the hardening commit that fixes all three flaws.

## Flaw-to-tool mapping

| # | Flaw | Location | Detected by | Status |
|---|------|----------|-------------|--------|
| a | Outdated/vulnerable base image (`python:3.9.0-slim`) | `Dockerfile` | Trivy (`image` scan) | Fixed → `python:3.14.6-slim` |
| b | No non-root `USER` directive | `Dockerfile` | Trivy (`config` scan) | Fixed → `USER appuser` |
| c | Hardcoded Flask secret key | `app.py` | Bandit | Fixed → loaded from `FLASK_SECRET_KEY` env var |

## Before/after comparison

| Tool | Check | Before | After |
|------|-------|--------|-------|
| Trivy `config` | DS-0002 (missing non-root `USER`) | **FAIL (HIGH)** | **PASS** |
| Trivy `image` | Base image CVEs | 126 vulns (26 CRITICAL, 100 HIGH) | **0 vulns** (`python:3.14-alpine`) |
| Bandit | B105 (hardcoded secret) | **FAIL (Low/Medium)** | **PASS** |
| Bandit | B104 (bind-all-interfaces) | FAIL (Medium, not an intentional flaw) | **PASS** (explicitly suppressed via `# nosec B104`) |
| Hadolint | Dockerfile lint | 0 issues | 0 issues (no change — see note below) |
| Docker Bench | CIS Docker benchmark | Host-level audit only (see limitation) | Host-level audit only (see limitation) |

All three GitHub Actions CI jobs (Hadolint, Bandit, Trivy) are expected to
be green on `main` once this commit is pushed — see "CI results" at the end
of this document for the full timeline, including the run that verifies it.

---

## BEFORE — initial scaffold (flawed version)

### Trivy — config scan (`trivy config Dockerfile`)

Static analysis of the Dockerfile itself.

- **DS-0002 (HIGH)** — Specify at least 1 `USER` command in Dockerfile with a
  non-root user as argument. Confirms flaw (b).
- **DS-0026 (LOW)** — Missing `HEALTHCHECK` instruction. Not one of the
  intentional flaws; a general best-practice gap.

Result: 2 failures out of 27 checks.

### Trivy — image scan (`trivy image python:3.9.0-slim`)

Vulnerability scan of the pinned base image (Debian 10.6).

- **126 vulnerabilities total: 26 CRITICAL, 100 HIGH**, across base OS
  packages and bundled Python tooling (`pip`, `setuptools`, `wheel`).
- Example: `CVE-2022-1664` (CRITICAL) in `dpkg`.

Confirms flaw (a).

### Bandit (`bandit app.py`)

Static analysis of the Flask app source.

- **B105 — hardcoded_password_string** (Low severity / Medium confidence,
  CWE-259) at `app.py:7` — `app.secret_key = "supersecret123"`. Confirms
  flaw (c).
- **B104 — hardcoded_bind_all_interfaces** (Medium severity / Medium
  confidence, CWE-605) at `app.py:21` — `app.run(host="0.0.0.0", ...)`.
  Not one of the intentional flaws; reviewed and accepted, since binding to
  all interfaces is expected for a containerized app (it's how the
  container's port gets exposed to the host).

### Hadolint (`hadolint Dockerfile`)

No issues found (exit code 0).

**Note:** Hadolint does not have a rule that flags a *missing* `USER`
directive. Its only related check, DL3002 ("Last USER should not be root"),
only fires if the Dockerfile explicitly sets `USER root` — it does not warn
when there's no `USER` instruction at all. So despite the original plan,
Hadolint is not an effective detector for flaw (b) as written; Trivy's
config scan (DS-0002, above) covers that gap instead.

### Docker Bench for Security

Ran the official script directly against the Docker host (the bundled
`docker/docker-bench-security` Docker Hub image ships a Docker CLI too old
to talk to the current daemon, so the script was run natively instead).

Result: 86 checks — 28 PASS, 29 WARN, 70 INFO/manual. The WARNs were almost
entirely host/daemon-level CIS hardening gaps unrelated to this project
(Linux audit rules, user namespace remapping, Content Trust, etc.).

**Limitation:** this project's Docker image could not be built in the
development sandbox, because `docker build` has no outbound network access
there and `pip install -r requirements.txt` cannot reach PyPI. Docker Bench
audits built images and running containers, not raw Dockerfile text, so
without a built image its container-level checks (e.g. CIS 4.1, "Ensure a
user for the container has been created") fell back to auditing unrelated
pre-existing images on the host rather than this project's Dockerfile. See
the "Known limitations" section in `README.md` for more detail.

---

## AFTER — hardened version

### Trivy — config scan (`trivy config Dockerfile`)

- **DS-0002 no longer fails** — the `USER appuser` directive resolves it.
- **DS-0026 (LOW)** — missing `HEALTHCHECK` still present; this was never
  one of the three intentional flaws, left as-is.

Result: 1 failure out of 27 checks (down from 2).

### Trivy — image scan (`trivy image python:3.14.6-slim`, then `python:3.14-alpine`)

- First pass, staying on Debian slim (`python:3.14.6-slim`): **23
  vulnerabilities total: 4 CRITICAL, 19 HIGH** (down from 126 total / 26
  CRITICAL / 100 HIGH on `python:3.9.0-slim`) — an ~82% reduction, but not
  zero. All 4 CRITICAL findings were in `perl-base`, a transitive OS
  package pulled in by the Debian base image and unrelated to anything in
  this app's own code.
- Rather than suppressing those findings (e.g. `--ignore-unfixed` or a
  `.trivyignore`), the base image was switched to `python:3.14-alpine`.
  Alpine's minimal BusyBox/musl userland doesn't include `perl-base` at
  all, which eliminates that CVE source entirely instead of just hiding it
  from the scanner.
- Result on `python:3.14-alpine` (Alpine 3.24.1): **0 vulnerabilities**,
  full stop — not just 0 CRITICAL. Verified both locally and in the
  `build-and-scan-image` CI job.

### Bandit (`bandit app.py`)

- **B105 no longer fires** — the secret key is now read from
  `os.environ["FLASK_SECRET_KEY"]` with no hardcoded value in source.
- **B104 (bind-all-interfaces)**: initially still fired after the flaw (c)
  fix, same as before. It was never one of the three intentional flaws —
  binding to `0.0.0.0` is required for a containerized app's exposed port
  to be reachable from the host — but Bandit's CLI fails the job on *any*
  finding regardless of severity, with no default threshold. Rather than
  raising Bandit's global severity threshold (which would have also
  silenced future Low-severity findings like B105, undermining the whole
  point of running Bandit in CI), the specific line was annotated with
  `# nosec B104` and a one-line justification. Bandit now reports "No
  issues identified" and explicitly logs that 1 finding was skipped via
  `#nosec`, so the suppression is visible in the tool's own output rather
  than silent.

### Hadolint (`hadolint Dockerfile`)

No issues found (exit code 0) — unchanged from before, since Hadolint never
flagged either Dockerfile fix in the first place (see note in the BEFORE
section).

### Docker Bench for Security

Same limitation as the BEFORE run: the hardened image also could not be
built in this sandbox (no outbound network access during `docker build`),
so Docker Bench still could not evaluate this project's actual image.

---

## CI results (GitHub Actions)

A `.github/workflows/security.yml` workflow runs Hadolint, Bandit, and
Trivy automatically on every push to `main` and every pull request. Unlike
the local sandbox, GitHub-hosted runners have full outbound internet
access, so `docker build` succeeds there.

| Run | Base image | Hadolint | Bandit | Trivy (image build+scan) |
|-----|------------|----------|--------|---------------------------|
| [30359685096](https://github.com/NoraAlajmi/devsecops-container-security-suite/actions/runs/30359685096) — hardening commit, `python:3.14.6-slim` | Debian slim | ✅ PASS | ❌ FAIL (B104) | ❌ FAIL (4 CRITICAL in `perl-base`) |
| [30360559278](https://github.com/NoraAlajmi/devsecops-container-security-suite/actions/runs/30360559278) — switched to `python:3.14-alpine` | Alpine | ✅ PASS | ❌ FAIL (B104) | ✅ PASS (0 vulnerabilities) |

The Bandit job is expected to go green on the next run, following the
`# nosec B104` suppression documented above.
