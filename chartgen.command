#!/usr/bin/env bash
# Double-click to open the chartgen UI.
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

# Check that the app imports before launching detached - a detached process
# that fails at startup would otherwise fail invisibly.
err_log="$(mktemp -t chartgen-app-check)"
trap 'rm -f "$err_log"' EXIT
if ! .venv/bin/python3 -c "import chartgen.app" 2>"$err_log"; then
    echo
    echo " The app failed to load. Details:"
    echo
    cat "$err_log"
    echo
    echo " Try re-running install.command."
    echo
    read -n 1 -s -r -p "Press any key to close..."
    echo
    exit 1
fi

nohup .venv/bin/python3 -m chartgen.app >/dev/null 2>&1 &
disown
