# Secure Containerized Web App — DevSecOps Hardening Suite

A minimal Flask app used to demonstrate container security scanning and hardening (Trivy, Hadolint, Bandit, Docker Bench for Security).

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
