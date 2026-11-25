#!/usr/bin/env python3
"""Fills the contact e-mail and developer name everywhere in one command.
Usage (from the project root): python3 store/fill_placeholders.py --email you@example.com --name "Name"
"""
import argparse, glob, re, sys

TOKEN = "ADD_CONTACT_EMAIL_BEFORE_PUBLISHING"
NAME_TOKEN = "DEVELOPER_NAME_PLACEHOLDER"

ap = argparse.ArgumentParser()
ap.add_argument("--email", required=True)
ap.add_argument("--name", required=True)
a = ap.parse_args()
if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", a.email):
    sys.exit("invalid e-mail")

files = ["lib/core/config.dart", "PRIVACY.md"] + glob.glob("store/**/*.html", recursive=True) + glob.glob("store/*.md")
for f in files:
    t = open(f, encoding="utf-8").read()
    n = t.replace(TOKEN, a.email).replace(NAME_TOKEN, a.name)
    if n != t:
        open(f, "w", encoding="utf-8").write(n)
        print("updated", f)
print("done. lib/features/privacy/privacy_text.dart keeps the token on purpose: the app fills it from config.dart.")
