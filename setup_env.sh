#!/bin/bash
# Reproducible venv-based setup for robosuite + robomimic (PickPlaceCan, image-based
# Diffusion Policy). No conda required. Tested on Ubuntu w/ Python 3.10, CUDA 13 driver.
#
# Usage: ./setup_env.sh [install_dir]
#   install_dir defaults to the current directory.
set -euo pipefail

INSTALL_DIR="${1:-$(pwd)}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Re-runnable: if a clone was interrupted partway (Ctrl-C, dropped network),
# the target dir exists but has no .git -> wipe it and clone again. If it has
# .git, assume a prior run finished the clone and skip re-cloning.
clone_if_needed() {
    local url="$1" dir="$2"
    if [ -d "$dir/.git" ]; then
        echo "$dir already cloned, skipping."
    else
        rm -rf "$dir"
        git clone "$url" "$dir"
    fi
}

# 1. venv (use python3.10 if available; otherwise fall back to python3)
#    Safe to rerun: `python -m venv` on an existing venv dir just refreshes it.
PYBIN="$(command -v python3.10 || command -v python3)"
echo "Using $PYBIN"
"$PYBIN" -m venv venv
source venv/bin/activate
pip install --upgrade pip

# 2. PyTorch (pick the CUDA build matching your driver; see
#    https://pytorch.org/get-started/locally/ if this default doesn't match)
pip install torch torchvision

# 3. Fresh robosuite from source (pinned to the release this was validated against)
clone_if_needed https://github.com/ARISE-Initiative/robosuite.git robosuite
(cd robosuite && git checkout v1.5.2 && pip install -e .)

# 4. Fresh robomimic from source
clone_if_needed https://github.com/ARISE-Initiative/robomimic.git robomimic
(cd robomimic && pip install -e .)

# 5. Robot model assets (Panda etc.) - required, robosuite no longer bundles these
pip install robosuite_models

# 6. IMPORTANT: pin mujoco to 3.3.0. robosuite 1.5.2 + mujoco>=3.4 hits
#    "AssertionError" in get_joint_qpos_addr on env reset (joint_type binding
#    mismatch). 3.3.0 is the newest version confirmed working.
pip install "mujoco==3.3.0"

echo ""
echo "Setup complete. Verify with:"
echo "  source $INSTALL_DIR/venv/bin/activate"
echo "  MUJOCO_GL=egl python -c \"import robosuite as suite; suite.make('PickPlaceCan', robots='Panda', has_renderer=False, has_offscreen_renderer=True, use_camera_obs=True, camera_names='agentview').reset(); print('OK')\""
