# INTENTIONAL FLAW: outdated/pinned base image with known CVEs (should use a current slim tag).
FROM python:3.9.0-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# INTENTIONAL FLAW: no USER directive — container runs as root by default.

EXPOSE 5000

CMD ["python", "app.py"]
