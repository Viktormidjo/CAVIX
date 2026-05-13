from flask import Flask, render_template
import psycopg2
import base64
import os

app = Flask(__name__)


def get_db():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "db"),
        dbname=os.environ.get("DB_NAME", "appdb"),
        user=os.environ.get("DB_USER", "appuser"),
        password=os.environ.get("DB_PASS", "supersecret")
    )


@app.route("/")
def index():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT text FROM comments LIMIT 5;")
    comments = [row[0] for row in cur.fetchall()]
    cur.execute("SELECT data FROM images LIMIT 1;")
    img = cur.fetchone()
    img_b64 = base64.b64encode(img[0]).decode() if img else ""
    cur.close()
    conn.close()
    return render_template("index.html", comments=comments, img_b64=img_b64)


@app.route("/info")
def info():
    return render_template("info.html")


@app.route("/teamet")
def teamet():
    ansatte = [
        {"navn": "Ola Nordmann",   "rolle": "IT-drift",            "epost": "ola.nordmann@bedriften.no"},
        {"navn": "Kari Hansen",    "rolle": "Prosjektleder",       "epost": "kari.hansen@bedriften.no"},
        {"navn": "Lars Eriksen",   "rolle": "Programvareutvikler", "epost": "lars.eriksen@bedriften.no"},
        {"navn": "Marte Johansen", "rolle": "Økonomiansvarlig",    "epost": "marte.johansen@bedriften.no"},
        {"navn": "Thomas Berg",    "rolle": "Salg og marked",      "epost": "thomas.berg@bedriften.no"},
    ]
    for a in ansatte:
        a["initialer"] = "".join(ord[0] for ord in a["navn"].split())
    return render_template("teamet.html", ansatte=ansatte)


@app.route("/kontakt")
def kontakt():
    return render_template("kontakt.html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
