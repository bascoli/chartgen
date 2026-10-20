#!/usr/bin/env bash
# Double-click this first, once, on a new Mac.
#
# macOS Gatekeeper will likely warn that this is from an unidentified
# developer the first time you double-click it: right-click (or
# Control-click) the file, choose Open, then confirm - that's a one-time
# step per machine.
cd "$(dirname "$0")"
echo
echo " chartgen installer"
echo " ------------------"
echo " Sets up Python, PyTorch and dependencies. Needs an internet connection."
echo " Expect several minutes and roughly 3 GB of downloads."
echo

chmod +x setup.sh
if ./setup.sh "$@"; then
    echo
    echo " Setup finished. You can now double-click chartgen.command"
else
    echo
    echo " Setup FAILED - see the messages above."
fi

echo
read -n 1 -s -r -p "Press any key to close this window..."
echo
