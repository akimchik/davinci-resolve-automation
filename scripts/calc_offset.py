import pandas as pd
import glob
import os
import json
import subprocess
from datetime import datetime, timezone

import shutil
FFPROBE = shutil.which("ffprobe") or "/opt/homebrew/bin/ffprobe"

def get_meta(f):
    cmd = [FFPROBE, '-v', 'quiet', '-show_entries', 'format_tags=creation_time:format=duration', '-of', 'json', f]
    res = subprocess.run(cmd, capture_output=True, text=True)
    d = json.loads(res.stdout)
    tags = d.get('format', {}).get('tags', {})
    dur = float(d.get('format', {}).get('duration', 0))
    ts = tags.get('creation_time')
    if ts:
        return {'ts': datetime.strptime(ts[:19], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc).timestamp(), 'dur': dur}
    return None

date = "2026-06-06"
logs_dir = "/Volumes/Untitled/DCIM/LOGS/"
media_dir = "/Volumes/Untitled/DCIM/100PRLNZ/"

# 1. Get CSV dive start
log_files = glob.glob(os.path.join(logs_dir, "*.csv"))
df = pd.concat([pd.read_csv(f) for f in log_files])
df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
df = df.dropna(subset=['Time']).sort_values(by='Time')
df = df[df['ISO8601'].str.startswith(date, na=False)]
df['session'] = (df['Time'].diff() > 7200).cumsum()
dives = [g for _, g in df.groupby('session') if g['Depth'].max() > 1.0]

if not dives:
    print("No dives found")
    exit()

dive_start = dives[0]['Time'].min()
print(f"Dive start epoch (CSV): {dive_start} ({datetime.fromtimestamp(dive_start, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')})")

# 2. Get Video start
videos = []
for f in glob.glob(os.path.join(media_dir, "*.MP4")):
    if "lowres" in f.lower() or "/._" in f: continue
    m = get_meta(f)
    if m: m['path'] = f; videos.append(m)

videos.sort(key=lambda x: x['ts'])
if not videos:
    print("No videos found")
    exit()

vid_start = videos[0]['ts']
print(f"Video start epoch (MP4): {vid_start} ({datetime.fromtimestamp(vid_start, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')})")
print(f"First video: {os.path.basename(videos[0]['path'])}")

diff = dive_start - vid_start
print(f"\nTime difference (CSV - Video): {diff} seconds ({diff/3600:.2f} hours)")
