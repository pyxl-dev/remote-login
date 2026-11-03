#!/usr/bin/env python3
"""Tiny sign-in site on 127.0.0.1:8799 to test remote-login end to end.
Test account (fixture only): demo / demo-pass-8799."""
import http.server, secrets, urllib.parse
USER, PASS = "demo", "demo-pass-8799"
SESSIONS = set()
STYLE = """<meta name=viewport content="width=device-width,initial-scale=1"><style>
body{margin:0;font:16px/1.4 -apple-system,system-ui,Roboto,sans-serif;background:#f3f4f6;color:#111827}
main{max-width:360px;margin:0 auto;padding:40px 20px}.logo{width:44px;height:44px;border-radius:12px;background:#2563eb;margin-bottom:24px}
h1{font-size:26px;margin:0 0 6px}p.sub{color:#6b7280;margin:0 0 28px}label{display:block;font-size:14px;font-weight:600;margin:0 0 6px}
input{display:block;width:100%;box-sizing:border-box;font:inherit;padding:12px 14px;border:1px solid #d1d5db;border-radius:10px;background:#fff;margin:0 0 18px}
input:focus{outline:2px solid #2563eb;border-color:transparent}button{width:100%;font:inherit;font-weight:600;padding:13px;border:0;border-radius:10px;background:#2563eb;color:#fff;margin-top:6px}
.err{color:#b91c1c}</style>"""
FORM = (STYLE + """<main><div class=logo></div><h1>Connexion</h1><p class=sub>Site de test de remote-login</p>
<form method=post action=/login><label for=u>Utilisateur</label><input id=u name=u autocomplete=username>
<label for=p>Mot de passe</label><input id=p name=p type=password autocomplete=current-password>
<button>Se connecter</button></form></main>""").encode()
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def sid(self):
        for c in (self.headers.get("Cookie") or "").split(";"):
            k, _, v = c.strip().partition("=")
            if k == "sid" and v in SESSIONS: return v
    def page(self, body, code=200, extra=()):
        self.send_response(code); self.send_header("Content-Type", "text/html; charset=utf-8")
        for k, v in extra: self.send_header(k, v)
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if self.path == "/account":
            if self.sid(): return self.page((STYLE + "<main><h1>Compte</h1><p id=who>Connecté en tant que demo</p></main>").encode())
            return self.page(b"", 302, [("Location", "/")])
        self.page(FORM)
    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        f = urllib.parse.parse_qs(self.rfile.read(n).decode())
        if f.get("u", [""])[0] == USER and f.get("p", [""])[0] == PASS:
            s = secrets.token_hex(8); SESSIONS.add(s)
            return self.page(b"", 302, [("Set-Cookie", f"sid={s}; Path=/; HttpOnly"), ("Location", "/account")])
        self.page(FORM.replace(b"<form", b"<p class=err>Mauvais identifiants</p><form"), 401)
http.server.ThreadingHTTPServer(("127.0.0.1", 8799), H).serve_forever()
