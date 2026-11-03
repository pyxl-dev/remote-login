#!/usr/bin/env python3
"""Tiny sign-in site on 127.0.0.1:8799 to test remote-login end to end.
Test account (fixture only): demo / demo-pass-8799."""
import http.server, secrets, urllib.parse
USER, PASS = "demo", "demo-pass-8799"
SESSIONS = set()
FORM = b"""<!doctype html><meta name=viewport content="width=device-width"><h1>Connexion test</h1>
<form method=post action=/login><p><input name=u placeholder=Utilisateur autofocus style="font-size:20px;width:90%"></p>
<p><input name=p type=password placeholder="Mot de passe" style="font-size:20px;width:90%"></p><p><button style="font-size:20px">Se connecter</button></p></form>"""
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
            if self.sid(): return self.page("<h1>Compte</h1><p id=who>Connecté en tant que demo</p>".encode())
            return self.page(b"", 302, [("Location", "/")])
        self.page(FORM)
    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        f = urllib.parse.parse_qs(self.rfile.read(n).decode())
        if f.get("u", [""])[0] == USER and f.get("p", [""])[0] == PASS:
            s = secrets.token_hex(8); SESSIONS.add(s)
            return self.page(b"", 302, [("Set-Cookie", f"sid={s}; Path=/; HttpOnly"), ("Location", "/account")])
        self.page(b"<p>Mauvais identifiants</p>" + FORM, 401)
http.server.ThreadingHTTPServer(("127.0.0.1", 8799), H).serve_forever()
