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
| Trivy `image` | Base image CVEs | 126 vulns (26 CRITICAL, 100 HIGH) | 23 vulns (4 CRITICAL, 19 HIGH) |
| Bandit | B105 (hardcoded secret) | **FAIL (Low/Medium)** | **PASS** |
| Hadolint | Dockerfile lint | 0 issues | 0 issues (no change — see note below) |
| Docker Bench | CIS Docker benchmark | Host-level audit only (see limitation) | Host-level audit only (see limitation) |

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

### Trivy — image scan (`trivy image python:3.14.6-slim`)

- **23 vulnerabilities total: 4 CRITICAL, 19 HIGH** (down from 126 total /
  26 CRITICAL / 100 HIGH on `python:3.9.0-slim`) — an ~82% reduction.
- Not zero: current Debian-based images still carry some open CVEs at any
  point in time (e.g. `perl-base`, `ncurses-base`, `util-linux` in this
  scan) since new CVEs are disclosed continuously. Flaw (a) was about using
  a *known-outdated, long-unpatched* pin, not about achieving zero CVEs —
  that goal is met by tracking current stable tags going forward.

### Bandit (`bandit app.py`)

- **B105 no longer fires** — the secret key is now read from
  `os.environ["FLASK_SECRET_KEY"]` with no hardcoded value in source.
- **B104 (bind-all-interfaces)** still present, same as before — still
  reviewed and accepted for the same reason (expected in a container).

### Hadolint (`hadolint Dockerfile`)

No issues found (exit code 0) — unchanged from before, since Hadolint never
flagged either Dockerfile fix in the first place (see note in the BEFORE
section).

### Docker Bench for Security

Same limitation as the BEFORE run: the hardened image also could not be
built in this sandbox (no outbound network access during `docker build`),
so Docker Bench still could not evaluate this project's actual image.
