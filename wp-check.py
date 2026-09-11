#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wpcek.py -- WordPress Client Audit Tool v4.0 (Playwright edition, defensive, read-only)
========================================================================================

Verifies a credential you ALREADY HOLD against a WordPress site you are
authorised to manage, detects the effective role accurately, and runs a
set of passive, read-only security-posture checks. Produces a CSV report
suitable for client maintenance / handover.

This version drives a real Chromium browser via Playwright (same engine as
checker/core.py) instead of raw `requests` -- pages that gate behind
JS-rendered challenges (Cloudflare/WAF interstitials, JS-only login forms)
are handled the same way a real browser would see them.

Implementation lives in the wpcheck/ package next to this file (config,
status codes, models, fetch layer, discovery, fingerprinting, login,
role detection, Telegram notifications, pipeline, orchestrator, CLI) --
this script is just the entry point.

USAGE (unchanged workflow):
    python wp-check.py input.txt output.csv
    python wp-check.py input.txt output.csv --workers 8 --timeout 25 --delay 1.5
    python wp-check.py input.txt output.csv --no-login      # audit only, no auth
    python wp-check.py                                       # interactive picker

INPUT FORMAT (one target per line):
    https://example.com:admin:the-password
    https://example.com/blog<TAB>admin<TAB>the-password    (tab-delimited also OK)
    https://example.com                                    (audit only, no creds)

    * Prefer per-site WordPress "Application Passwords" over the client's real
      login password: they are revocable, scoped, and safer to store in a file.
    * Lines beginning with '#' are ignored.

DESIGN BOUNDARIES (by intent -- this is an auditor's tool, not an attacker's):
    * ONE credential is verified per site. No password lists, no iteration,
      no retry on an authentication failure. This is not, and must not become,
      a brute-force / password-spraying / credential-stuffing tool.
    * If a site presents CAPTCHA, a WAF challenge, or rate-limiting, the tool
      REPORTS it and STOPS. It never attempts to bypass a protection.
    * All post-login checks are read-only GETs. Nothing is created, changed,
      or deleted on the target.
    * Passwords are NEVER printed, logged, written to the CSV, or embedded in
      error messages.

Requires: playwright. Optional: colorama (coloured console; degrades cleanly).
Windows-compatible. Run `playwright install chromium` once before first use.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from wpcheck.cli import main  # noqa: E402

if __name__ == "__main__":
    main()
