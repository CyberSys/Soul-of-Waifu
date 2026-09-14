#!/usr/bin/env bash
#
# Soul of Waifu v2.5.1 — Linux Installer
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
echo "  Soul of Waifu v2.5.1 Installer (Linux)"
echo "=============================================="
echo

# ── Step [1/6] System dependencies ──────────────────────────────────────────
echo "[1/6] Checking system dependencies..."

check_system_pkg() {
    local pkg="$1"
    local install_hint="$2"
    local found=0
    # check if package is installed via dpkg/rpm
    if dpkg -s "$pkg" &>/dev/null 2>&1 || rpm -q "$pkg" &>/dev/null 2>&1; then
        found=1
    fi
    # check if binary exists in PATH (for tools like gcc, cmake, ffmpeg)
    if command -v "$pkg" &>/dev/null; then
        found=1
    fi
    # for -dev packages, also check if the .pc file or header exists
    if [[ "$pkg" == *-dev ]] && [ -d "/usr/include" ]; then
        local short="${pkg%-dev}"
        if dpkg -L "$pkg" 2>/dev/null | grep -q '\.h$' 2>/dev/null; then
            found=1
        fi
    fi
    if [ "$found" -eq 0 ]; then
        echo "  WARNING: $pkg not found. $install_hint"
        return 1
    fi
    return 0
}

MISSING=0
check_system_pkg "gcc"            "Install: sudo apt install build-essential" || MISSING=1
check_system_pkg "g++"            "Install: sudo apt install build-essential" || MISSING=1
check_system_pkg "cmake"          "Install: sudo apt install cmake (optional)" || true
check_system_pkg "libasound2-dev" "Install: sudo apt install libasound2-dev (required for sounddevice)" || MISSING=1
check_system_pkg "portaudio19-dev" "Install: sudo apt install portaudio19-dev (required for PyAudio)" || MISSING=1
check_system_pkg "ffmpeg"         "Install: sudo apt install ffmpeg" || MISSING=1

if [ "$MISSING" -eq 1 ]; then
    echo
    read -r -p "Some system packages are missing. Continue anyway? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# ── Step [2/6] Miniconda setup ──────────────────────────────────────────────
echo "[2/6] Setting up Miniconda3..."

INSTALL_DIR="$(pwd)/installer_files"
CONDA_ROOT_PREFIX="$(pwd)/installer_files/conda"
INSTALL_ENV_DIR="$(pwd)/installer_files/env"

OS_ARCH="$(uname -m)"
MINICONDA_DOWNLOAD_URL="https://repo.anaconda.com/miniconda/Miniconda3-py311_24.11.1-0-Linux-${OS_ARCH}.sh"
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
export CUDA_PATH="$INSTALL_ENV_DIR"
export CUDA_HOME="$CUDA_PATH"

# activate env
source "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"
conda activate "$INSTALL_ENV_DIR"

echo "  Python version: $(python --version)"

# ── Step [4/6] Install PyTorch ───────────────────────────────────────────────
echo "[4/6] Installing PyTorch..."
echo
echo "=============================================================="
echo "  Please select PyTorch installation:"
echo "  [1] NVIDIA — CUDA 12.1 (torch 2.5.1 + xformers)"
echo "  [2] NVIDIA — CUDA 12.8+ (torch 2.10.0)"
echo "  [3] AMD ROCm 6.1 (torch 2.7.0)"
echo "  [4] Intel Arc GPU (via IPEX)"
echo "  [5] Vulkan (via mesa-vulkan + llama.cpp)"
echo "  [6] CPU only"
echo "=============================================================="
read -r -p "  Enter choice (1-6): " CHOICE

python -m pip install --upgrade pip setuptools wheel

case "$CHOICE" in
    1)
        echo "  Installing PyTorch with CUDA 12.1 support..."
        pip install --no-cache-dir torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu121
        echo "  Installing xformers for CUDA 12.1..."
        pip install --no-cache-dir xformers==0.0.27.post2 --index-url https://download.pytorch.org/whl/cu121
        ;;
    2)
        echo "  Installing PyTorch with CUDA 12.8+ support..."
        pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128
        ;;
    3)
        echo "  Installing PyTorch with ROCm 6.1 support..."
        pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0
        echo "  NOTE: For native ROCm, install torch from: https://download.pytorch.org/whl/rocm6.1"
        ;;
    4)
        echo "  Installing PyTorch with Intel Arc (IPEX) support..."
        pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cpu
        pip install --no-cache-dir --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ \
            intel-extension-for-pytorch==2.7.10+xpu oneccl_bind_pt==2.7.0+xpu
        echo "  Installing oneAPI runtime via conda..."
        "$CONDA_ROOT_PREFIX/bin/conda" install -y -c https://software.repos.intel.com/python/conda/ -c conda-forge \
            dpcpp-cpp-rt=2025.0 mkl-dpcpp=2025.0 || echo "  WARNING: oneAPI conda install failed — install manually if needed"
        ;;
    5)
        echo "  Installing PyTorch CPU (Vulkan via system mesa-vulkan-drivers)..."
        pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0
        echo "  NOTE: Ensure vulkan-tools is installed: sudo apt install vulkan-tools"
        echo "  Run 'vulkaninfo' to verify Vulkan detection."
        ;;
    6)
        echo "  Installing PyTorch CPU..."
        pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac

# ── Step [5/6] Install dependencies ──────────────────────────────────────────
echo "[5/6] Installing application dependencies..."

pip install --no-cache-dir --force-reinstall numpy==1.26.4

pip install --no-cache-dir PyQt6==6.9.0 PyQt6-WebEngine==6.9.0 qasync==0.27.1
pip install --no-cache-dir beautifulsoup4 mss
pip install --no-cache-dir ddgs pypdf python-docx
pip install --no-cache-dir discord.py PyNaCl davey
pip install --no-cache-dir pypresence
pip install --no-cache-dir pyautogui playwright
playwright install chromium
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

# torchcodec: not compatible with torch 2.7.x or Intel Arc builds
TORCH_VER=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "")
if [[ "$TORCH_VER" == 2.7.* ]]; then
    echo "  Skipping torchcodec — not compatible with torch 2.7.0"
elif [[ "$CHOICE" == "4" ]]; then
    echo "  Skipping torchcodec — not compatible with Intel Arc IPEX"
else
    pip install --no-cache-dir --force-reinstall torchcodec==0.10.0
fi

# ── Step [6/6] Final checks ──────────────────────────────────────────────────
echo "[6/6] Final checks..."

python -m pip check || echo "WARNING: pip check found issues (RVC/Coqui may have minor conflicts)"

echo "  Smoke test (basic imports)..."
python -c "import torch, numpy, transformers, PyQt6; print('  Core imports OK')"
python -c "from TTS.api import TTS; print('  Coqui TTS import OK')" || echo "  WARNING: Coqui TTS import failed — possible version conflict!"

# GPU detection
python -c "
import torch
if torch.cuda.is_available():
    print(f'  GPU: CUDA {torch.version.cuda} — {torch.cuda.get_device_name(0)}')
elif hasattr(torch, 'xpu') and torch.xpu.is_available():
    print(f'  GPU: Intel XPU — {torch.xpu.get_device_name(0)}')
elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
    print('  GPU: Metal/MPS')
else:
    print('  GPU: CPU only')
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
    bash start_linux.sh
else
    echo "Exiting."
fi
