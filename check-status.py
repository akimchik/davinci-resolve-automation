#!/usr/bin/env bash
"exec" ".venv/bin/python3" "$0" "$@"
import os, glob

base = os.getcwd()
tasks = [
    ('🎬 Full Movie', 'temp_slices_full'),
    ('🌟 Highlights', 'temp_slices_highlights')
]

print("================= LIVE RENDER STATUS =================")
active_render = False

for name, folder in tasks:
    dir_path = os.path.join(base, folder)

    if not os.path.exists(dir_path):
        continue

    files = sorted(glob.glob(os.path.join(dir_path, '*.MP4')), key=os.path.getmtime)
    if not files:
        print(f"{name}: [Extracting first clip...]")
        active_render = True
        continue

    active_render = True
    latest = files[-1]
    latest_size = os.path.getsize(latest) / (1024 * 1024)
    done_count = len(files) - 1

    print(f"{name}: {done_count} clips successfully extracted.")
    clip_name = os.path.basename(latest)
    if clip_name.startswith('s_'):
        clip_name = '_'.join(clip_name.split('_')[3:])

    print(f"   ⏳ Currently Encoding: {clip_name} ({latest_size:.1f} MB)")

if not active_render:
    print("No active render detected. (Temp folders are empty or cleaned up).")
print("======================================================")
