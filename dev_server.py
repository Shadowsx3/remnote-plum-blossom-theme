#!/usr/bin/env python3
"""Local dev server for the Plum Blossom 紫梅 RemNote theme.

Serves this folder over HTTP the way RemNote's "Develop from localhost" flow
expects, so you can load and test the theme without publishing anything.

    ./dev.sh                      # then use http://localhost:8080

Why a custom server rather than `python3 -m http.server`:

* RemNote fetches manifest.json / theme.css from its own origin, so the
  responses need `Access-Control-Allow-Origin: *` (the webpack template sets
  the same header for the same reason).
* `Cache-Control: no-store`, so editing theme.css and refreshing RemNote shows
  the change instead of a cached stylesheet.
* Every request is logged, which is how you confirm RemNote actually fetched
  the theme.
"""

import argparse
import functools
import http.server
import json
import os
import socket
import sys
import threading
import time
import urllib.request
from typing import Optional, Tuple

DEFAULT_PORT = 8080  # RemNote's "Develop from localhost" default


class ThemeHandler(http.server.SimpleHTTPRequestHandler):
    """Static files, CORS-open, never cached."""

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()

    def do_OPTIONS(self):  # noqa: N802 - name fixed by the base class
        self.send_response(204)
        self.end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("  %s\n" % (fmt % args))
        sys.stderr.flush()


LOOPBACK_HOSTS = ("127.0.0.1", "[::1]", "localhost")


def probe(host: str, port: int) -> Tuple[Optional[str], Optional[str]]:
    """Return (manifest id, error) for one loopback address."""
    url = f"http://{host}:{port}/manifest.json"
    try:
        with urllib.request.urlopen(url, timeout=3) as response:
            return json.load(response).get("id"), None
    except Exception as exc:  # noqa: BLE001 - any failure means "not usable"
        return None, f"{type(exc).__name__}: {exc}"


def self_check(port: int, expected_id: Optional[str]) -> Tuple[bool, list]:
    """Confirm every loopback address for this port serves *this* theme.

    Checking only 127.0.0.1 is not enough. A webpack dev server from another
    plugin binds the IPv6 wildcard, which lets this server take 127.0.0.1 and
    quietly share the port. RemNote resolves `localhost` to `::1` first on
    macOS, so it could load the other plugin while 127.0.0.1 looks fine. Only
    asking all three addresses tells the truth.
    """
    lines = []
    mismatched = []
    for host in LOOPBACK_HOSTS:
        got, error = probe(host, port)
        if error:
            lines.append(f"{host}:{port} -> not answering ({error})")
            continue
        if expected_id and got == expected_id:
            lines.append(f"{host}:{port} -> {got!r}  (this theme)")
        else:
            lines.append(f"{host}:{port} -> {got!r}  <-- NOT this theme")
            mismatched.append(host)
    return (not mismatched), lines


class DualStackServer(http.server.ThreadingHTTPServer):
    """Listen on both 127.0.0.1 and ::1 with one socket.

    The official RemNote template's webpack dev server binds `*:8080` (IPv6
    dual-stack) for this reason: RemNote may resolve `localhost` to either
    address, and a v4-only bind leaves ::1 refused. IPV6_V6ONLY=0 makes the
    IPv6 socket also accept IPv4, so both spellings of localhost work.
    """

    address_family = socket.AF_INET6

    def server_bind(self):
        try:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        except OSError:
            pass  # already dual-stack, or a platform without the knob
        super().server_bind()


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve this theme locally.")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument(
        "--host",
        default="::",
        help="bind address (default: '::' = dual-stack, like the template's dev "
        "server; use 127.0.0.1 to keep it off your LAN)",
    )
    parser.add_argument(
        "--dir",
        default=os.path.dirname(os.path.abspath(__file__)),
        help="folder to serve (default: the folder this script lives in)",
    )
    args = parser.parse_args()

    handler = functools.partial(ThemeHandler, directory=args.dir)
    try:
        httpd = DualStackServer((args.host, args.port), handler)
    except OSError as exc:
        print(f"Could not listen on {args.host}:{args.port} ({exc}).", file=sys.stderr)
        print("RemNote expects port 8080, so free it first:", file=sys.stderr)
        print(f"  lsof -nP -iTCP:{args.port} -sTCP:LISTEN", file=sys.stderr)
        return 1

    base = f"http://localhost:{args.port}"
    print(f"serving {args.dir}")
    print()
    print(f"  preview          {base}/preview.html")
    print(f"  theme.css        {base}/theme.css")
    print(f"  manifest.json    {base}/manifest.json")
    print()
    print("  in RemNote:  Settings -> Plugins -> Build -> \"Develop from localhost\"")
    print(f"               enter {base}/ and click Develop")
    print()
    print("  Ctrl+C to stop")
    print()

    # Read back our own manifest through the port. If something else is holding
    # it, say so plainly instead of letting RemNote load the wrong plugin.
    expected_id = None
    try:
        with open(os.path.join(args.dir, "manifest.json"), encoding="utf-8") as fh:
            expected_id = json.load(fh).get("id")
    except Exception:  # noqa: BLE001 - the check below reports the useful part
        pass

    def report_port() -> None:
        time.sleep(0.6)
        ok, lines = self_check(args.port, expected_id)
        for line in lines:
            print("    " + line)
        print("  ok    every loopback address serves this theme" if ok else "  WARN  another server is sharing this port")
        if not ok:
            print()
            print("  RemNote's \"Develop from localhost\" only talks to port 8080, and on")
            print("  macOS `localhost` resolves to ::1 first. A webpack dev server from")
            print("  another plugin binds the IPv6 wildcard, so RemNote could load *that*")
            print("  plugin instead of this theme. Free the port first:")
            print()
            print(f"    lsof -nP -iTCP:{args.port} -sTCP:LISTEN     # who is it?")
            print("    kill <pid>                                  # or Ctrl+C there")
            print()
        sys.stdout.flush()

    threading.Thread(target=report_port, daemon=True).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
