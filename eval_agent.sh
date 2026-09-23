#!/bin/bash
# Roll out a trained robomimic checkpoint and save a video of the episodes.
#
# Usage:
#   ./eval_agent.sh <checkpoint.pth> [n_rollouts] [horizon] [output_video.mp4]
#
# Examples:
#   ./eval_agent.sh trained_models/can_ph_image_dp/20260923192330/last.pth
#   ./eval_agent.sh trained_models/can_ph_image_dp/20260923192330/last.pth 10 400 videos/eval.mp4
#
# Notes:
# - Camera(s) recorded default to agentview + robot0_eye_in_hand (what the Can-PH
#   image dataset was built with). Override by exporting CAMERA_NAMES="cam1 cam2".
# - Picks whichever GPU currently has the most free memory, so it doesn't collide
#   with other jobs on a shared machine. Override by exporting CUDA_VISIBLE_DEVICES.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

CKPT="${1:?usage: eval_agent.sh <checkpoint.pth> [n_rollouts] [horizon] [output_video.mp4]}"
N_ROLLOUTS="${2:-10}"
HORIZON="${3:-400}"
VIDEO_PATH="${4:-$SCRIPT_DIR/videos/eval_$(basename "$CKPT" .pth)_$(date +%Y%m%d_%H%M%S).mp4}"
CAMERA_NAMES="${CAMERA_NAMES:-agentview robot0_eye_in_hand}"

mkdir -p "$(dirname "$VIDEO_PATH")"

source "$SCRIPT_DIR/venv/bin/activate"

if [ -z "${CUDA_VISIBLE_DEVICES:-}" ] && command -v nvidia-smi >/dev/null 2>&1; then
    export CUDA_VISIBLE_DEVICES="$(nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits \
        | sort -t',' -k2 -n -r | head -1 | cut -d',' -f1 | tr -d ' ')"
    echo "Auto-selected GPU $CUDA_VISIBLE_DEVICES (most free memory)"
fi

export MUJOCO_GL=egl

python "$SCRIPT_DIR/robomimic/robomimic/scripts/run_trained_agent.py" \
    --agent "$CKPT" \
    --n_rollouts "$N_ROLLOUTS" \
    --horizon "$HORIZON" \
    --video_path "$VIDEO_PATH" \
    --camera_names $CAMERA_NAMES \
    --seed 0

echo ""
echo "Video saved to: $VIDEO_PATH"
