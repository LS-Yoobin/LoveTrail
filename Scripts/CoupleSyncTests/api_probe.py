#!/usr/bin/env python3
"""BAB-147 integration helper: watch couple profile sync against a STAGING API.

Two modes, both refuse known production hosts and never print tokens, passwords,
invite codes, signed URLs, request headers or raw bodies.

  proxy  Local logging reverse proxy. Point a simulator at it with
         COVELA_API_BASE_URL=http://127.0.0.1:<port><api-base-path>. Logs one line per
         request (method, redacted path, status, time) plus a redacted summary of
         GET /pairing-status, GET /couple/profile and PATCH /couple/profile.

  probe  Read-only check for one test account: signs in, then GETs /pairing-status
         and /couple/profile and prints the same redacted summary. Credentials are read
         from the environment (COVELA_PROBE_EMAIL / COVELA_PROBE_PASSWORD), never args.

Names and ids are shown as length + short SHA-256 prefix, so two devices can be
compared ("A's own entry hash == B's partner entry hash") without printing them.

Usage:
  python3 -I api_probe.py proxy --upstream https://<staging-host>/covela/api [--port 8787]
  COVELA_PROBE_EMAIL=... COVELA_PROBE_PASSWORD=... \
    python3 -I api_probe.py probe --api https://<staging-host>/covela/api
"""
import argparse
import getpass
import hashlib
import http.client
import json
import os
import re
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PRODUCTION_HOSTS = {
    "pocketverse.herokuapp.com",
    "api.covela.app",
    "ls-file-server-4312402ca23f.herokuapp.com",
}
HOP_BY_HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
              "te", "trailers", "transfer-encoding", "upgrade", "host", "accept-encoding",
              "content-length"}


def refuse_production(url):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ("https", "http") or not parsed.hostname:
        sys.exit(f"Invalid URL: {url}")
    if parsed.hostname.lower() in PRODUCTION_HOSTS:
        sys.exit(f"Refusing production host {parsed.hostname}. Use a staging API URL.")
    if parsed.scheme == "http" and parsed.hostname not in ("127.0.0.1", "localhost"):
        sys.exit("Plain http is only allowed for localhost.")
    return parsed


def tag(value):
    """Length + short hash: comparable across devices, not readable."""
    if value is None:
        return "null"
    if not isinstance(value, str):
        return f"<{type(value).__name__}>"
    if value == "":
        return "empty"
    digest = hashlib.sha256(value.encode()).hexdigest()[:8]
    return f"len{len(value)}#{digest}"


def redact_path(path):
    path = path.split("?", 1)[0]
    # /invite/<code> and /invite/<code>/... carry the invite code.
    return re.sub(r"(/invite/)[^/]+", r"\1<code>", path)


def summarize(method, path, status, req_body, resp_body):
    """Redacted one-line summary for the three BAB-147 endpoints, else None."""
    try:
        resp = json.loads(resp_body) if resp_body else {}
    except ValueError:
        resp = {}
    if not isinstance(resp, dict):
        resp = {}
    reason = resp.get("reason")
    out = []
    if status >= 400:
        return f"reason={reason}" if reason else None
    if path.endswith("/pairing-status") and method == "GET":
        out.append(f"paired={resp.get('paired')} stage={resp.get('relationship_stage')} "
                   f"invite_sent={resp.get('invite_sent')} partner_name={tag(resp.get('partner_name'))}")
    elif path.endswith("/couple/profile") and method == "GET":
        profiles = resp.get("partner_profiles")
        out.append(f"couple_profile_id={tag(resp.get('couple_profile_id'))} "
                   f"note={tag(resp.get('note'))} mood={resp.get('mood')!r} updated_at={resp.get('updated_at')}")
        if isinstance(profiles, list):
            out.append(f"partner_profiles={len(profiles)}")
            for entry in profiles:
                if isinstance(entry, dict):
                    out.append(f"  user={tag(str(entry.get('user_id', '')).lower())} "
                               f"nickname={tag(entry.get('nickname'))} "
                               f"avatar_path={tag(entry.get('avatar_path'))} "
                               f"avatar_url={'present' if entry.get('avatar_url') else 'none'}")
        else:
            out.append("partner_profiles=MISSING")
    elif path.endswith("/couple/profile") and method in ("PATCH", "PUT"):
        try:
            req = json.loads(req_body) if req_body else {}
        except ValueError:
            req = {}
        own = req.get("partner_profile") if isinstance(req, dict) else None
        own = own if isinstance(own, dict) else {}
        out.append(f"sent note={tag(req.get('note'))} mood={req.get('mood')!r} "
                   f"nickname={tag(own.get('nickname'))} "
                   f"avatar_path={'absent' if 'avatar_path' not in own else tag(own.get('avatar_path'))} "
                   f"base_updated_at={'present' if req.get('base_updated_at') else 'absent'}")
        out.append(f"answer updated_at={resp.get('updated_at')}")
    else:
        return f"reason={reason}" if reason and status >= 400 else None
    if reason:
        out.append(f"reason={reason}")
    return "\n      ".join(out)


