import os

from flask import Flask

app = Flask(__name__)

# FIXED: load the secret key from the environment (resolves flaw c) instead of
# hardcoding it. No insecure default — this raises KeyError and fails loudly
# if FLASK_SECRET_KEY isn't set, rather than silently falling back to something.
app.secret_key = os.environ["FLASK_SECRET_KEY"]


@app.route("/")
def home():
    return "Welcome to the Secure Containerized Web App demo!"


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    # Binding to all interfaces is intentional: this runs inside a container, and
    # 0.0.0.0 is what makes the exposed port reachable from outside the container.
    app.run(host="0.0.0.0", port=5000)  # nosec B104
