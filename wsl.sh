#!/bin/bash
#
# Soul of Waifu v2.5.1 — WSL Launcher & Installer
# Runs inside WSL from a Windows-side start_wsl.bat
#

# detect if build-essential is missing or broken
if ! dpkg-query -W -f'${Status}' "build-essential" 2>/dev/null | grep -q "ok installed"; then
echo "build-essential not found or broken!

A C++ compiler is required to build needed Python packages!
To install one, open a WSL terminal and run:

sudo apt-get update
sudo apt-get install build-essential
"
read -r -n1 -p "Continue the installer anyway? [y,n] " EXIT_PROMPT
if ! [[ $EXIT_PROMPT == "Y" || $EXIT_PROMPT == "y" ]]; then exit; fi
fi

# deactivate existing conda envs as needed to avoid conflicts
{ conda deactivate && conda deactivate && conda deactivate; } 2>/dev/null || true

# config — WSL file IO bug workaround: use $HOME for /mnt/* paths
INSTALL_DIR_PREFIX="$HOME/sow-install"
if [[ ! $(realpath "$(pwd)/..") = /mnt/* ]]; then
    INSTALL_DIR_PREFIX="$(realpath "$(pwd)/..")" && INSTALL_INPLACE=1
fi
INSTALL_DIR="$INSTALL_DIR_PREFIX/Soul-of-Waifu-v2.5.1"
CONDA_ROOT_PREFIX="$INSTALL_DIR/installer_files/conda"
INSTALL_ENV_DIR="$INSTALL_DIR/installer_files/env"

# environment isolation
export PYTHONNOUSERSITE=1
unset PYTHONPATH
unset PYTHONHOME
export CUDA_PATH="$INSTALL_ENV_DIR"
export CUDA_HOME="$CUDA_PATH"

# /usr/lib/wsl/lib needs to be added to LD_LIBRARY_PATH to fix years-old bug in WSL
# where GPU drivers aren't linked properly
export LD_LIBRARY_PATH="$INSTALL_ENV_DIR/lib:$INSTALL_ENV_DIR/lib64:/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"

# ── Colors ───────────────────────────────────────────────────────────────────
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[90m"
C_CYAN="\033[38;2;75;184;255m"
C_PURPLE="\033[38;2;167;139;250m"
C_MINT="\033[38;2;74;222;128m"
C_RED="\033[38;2;248;113;113m"
C_GOLD="\033[38;2;251;191;36m"
C_WHITE="\033[97m"

# ── Handle 'cmd' mode (open interactive shell) ───────────────────────────────
if [ "$1" == "cmd" ]; then
    echo "Opening interactive shell in Soul-of-Waifu environment..."
    exec bash --init-file <(echo ". ~/.bashrc 2>/dev/null; conda deactivate 2>/dev/null; cd \"$INSTALL_DIR\" 2>/dev/null || cd ~; source \"$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh\" 2>/dev/null; conda activate \"$INSTALL_ENV_DIR\" 2>/dev/null; echo \"conda env: $(basename $INSTALL_ENV_DIR) | python: \$(python --version 2>/dev/null || echo 'not found')\"")
    exit
fi

if [[ "$INSTALL_DIR" =~ " " ]]; then
    echo "ERROR: This script cannot be run from a path containing spaces."
    exit 1
fi

# ── Create install dir if missing ────────────────────────────────────────────
if [ ! -d "$INSTALL_DIR" ]; then mkdir -p "$INSTALL_DIR" || exit; fi

# ── System dependencies ──────────────────────────────────────────────────────
echo "=============================================="
echo "  Soul of Waifu v2.5.1 Installer (WSL)"
echo "=============================================="
echo

MISSING=0
check_pkg() {
    local pkg="$1"
    if ! dpkg -s "$pkg" &>/dev/null 2>&1; then
        echo "  WARNING: $pkg not found."
        MISSING=1
    fi
}

check_pkg "build-essential"
check_pkg "libasound2-dev"
check_pkg "portaudio19-dev"
check_pkg "ffmpeg"

if [ "$MISSING" -eq 1 ]; then
    echo
    echo "  Missing system packages. Install with:"
    echo "    sudo apt-get update && sudo apt-get install -y build-essential libasound2-dev portaudio19-dev ffmpeg"
    echo
    read -r -n1 -p "  Continue anyway? [y,n] " REPLY
    if ! [[ $REPLY == "Y" || $REPLY == "y" ]]; then exit; fi
fi

# ── Miniconda setup ──────────────────────────────────────────────────────────
MINICONDA_DOWNLOAD_URL="https://repo.anaconda.com/miniconda/Miniconda3-py311_24.11.1-0-Linux-x86_64.sh"
conda_exists="F"

if "$CONDA_ROOT_PREFIX/bin/conda" --version &>/dev/null; then conda_exists="T"; fi

if [ "$conda_exists" == "F" ]; then
    echo "  Downloading Miniconda from $MINICONDA_DOWNLOAD_URL"

    curl -L "$MINICONDA_DOWNLOAD_URL" > "$INSTALL_DIR/miniconda_installer.sh"

    chmod u+x "$INSTALL_DIR/miniconda_installer.sh"
    bash "$INSTALL_DIR/miniconda_installer.sh" -b -p $CONDA_ROOT_PREFIX

    echo "  Miniconda version: $("$CONDA_ROOT_PREFIX/bin/conda" --version)"
    rm "$INSTALL_DIR/miniconda_installer.sh"
fi

# ── Create conda environment ─────────────────────────────────────────────────
if [ ! -e "$INSTALL_ENV_DIR" ]; then
    "$CONDA_ROOT_PREFIX/bin/conda" create -y -k --prefix "$INSTALL_ENV_DIR" python=3.11 git
fi

if [ ! -e "$INSTALL_ENV_DIR/bin/python" ]; then
    echo "ERROR: Conda environment is empty."
    exit 1
fi

# activate env
source "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"
conda activate "$INSTALL_ENV_DIR"

# ── Clone repo if not present ────────────────────────────────────────────────
pushd "$INSTALL_DIR" 1>/dev/null || exit

if [ ! -f "./main.py" ]; then
    echo "  Cloning Soul-of-Waifu repository..."
    git init -b v2.5.1
    git remote add origin https://github.com/CyberSys/Soul-of-Waifu.git
    git fetch origin v2.5.1
    git reset origin/v2.5.1 --hard
    git branch --set-upstream-to=origin/v2.5.1
fi

# ── Install if called with 'wsl.sh install' ──────────────────────────────────
case "$1" in
("install")
    echo "[1/5] Selecting PyTorch backend..."
    echo
    echo "=============================================================="
    echo "  Please select PyTorch installation:"
    echo "  [1] NVIDIA — CUDA 12.1 (torch 2.7.0 + xformers)"
    echo "  [2] NVIDIA — CUDA 12.8+ (torch 2.10.0)"
    echo "  [3] AMD ROCm 6.1 (torch 2.7.0)"
    echo "  [4] Intel Arc GPU (via IPEX)"
    echo "  [5] CPU only"
    echo "=============================================================="
    read -r -p "  Enter choice (1-5): " GPU_CHOICE

    python -m pip install --upgrade pip setuptools wheel

    case "$GPU_CHOICE" in
        1)
            echo "  Installing PyTorch with CUDA 12.1..."
            pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu121
            pip install --no-cache-dir xformers==0.0.30 --index-url https://download.pytorch.org/whl/cu121
            ;;
        2)
            echo "  Installing PyTorch with CUDA 12.8+..."
            pip install --no-cache-dir torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 --index-url https://download.pytorch.org/whl/cu128
            ;;
        3)
            echo "  Installing PyTorch with ROCm 6.1..."
            pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/rocm6.1
            ;;
        4)
            echo "  Installing PyTorch with Intel Arc (IPEX)..."
            pip install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cpu
            pip install --no-cache-dir --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ \
                intel-extension-for-pytorch==2.7.10+xpu oneccl_bind_pt==2.7.0+xpu
            ;;
        5)
            echo "  Installing PyTorch CPU..."
            pip install --no-cache-dir torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0
            ;;
        *)
            echo "Invalid choice."
            exit 1
            ;;
    esac

    echo "[2/5] Installing core dependencies..."
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

    echo "  Installing Coqui TTS / XTTSv2..."
    pip install --no-cache-dir coqui-tts[codec]

    echo "  Installing RVC support dependencies..."
    pip install --no-cache-dir pyworld torchcrepe uvicorn omegaconf==2.3.0

    # torchcodec: not compatible with torch 2.7.x or Intel Arc
    TORCH_VER=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "")
    if [[ "$TORCH_VER" == 2.7.* ]] || [[ "$GPU_CHOICE" == "4" ]]; then
        echo "  Skipping torchcodec — not compatible with this configuration"
    else
        pip install --no-cache-dir --force-reinstall torchcodec==0.10.0
    fi

    echo "[3/5] Final checks..."
    python -m pip check || echo "WARNING: pip check found issues"

    echo "[4/5] Smoke test..."
    python -c "import torch, numpy, transformers, PyQt6; print('  Core imports OK')"
    python -c "from TTS.api import TTS; print('  Coqui TTS import OK')" || echo "  WARNING: Coqui TTS import failed!"

    echo "[5/5] Installation complete!"
    echo
    echo "=============================================="
    echo "  Installation completed successfully!"
    echo "=============================================="
    ;;
(*)
    # default: just launch the app
    ;;
esac

# ── Launch the application ───────────────────────────────────────────────────
if [ "$1" != "install" ]; then
    clear
    echo
    echo -e "${C_CYAN}  ███████╗ ██████╗ ██╗   ██╗██╗        ██████╗ ███████╗    ██╗    ██╗ █████╗ ██╗███████╗██╗   ██╗${C_RESET}"
    echo -e "${C_CYAN}  ██╔════╝██╔═══██╗██║   ██║██║       ██╔═══██╗██╔════╝    ██║    ██║██╔══██╗██║██╔════╝██║   ██║${C_RESET}"
    echo -e "${C_CYAN}  ███████╗██║   ██║██║   ██║██║       ██║   ██║█████╗      ██║ █╗ ██║███████║██║█████╗  ██║   ██║${C_RESET}"
    echo -e "${C_CYAN}  ╚════██║██║   ██║██║   ██║██║       ██║   ██║██╔══╝      ██║███╗██║██╔══██║██║██╔══╝  ██║   ██║${C_RESET}"
    echo -e "${C_CYAN}  ███████║╚██████╔╝╚██████╔╝███████╗  ╚██████╔╝██║         ╚███╔███╔╝██║  ██║██║██║     ╚██████╔╝${C_RESET}"
    echo -e "${C_DIM}  ╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝   ╚═════╝ ╚═╝          ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝╚═╝      ╚═════╝ ${C_RESET}"
    echo
    echo -e "${C_WHITE}   Soul of Waifu ${C_PURPLE}v2.5.1${C_WHITE} — Soul Continuum ${C_RESET}"
    echo -e "${C_DIM}  ──────────────────────────────────────────────────────────────────────────────────────────${C_RESET}"
    echo
    echo -e "  ${C_MINT}✓${C_RESET} Environment loaded: ${C_PURPLE}$(python --version) / $(python -c 'import torch; print(f"PyTorch {torch.__version__}")')${C_RESET}"
    GPU_INFO=$(python -c "
import torch
if torch.cuda.is_available():
    print(f'CUDA {torch.version.cuda} — {torch.cuda.get_device_name(0)}')
elif hasattr(torch, 'xpu') and torch.xpu.is_available():
    print(f'Intel XPU — {torch.xpu.get_device_name(0)}')
elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
    print('Metal/MPS')
else:
    print('CPU only')
" 2>/dev/null || echo "unknown")
    echo -e "  ${C_DIM}GPU:${C_RESET} ${C_DIM}${GPU_INFO}${C_RESET}"
    echo
    echo -e "${C_DIM}  ──────────────────────────────────────────────────────────────────────────────────────────${C_RESET}"
    echo

    python main.py
    EXIT_CODE=$?

    if [ "$EXIT_CODE" -ne 0 ]; then
        echo
        echo -e "${C_RED}   ✕ APPLICATION TERMINATED WITH CODE: ${EXIT_CODE}${C_RESET}"
        echo -e "    ${C_CYAN}➜ Check logs/ for details${C_RESET}"
        echo
    fi
fi

popd 1>/dev/null || true
exit "${EXIT_CODE:-0}"
