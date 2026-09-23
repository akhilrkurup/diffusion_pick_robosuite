# diffusion_pick_robosuite

Diffusion Policy training/eval pipeline for the robosuite pick-and-place task
(`PickPlaceCan`), built on [robosuite](https://github.com/ARISE-Initiative/robosuite)
+ [robomimic](https://github.com/ARISE-Initiative/robomimic). Everything here is
venv + pip based (no conda), so it can be replicated on a fresh machine with
just this repo and internet access.

robomimic doesn't ship a pretrained checkpoint for this task that works with
current robosuite — their public Can/pick checkpoints are locked to a
deprecated `offline_study` + mujoco-py stack. So this repo trains one from
scratch instead, using robomimic's official Can-PH (Proficient-Human,
200-demo) dataset and its built-in Diffusion Policy implementation.

This repo holds the **scripts and config only**. The dataset (~2GB) and
checkpoints (~1.4GB each) are not committed here — pull/regenerate them with
the scripts below.

## Repo layout

```
setup_env.sh          # creates venv, clones+installs robosuite & robomimic, pins mujoco
download_dataset.sh    # pulls the Can-PH dataset and renders the image observations
eval_agent.sh          # rolls out a checkpoint and saves an mp4
configs/
  diffusion_policy_can_image.json   # training config (rgb: agentview + wrist cam)
```

## Quick start

```bash
git clone https://github.com/akhilrkurup/diffusion_pick_robosuite.git
cd diffusion_pick_robosuite

./setup_env.sh          # sets up venv/, robosuite/, robomimic/ next to this script
./download_dataset.sh   # -> datasets/can/ph/image_v15.hdf5 (~6 min, needs a GPU for rendering)

source venv/bin/activate
python robomimic/robomimic/scripts/train.py --config configs/diffusion_policy_can_image.json
```

Run `train.py` from the repo root — the config's `data`/`output_dir` paths are
relative to the current directory. Checkpoints land in `trained_models/<experiment_name>/<timestamp>/`.

The shipped config trains for 2000 epochs (robomimic's default for this
algorithm), evaluating 20 rollouts every 50 epochs. Edit `train.num_epochs` /
`experiment.rollout` in the config to shorten this for a quick smoke test.

### Picking a GPU

If the machine is shared, set `CUDA_VISIBLE_DEVICES` before training —
`nvidia-smi --query-gpu=index,memory.free --format=csv` shows which one has
headroom. `eval_agent.sh` does this automatically for eval; `train.py` does not.

## Evaluating a checkpoint / saving a video

```bash
./eval_agent.sh trained_models/can_ph_image_dp/<timestamp>/last.pth [n_rollouts] [horizon] [output.mp4]
```

Defaults: 10 rollouts, horizon 400, video written to
`videos/eval_<checkpoint>_<timestamp>.mp4`. Camera(s) recorded default to
`agentview robot0_eye_in_hand`; override with `CAMERA_NAMES="cam1 cam2"`.

## Pulling the dataset later / on another machine

`./download_dataset.sh` does this in one step. What it does under the hood, in
case you need to adapt it (e.g. a different task):

1. Downloads the raw (states-only) demo file from robomimic's HuggingFace repo:
   `https://huggingface.co/datasets/amandlek/robomimic/resolve/main/v1.5/can/ph/demo_v15.hdf5`
2. Replays it through the simulator with offscreen rendering to bake in camera
   observations, via robomimic's `dataset_states_to_obs.py`:
   ```bash
   python robomimic/robomimic/scripts/dataset_states_to_obs.py --done_mode 2 \
     --dataset datasets/can/ph/demo_v15.hdf5 \
     --output_name datasets/can/ph/image_v15.hdf5 \
     --camera_names agentview robot0_eye_in_hand \
     --camera_height 84 --camera_width 84
   ```
   robomimic only pre-renders images for the old v0.1 dataset release, not the
   current v1.5 line, which is why this replay step is needed.

Other tasks (Lift, Square, Transport, Tool Hang) and dataset types (MH,
machine-generated, paired) are listed at
https://robomimic.github.io/docs/datasets/robomimic_v0.1.html — same
two-step process, different `--dataset`/`--camera_names` args (see
`robomimic/robomimic/scripts/extract_obs_from_raw_datasets.sh` for the exact
command used for each one).

## Known gotcha: mujoco version pin

robosuite 1.5.2 crashes on environment reset with mujoco ≥3.4:

```
AssertionError
  ... get_joint_qpos_addr ...
  assert joint_type in (mujoco.mjtJoint.mjJNT_HINGE, mujoco.mjtJoint.mjJNT_SLIDE)
```

`setup_env.sh` pins `mujoco==3.3.0`, which is confirmed working. If you `pip
install -U mujoco` for any reason, this will come back.

Also needed: `pip install robosuite_models` — robosuite no longer bundles
robot XML/mesh assets (Panda, etc.) in the base package.
