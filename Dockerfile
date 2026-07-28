# FIXED: replaced outdated python:3.9.0-slim (flaw a) with a current, patched slim image.
FROM python:3.14.6-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# FIXED: create and switch to a non-root user (resolves flaw b) instead of running as root.
RUN useradd --create-home --shell /usr/sbin/nologin appuser
USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
