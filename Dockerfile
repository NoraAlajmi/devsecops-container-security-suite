# FIXED: replaced outdated python:3.9.0-slim (flaw a) with a current, patched image.
# Switched to Alpine (musl libc, BusyBox userland) instead of Debian slim: it has a much
# smaller package set, which eliminates the perl-base CRITICAL CVEs Trivy found in the
# Debian-based image, and reduces overall image size/attack surface.
FROM python:3.14-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# FIXED: create and switch to a non-root user (resolves flaw b) instead of running as root.
# Alpine's BusyBox userland doesn't ship useradd/passwd — adduser is the equivalent here.
RUN adduser -D appuser
USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
