#!/usr/bin/env bash
#
# Soul of Waifu v2.5.1 — macOS Shell
# Opens interactive bash with conda environment activated
# Usage: bash cmd_macos.sh
#

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ "$(pwd)" =~ " " ]]; then echo "This script cannot be run from a path containing spaces." && exit 1; fi

# deactivate existing conda envs as needed to avoid conflicts
{ conda deactivate && conda deactivate && conda deactivate; } 2>/dev/null || true

# config
CONDA_ROOT_PREFIX="$(pwd)/installer_files/conda"
INSTALL_ENV_DIR="$(pwd)/installer_files/env"

if [ ! -e "$INSTALL_ENV_DIR/bin/python" ]; then
    echo "Conda environment not found!"
    echo "Please run installer_macos.sh first: bash installer_macos.sh"
    exit 1
fi

# environment isolation
export PYTHONNOUSERSITE=1
unset PYTHONPATH
unset PYTHONHOME

# activate env and open interactive shell
bash --init-file <(echo "source \"$CONDA_ROOT_PREFIX/etc/profile.d/conda.sh\" && conda activate \"$INSTALL_ENV_DIR\" && echo 'Soul of Waifu env activated | Python:' \$(python --version 2>/dev/null) '| PyTorch:' \$(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'N/A') '| MPS:' \$(python -c 'import torch; print(\"on\" if torch.backends.mps.is_available() else \"off\")' 2>/dev/null || echo 'unknown')")