# MARK: proxy

def run_proxy(upstream, port):
    target = refuse_production(upstream)
    conn_cls = http.client.HTTPSConnection if target.scheme == "https" else http.client.HTTPConnection

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *args):  # default logging prints raw paths; suppress it
            pass

        def _forward(self):
            started = time.time()
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else b""
            headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP_BY_HOP}
            headers["Accept-Encoding"] = "identity"
            try:
                conn = conn_cls(target.hostname, target.port, timeout=30)
                conn.request(self.command, self.path, body=body or None, headers=headers)
                resp = conn.getresponse()
                data = resp.read()
                status = resp.status
                resp_headers = [(k, v) for k, v in resp.getheaders() if k.lower() not in HOP_BY_HOP]
                conn.close()
            except OSError as error:
                status, data, resp_headers = 502, b'{"result":"FAIL","reason":"proxy_upstream_error"}', \
                    [("Content-Type", "application/json")]
                print(f"[proxy] upstream error: {type(error).__name__}", flush=True)

            self.send_response(status)
            for k, v in resp_headers:
                self.send_header(k, v)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

            path = redact_path(self.path)
            ms = int((time.time() - started) * 1000)
            line = f"{time.strftime('%H:%M:%S')} {self.command:6} {path} -> {status} ({ms}ms)"
            if path.endswith("/auth/login") or path.endswith("/auth/register") or path.endswith("/auth/apple"):
                print(line, flush=True)   # status only; bodies hold credentials
                return
            summary = summarize(self.command, path, status, body, data)
            print(line + (f"\n      {summary}" if summary else ""), flush=True)

        do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = _forward

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"[proxy] 127.0.0.1:{port} -> {target.scheme}://{target.hostname} (paths passed through)", flush=True)
    print(f"[proxy] app base URL: http://127.0.0.1:{port}{target.path}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


# MARK: probe (read-only)

def run_probe(api):
    base = refuse_production(api)
    email = os.environ.get("COVELA_PROBE_EMAIL") or input("email: ")
    password = os.environ.get("COVELA_PROBE_PASSWORD") or getpass.getpass("password: ")
    conn_cls = http.client.HTTPSConnection if base.scheme == "https" else http.client.HTTPConnection

    def call(method, suffix, payload=None, token=None):
        conn = conn_cls(base.hostname, base.port, timeout=30)
        headers = {"Content-Type": "application/json", "Accept-Encoding": "identity"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        body = json.dumps(payload).encode() if payload is not None else None
        conn.request(method, base.path.rstrip("/") + suffix, body=body, headers=headers)
        resp = conn.getresponse()
        data = resp.read()
        conn.close()
        return resp.status, data

    status, data = call("POST", "/auth/login", {"email": email, "password": password})
    del password
    if status != 200:
        sys.exit(f"login -> {status} (credentials not shown)")
    login = json.loads(data)
    token, user_id = login.get("token"), str(login.get("userId", "")).lower()
    print(f"login -> 200, user={tag(user_id)}")
    for suffix in ("/pairing-status", "/couple/profile"):
        status, data = call("GET", suffix, token=token)
        print(f"GET {suffix} -> {status}\n      {summarize('GET', suffix, status, b'', data)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="mode", required=True)
    p = sub.add_parser("proxy")
    p.add_argument("--upstream", required=True)
    p.add_argument("--port", type=int, default=8787)
    q = sub.add_parser("probe")
    q.add_argument("--api", required=True)
    args = parser.parse_args()
    run_proxy(args.upstream, args.port) if args.mode == "proxy" else run_probe(args.api)
