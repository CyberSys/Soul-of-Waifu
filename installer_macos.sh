#!/usr/bin/env bash
#
# Soul of Waifu v2.5.1 — macOS Installer
# Usage: bash installer.sh
#

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ "$(pwd)" =~ " " ]]; then
    echo "ERROR: This script cannot be run from a path containing spaces."
    exit 1
fi

# deactivate existing conda envs as needed to avoid conflicts
{ conda deactivate && conda deactivate && conda deactivate; } 2>/dev/null || true

echo "=============================================="
echo "  Soul of Waifu v2.5.1 Installer (macOS)"
echo "=============================================="
echo

# ── Step [1/6] System dependencies ──────────────────────────────────────────
echo "[1/6] Checking system dependencies..."

# Check for Homebrew
if ! command -v brew &>/dev/null; then
    echo "  Homebrew not found."
    echo "  Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

MISSING=0
check_brew_pkg() {
    local pkg="$1"
    if ! brew list "$pkg" &>/dev/null 2>&1; then
        echo "  WARNING: $pkg not found. Installing via Homebrew..."
        brew install "$pkg" || MISSING=1
    fi
}

check_brew_pkg "ffmpeg"
check_brew_pkg "portaudio"

# libsndfile needed by soundfile
if ! brew list libsndfile &>/dev/null 2>&1; then
    echo "  Installing libsndfile (required by soundfile)..."
    brew install libsndfile || true
fi

# ── Step [2/6] Miniconda setup ──────────────────────────────────────────────
echo "[2/6] Setting up Miniconda3..."

INSTALL_DIR="$(pwd)/installer_files"
CONDA_ROOT_PREFIX="$(pwd)/installer_files/conda"
INSTALL_ENV_DIR="$(pwd)/installer_files/env"

OS_ARCH="$(uname -m)"
MINICONDA_DOWNLOAD_URL="https://repo.anaconda.com/miniconda/Miniconda3-py311_24.11.1-0-MacOSX-${OS_ARCH}.sh"
conda_exists="F"

if "$CONDA_ROOT_PREFIX/bin/conda" --version &>/dev/null; then
    conda_exists="T"
fi

if [ "$conda_exists" == "F" ]; then
    echo "  Downloading Miniconda from $MINICONDA_DOWNLOAD_URL"
    mkdir -p "$INSTALL_DIR"
    curl -L "$MINICONDA_DOWNLOAD_URL" > "$INSTALL_DIR/miniconda_installer.sh"
    chmod u+x "$INSTALL_DIR/miniconda_installer.sh"
    bash "$INSTALL_DIR/miniconda_installer.sh" -b -p "$CONDA_ROOT_PREFIX"
    rm "$INSTALL_DIR/miniconda_installer.sh"
    echo "  Miniconda version: $("$CONDA_ROOT_PREFIX/bin/conda" --version)"
fi

# ── Step [3/6] Create conda environment ──────────────────────────────────────
echo "[3/6] Creating conda environment (Python 3.11)..."

if [ ! -e "$INSTALL_ENV_DIR" ]; then
    "$CONDA_ROOT_PREFIX/bin/conda" create -y -k --prefix "$INSTALL_ENV_DIR" python=3.11
fi

if [ ! -e "$INSTALL_ENV_DIR/bin/python" ]; then
    echo "ERROR: Conda environment is empty."
    exit 1
fi

# environment isolation
export PYTHONNOUSERSITE=1
unset PYTHONPATH
unset PYTHONHOME

# activate env
source "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"
conda activate "$INSTALL_ENV_DIR"

echo "  Python version: $(python --version)"

# ── Step [4/6] Install PyTorch ───────────────────────────────────────────────
echo "[4/6] Installing PyTorch (CPU + Metal/MPS)..."

python -m pip install --upgrade pip setuptools wheel

echo "  Installing PyTorch for macOS (MPS support)..."
pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0

echo "  PyTorch installed — Metal Performance Shaders (MPS) available on Apple Silicon"

# ── Step [5/6] Install dependencies ──────────────────────────────────────────
echo "[5/6] Installing application dependencies..."

pip install --no-cache-dir --force-reinstall numpy==1.26.4

pip install --no-cache-dir PyQt6==6.9.0 PyQt6-WebEngine==6.9.0 qasync==0.27.1
pip install --no-cache-dir beautifulsoup4 mss
pip install --no-cache-dir ddgs pypdf python-docx
pip install --no-cache-dir discord.py PyNaCl davey
pip install --no-cache-dir pypresence
pip install --no-cache-dir pyautogui playwright && playwright install chromium
pip install --no-cache-dir sentence-transformers==5.1.0
pip install --no-cache-dir openai==1.70.0 mistralai==1.5.0
pip install --no-cache-dir edge-tts==7.2.7 elevenlabs==1.52.0 kokoro==0.9.4
pip install --no-cache-dir qwen-tts
pip install --no-cache-dir faster-whisper
pip install --no-cache-dir curl_cffi
pip install --no-cache-dir translators==6.0.1 psutil==7.0.0 GPUtil==1.4.0
pip install --no-cache-dir sounddevice==0.5.1 soundfile==0.13.1 pydub==0.25.1
pip install --no-cache-dir PyOpenGL==3.1.9 live2d-py==0.5.4
pip install --no-cache-dir scikit-learn==1.4.2 aiohttp==3.11.13 requests==2.32.3
pip install --no-cache-dir tiktoken==0.11.0 PyYAML==6.0.2 pillow==11.3.0 ipython==9.4.0

pip install --no-cache-dir huggingface-hub==0.36.0 hf_transfer==0.1.9
pip install --no-cache-dir transformers==4.57.3

pip install --no-cache-dir av praat-parselmouth scipy==1.13.1
pip install --no-cache-dir python-multipart PyAudio tensorboardX
pip install --no-cache-dir antlr4-python3-runtime==4.9.3 portalocker==3.2.0

echo "  Installing Coqui TTS / XTTSv2 (latest compatible fork)..."
pip install --no-cache-dir coqui-tts[codec]

echo "  Installing RVC support dependencies..."
pip install --no-cache-dir pyworld torchcrepe uvicorn omegaconf==2.3.0

# torchcodec not compatible with torch 2.7.0
echo "  Skipping torchcodec — not compatible with torch 2.7.0"

# ── Step [6/6] Final checks ──────────────────────────────────────────────────
echo "[6/6] Final checks..."

python -m pip check || echo "WARNING: pip check found issues (RVC/Coqui may have minor conflicts)"

echo "  Smoke test (basic imports)..."
python -c "import torch, numpy, transformers, PyQt6; print('  Core imports OK')"
python -c "from TTS.api import TTS; print('  Coqui TTS import OK')" || echo "  WARNING: Coqui TTS import failed — possible version conflict!"

# Check MPS availability on Apple Silicon
python -c "
import torch
if torch.backends.mps.is_available():
    print('  ✓ Metal Performance Shaders (MPS) available — GPU acceleration enabled')
else:
    print('  ⚠ MPS not available — running on CPU only')
" 2>/dev/null || true

echo
echo "=============================================="
echo "  Installation completed successfully!"
echo "  If pip check showed warnings — RVC and Coqui"
echo "  may have minor conflicts (safe to ignore)."
echo "=============================================="
echo
read -r -p "  [1] Start the program  [2] Exit  Enter choice: " POST_CHOICE
if [ "$POST_CHOICE" = "1" ]; then
    bash start_macos.sh
else
    echo "Exiting."
fi
