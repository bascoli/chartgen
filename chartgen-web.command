#!/usr/bin/env bash
# chartgen web UI: chart songs from your phone/laptop, get the zip back.
#
# Listens on http://127.0.0.1:8471 - the right thing behind a Cloudflare
# Tunnel on this Mac (see docs/remote-access.md). To reach it over Tailscale
# or the LAN instead, run from a terminal:  ./chartgen-web.command --host 0.0.0.0
#
# Set CHARTGEN_WEB_OWNERS to the email(s) Cloudflare Access signs you in
# with; everyone else charts as a guest whose songs are handed over and
# deleted rather than kept in the library.
cd "$(dirname "$0")"

if [ ! -x ".venv/bin/python3" ]; then
    echo
    echo " Not set up yet on this machine."
    echo " Double-click install.command first, then come back here."
    echo
    read -n 1 -s -r -p "Press any key to close..."
    echo
    exit 1
fi

export HF_HUB_DISABLE_PROGRESS_BARS=1
.venv/bin/python3 -m chartgen.web "$@"

echo
read -n 1 -s -r -p "Press any key to close..."
echo
