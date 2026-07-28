# Secure Containerized Web App — DevSecOps Hardening Suite

A minimal Flask app used to demonstrate container security scanning and hardening (Trivy, Hadolint, Bandit, Docker Bench for Security).

This is a portfolio project built to practice and showcase container security
scanning skills for Cloud Security / DevSecOps roles. The app itself is
intentionally trivial — the point is the security tooling and workflow around
it, not the application logic.

## How it works

This repo demonstrates a before/after security hardening workflow. The
original scaffold intentionally shipped with three flaws, each tagged in
git history with a `# INTENTIONAL FLAW:` comment:

1. An outdated, vulnerable base image pinned in the `Dockerfile`
   (`python:3.9.0-slim`)
2. No non-root `USER` directive in the `Dockerfile`, so the container ran as
   root
3. A Flask secret key hardcoded directly in `app.py`

All three have since been fixed on `main` — look for `# FIXED:` comments in
`Dockerfile` and `app.py` marking each resolution (the base image was later
switched again, to `python:3.14-alpine`, to eliminate a set of CRITICAL CVEs
found in a transitive OS package). [`findings.md`](findings.md) documents
the full before/after story: what each scanner found on the flawed version,
how each flaw was fixed, and what the same scanners report now.

## Continuous integration

[![Security Scans](https://github.com/NoraAlajmi/devsecops-container-security-suite/actions/workflows/security.yml/badge.svg)](https://github.com/NoraAlajmi/devsecops-container-security-suite/actions/workflows/security.yml)

`.github/workflows/security.yml` runs Hadolint, Bandit, and Trivy
automatically on every push to `main` and every pull request, so a
regression of any of these flaws (or a new one) gets caught in CI instead of
relying on someone remembering to scan locally. See the
[Actions tab](https://github.com/NoraAlajmi/devsecops-container-security-suite/actions)
for run history.

## Project structure

| File | Purpose |
|------|---------|
| `app.py` | Minimal Flask app with a home route and a `/health` check route |
| `requirements.txt` | Python dependencies |
| `Dockerfile` | Container build definition |
| `.env.example` | Template for environment variables the app expects |
| `.github/workflows/security.yml` | CI pipeline: Hadolint, Bandit, and Trivy on every push/PR |
| `findings.md` | Scan results from each security tool, before and after hardening |
| `LICENSE` | MIT license |

## Running locally

```bash
pip install -r requirements.txt
python app.py
```

The app listens on `http://localhost:5000/` with a health check at
`http://localhost:5000/health`.

## Tools used

- [Trivy](https://trivy.dev/) — image vulnerability scanning and Dockerfile
  misconfiguration scanning
- [Bandit](https://bandit.readthedocs.io/) — Python static security analysis
- [Hadolint](https://github.com/hadolint/hadolint) — Dockerfile linting
- [Docker Bench for Security](https://github.com/docker/docker-bench-security)
  — CIS Docker benchmark auditing

## Known limitations

- **Docker Bench for Security could not fully evaluate this project's image.** In the
  development environment used to build this demo, `docker build` has no outbound network
  access, so the `pip install -r requirements.txt` step in the Dockerfile cannot reach PyPI
  and the image never finishes building. Docker Bench audits *built images and running
  containers*, not raw Dockerfile text, so without a built image its container/image-level
  checks (e.g. CIS check 4.1, "Ensure a user for the container has been created") fell back
  to auditing unrelated pre-existing images on the host instead of this project's Dockerfile.
  The missing-non-root-user flaw is instead verified via `trivy config Dockerfile` (rule
  DS-0002, HIGH), which performed the equivalent static check successfully. Running Docker
  Bench against the real built image would require an environment with outbound network
  access during `docker build`.
