#!/usr/bin/env bash
# Set up chartgen on a fresh Mac. Normally launched by install.command.
#
# Finds a Python 3.10-3.14 with tkinter, creates the venv and installs
# torch, picking CPU or Apple Silicon (MPS) automatically, then verifies the
# result.
#
# The .venv is never copied between machines - it hardcodes absolute
# interpreter and project paths. Only the ~1 MB of source travels; this
# rebuilds the rest.
#
# Usage:
#   ./setup.sh                   # normal install
#   ./setup.sh --training        # also install the training stack
#   ./setup.sh --non-interactive # don't prompt (used by CI / the installer)

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TRAINING=0
NON_INTERACTIVE=0
for arg in "$@"; do
    case "$arg" in
        --training) TRAINING=1 ;;
        --non-interactive) NON_INTERACTIVE=1 ;;
        *) echo "unknown flag: $arg (expected --training / --non-interactive)" >&2; exit 1 ;;
    esac
done

say() { printf '%s\n' "$1"; }

say "chartgen setup"
say "--------------------------------------------------"

# ---------------------------------------------------------------- 1. Python
find_python() {
    for candidate in python3.13 python3.12 python3.14 python3.11 python3.10 python3; do
        command -v "$candidate" >/dev/null 2>&1 || continue
        version=$("$candidate" -c "import sys;print('%d.%d'%sys.version_info[:2])" 2>/dev/null) || continue
        case "$version" in
            3.1[0-4]) ;;
            *) continue ;;
        esac
        # tkinter is not optional here: the UI is built on it, and Homebrew's
        # python formula needs python-tk installed alongside it.
        if "$candidate" -c "import tkinter" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
        say "  $candidate has no tkinter, skipping"
    done
    return 1
}

PYTHON="$(find_python || true)"
if [ -z "$PYTHON" ]; then
    say "No suitable Python found (need 3.10-3.14 with tkinter)."
    say ""
    say "Install one, then re-run this script:"
    say "  brew install python-tk@3.13      (Homebrew; installs tkinter too)"
    say "  or a python.org installer from https://www.python.org/downloads/"
    say "  (its installer bundles tkinter already)"
    exit 1
fi
say "python       $PYTHON ($("$PYTHON" -c 'import sys;print(sys.version.split()[0])'))"

# ------------------------------------------------------- 2. vendored sources
# Optional: neither is on the default charting path. EasyChartGenerator (MIT)
# backs the `--reducer easygen` A/B option; ChartFormats (CC0) is the .chart
# spec, kept for reference. Fetched when git is available, skipped otherwise.
# Parallel arrays, not `declare -A`: macOS ships bash 3.2 (no associative
# arrays; those need bash 4+) as /bin/bash, and this script must run there.
vendor_paths=(vendor/EasyChartGenerator vendor/ChartFormats)
vendor_urls=(
    "https://github.com/Eerovil/EasyChartGenerator.git"
    "https://github.com/TheNathannator/GuitarGame_ChartFormats.git"
)
for i in "${!vendor_paths[@]}"; do
    path="${vendor_paths[$i]}"
    [ -d "$path" ] && continue
    if ! command -v git >/dev/null 2>&1; then
        say "vendor       $path skipped (optional; needs git)"
        continue
    fi
    say "cloning $path (optional)"
    git clone --depth 1 "${vendor_urls[$i]}" "$path" || say "vendor       $path skipped (clone failed; optional)"
done

# ------------------------------------------------------------------ 3. GPU
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then
    say "gpu          Apple Silicon detected -> MPS available to PyTorch (chartgen itself still runs its models on CPU; see README)"
else
    say "gpu          Intel Mac -> CPU build"
fi

# --------------------------------------------------------------- 4. install
if [ ! -d .venv ]; then
    say ""
    say "creating .venv ..."
    "$PYTHON" -m venv .venv
fi
PY=.venv/bin/python
"$PY" -m pip install --upgrade pip --quiet

say ""
say "installing torch (this is the big one, a few minutes) ..."
# No special index needed on macOS: the default PyPI wheel covers both CPU
# and Apple Silicon (MPS) builds, unlike Windows/Linux where CUDA needs its
# own index.
"$PY" -m pip install torch==2.9.1 torchaudio==2.9.1

say ""
say "installing everything else ..."
"$PY" -m pip install -r requirements.txt

# basic-pitch's wheel pulls in a tensorflow pin that is unnecessary baggage
# here (and fragile on Apple Silicon); --no-deps is enough because the ONNX
# backend is what actually runs and only needs onnxruntime (already
# installed from requirements.txt).
say ""
say "installing basic-pitch (transcription model) ..."
"$PY" -m pip install "basic-pitch==0.4.0" --no-deps

if [ "$TRAINING" -eq 1 ]; then
    say ""
    say "installing training stack ..."
    "$PY" -m pip install "pytorch-lightning==2.5.6" "lightning==2.5.5" \
        "hydra-core==1.3.2" "omegaconf==2.3.0" "torchmetrics==1.8.2" "wandb==0.22.2"
fi

# ----------------------------------------------------------------- 5. verify
say ""
say "--- verifying ---"
"$PY" -c "
import sys, torch, tkinter
print('python      ', sys.version.split()[0])
print('torch       ', torch.__version__)
print('tkinter      ok (the UI needs it)')
if torch.backends.mps.is_available():
    print('gpu          Apple Silicon MPS available (chartgen runs CPU-only for now; see README)')
else:
    print('gpu          none - generating charts works, training does not')
"

"$PY" -m tests.test_chartgen

say ""
say "Ready. Double-click chartgen.command to open the app."
say "The first charts download the separation and lyric models (~2.5 GB in total) automatically."
