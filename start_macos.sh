#!/usr/bin/env bash
#
# Soul of Waifu v2.5.1 — macOS Launcher
# Usage: bash start_macos.sh
#

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ "$(pwd)" =~ " " ]]; then
    echo "ERROR: This script cannot be run from a path containing spaces."
    exit 1
fi

# deactivate existing conda envs as needed to avoid conflicts
{ conda deactivate && conda deactivate && conda deactivate; } 2>/dev/null || true

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

# ── [1/4] Workspace ──────────────────────────────────────────────────────────
echo -e "  ${C_CYAN}[${C_WHITE}1/4${C_CYAN}]${C_RESET} ${C_WHITE}Initializing workspace...${C_RESET}"
echo -e "        ${C_DIM}Working Directory:${C_RESET} ${C_DIM}$(pwd)${C_RESET}"
echo -e "        ${C_MINT}✓${C_RESET} Directory confirmed."
echo

# ── [2/4] FFmpeg ─────────────────────────────────────────────────────────────
echo -e "  ${C_CYAN}[${C_WHITE}2/4${C_CYAN}]${C_RESET} ${C_WHITE}Configuring FFmpeg media pipelines...${C_RESET}"

if command -v ffmpeg &>/dev/null; then
    echo -e "        ${C_MINT}✓${C_RESET} FFmpeg found in PATH: $(command -v ffmpeg)"
elif [ -x "app/ffmpeg/bin/ffmpeg" ]; then
    export PATH="$(pwd)/app/ffmpeg/bin:$PATH"
    echo -e "        ${C_MINT}✓${C_RESET} FFmpeg found in app/ffmpeg/bin/"
else
    echo -e "        ${C_RED}✕ CRITICAL ERROR: FFmpeg not found!${C_RESET}"
    echo
    echo -e "        ${C_GOLD}Please install FFmpeg:${C_RESET}"
    echo -e "          Homebrew: ${C_WHITE}brew install ffmpeg${C_RESET}"
    echo
    exit 1
fi
echo

# ── [3/4] Conda environment ──────────────────────────────────────────────────
echo -e "  ${C_CYAN}[${C_WHITE}3/4${C_CYAN}]${C_RESET} ${C_WHITE}Mounting isolated runtime environment...${C_RESET}"

INSTALL_DIR="$(pwd)/installer_files"
CONDA_ROOT_PREFIX="$(pwd)/installer_files/conda"
INSTALL_ENV_DIR="$(pwd)/installer_files/env"

if [ ! -e "$INSTALL_ENV_DIR/bin/python" ]; then
    echo -e "        ${C_RED}✕ Conda environment not found!${C_RESET}"
    echo -e "        ${C_GOLD}Please run installer_macos.sh first:${C_RESET} ${C_WHITE}bash installer_macos.sh${C_RESET}"
    echo
    exit 1
fi

# environment isolation
export PYTHONNOUSERSITE=1
unset PYTHONPATH
unset PYTHONHOME

source "$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh"
conda activate "$INSTALL_ENV_DIR"

# Check MPS availability
MPS_STATUS=$(python -c "
import torch
if torch.backends.mps.is_available():
    print('Metal/MPS ✓')
else:
    print('CPU only')
" 2>/dev/null || echo "unknown")

echo -e "        ${C_MINT}✓${C_RESET} Environment loaded: ${C_PURPLE}$(python --version) / PyTorch $(python -c 'import torch; print(torch.__version__)') / ${MPS_STATUS}${C_RESET}"
echo

# ── [4/4] Launch ─────────────────────────────────────────────────────────────
echo -e "  ${C_CYAN}[${C_WHITE}4/4${C_CYAN}]${C_RESET} ${C_WHITE}Starting Soul of Waifu Core Runtime...${C_RESET}"
echo -e "        ${C_DIM}Launching interface (main.py)...${C_RESET}"
echo
echo -e "${C_DIM}  ──────────────────────────────────────────────────────────────────────────────────────────${C_RESET}"
echo -e "${C_MINT}   ⚡ App running. Logs streamed to /logs directory.${C_RESET}"
echo

python main.py
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    echo
    echo -e "${C_DIM}  ──────────────────────────────────────────────────────────────────────────────────────────${C_RESET}"
    echo -e "${C_MINT}   ✓ Application closed gracefully. Memory cache and sessions saved.${C_RESET}"
    echo -e "${C_PURPLE}   ✨ Thank you for using Soul of Waifu. See you next time.${C_RESET}"
    echo
elif [ "$EXIT_CODE" -eq 130 ]; then
    # SIGINT (Ctrl+C)
    echo
    echo -e "${C_DIM}  ──────────────────────────────────────────────────────────────────────────────────────────${C_RESET}"
    echo -e "${C_MINT}   ✓ Application interrupted (Ctrl+C).${C_RESET}"
    echo
else
    echo
    echo -e "${C_RED}  ════════════════════════════════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_RED}   ✕ APPLICATION TERMINATED WITH CODE: ${EXIT_CODE}${C_RESET}"
    echo -e "${C_RED}  ════════════════════════════════════════════════════════════════════════════════════════════${C_RESET}"
    echo
    echo -e "    ${C_GOLD}Possible causes:${C_RESET}"
    echo -e "     • Missing dependency or corrupted Python package in virtualenv."
    echo -e "     • Metal/MPS backend issue on Apple Silicon."
    echo -e "     • Permission restrictions."
    echo
    echo -e "    ${C_CYAN}➜ Check detailed crash traceback in:${C_RESET} ${C_WHITE}logs/${C_RESET}"
    echo
fi

exit "$EXIT_CODE"
