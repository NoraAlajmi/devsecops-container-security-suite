from flask import Flask

app = Flask(__name__)

# INTENTIONAL FLAW: hardcoded Flask secret key committed to source control.
# Should be loaded from an environment variable or secrets manager instead.
app.secret_key = "supersecret123"


@app.route("/")
def home():
    return "Welcome to the Secure Containerized Web App demo!"


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
