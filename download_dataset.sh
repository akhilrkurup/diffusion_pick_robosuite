#!/bin/bash
# Pull the robomimic Can-PH (pick-and-place) dataset and build the image-observation
# version used by configs/diffusion_policy_can_image.json.
#
# robomimic only hosts states-only "raw" hdf5s for the current v1.5 dataset line
# (their pre-rendered image hdf5s are from the old, deprecated v0.1/offline_study
# release). So this: (1) downloads the raw demo file, (2) replays it through the
# simulator with offscreen rendering to produce agentview + wrist-cam image
# observations. Step 2 takes ~6 minutes on a GPU machine.
#
# Usage: ./download_dataset.sh [install_dir]
#   install_dir defaults to the directory this script lives in.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
INSTALL_DIR="${1:-$SCRIPT_DIR}"

OUT_DIR="$INSTALL_DIR/datasets/can/ph"
mkdir -p "$OUT_DIR"

echo "Downloading raw Can-PH demonstrations (~62MB, 200 trajectories)..."
wget -q --show-progress \
    "https://huggingface.co/datasets/amandlek/robomimic/resolve/main/v1.5/can/ph/demo_v15.hdf5?download=true" \
    -O "$OUT_DIR/demo_v15.hdf5"

echo "Extracting image observations (agentview + robot0_eye_in_hand, 84x84)..."
source "$SCRIPT_DIR/venv/bin/activate"
MUJOCO_GL=egl python "$SCRIPT_DIR/robomimic/robomimic/scripts/dataset_states_to_obs.py" \
    --done_mode 2 \
    --dataset "$OUT_DIR/demo_v15.hdf5" \
    --output_name "$OUT_DIR/image_v15.hdf5" \
    --camera_names agentview robot0_eye_in_hand \
    --camera_height 84 --camera_width 84

echo ""
echo "Done. Image dataset at: $OUT_DIR/image_v15.hdf5"
