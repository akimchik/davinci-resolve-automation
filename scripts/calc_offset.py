import pandas as pd
import glob
import os
import json
import subprocess
import argparse
from datetime import datetime, timezone
import shutil

def get_ffprobe_path():
    return shutil.which("ffprobe") or "/opt/homebrew/bin/ffprobe"

def get_meta(f, ffprobe_path=None):
    if ffprobe_path is None:
        ffprobe_path = get_ffprobe_path()

    cmd = [ffprobe_path, '-v', 'quiet', '-show_entries', 'format_tags=creation_time:format=duration', '-of', 'json', f]
    res = subprocess.run(cmd, capture_output=True, text=True)
    d = json.loads(res.stdout)
    tags = d.get('format', {}).get('tags', {})
    dur = float(d.get('format', {}).get('duration', 0))
    ts = tags.get('creation_time')
    if ts:
        dt = datetime.strptime(ts[:19], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
        return {'ts': dt.timestamp(), 'dur': dur, 'path': f}
    return None

def calculate_time_drift(logs_dir, media_dir, date):
    # 1. Get CSV dive start
    log_files = glob.glob(os.path.join(logs_dir, "*.csv"))
    if not log_files:
        return None, "No logs found in directory"

    df = pd.concat([pd.read_csv(f) for f in log_files])
    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
    df = df.dropna(subset=['Time']).sort_values(by='Time')
    df = df[df['ISO8601'].str.startswith(date, na=False)]

    if df.empty:
        return None, f"No logs matching date {date} found"

    df['session'] = (df['Time'].diff() > 7200).cumsum()
    dives = [g for _, g in df.groupby('session') if g['Depth'].max() > 1.0]

    if not dives:
        return None, "No dives found in logs"

    dive_start = dives[0]['Time'].min()

    # 2. Get Video start
    videos = []
    for f in glob.glob(os.path.join(media_dir, "*.MP4")):
        if "lowres" in f.lower() or "/._" in f:
            continue
        m = get_meta(f)
        if m:
            videos.append(m)

    videos.sort(key=lambda x: x['ts'])
    if not videos:
        return None, "No valid high-res videos found"

    vid_start = videos[0]['ts']
    diff = dive_start - vid_start

    return {
        'dive_start': dive_start,
        'vid_start': vid_start,
        'first_video': videos[0]['path'],
        'diff': diff
    }, None

def main():
    parser = argparse.ArgumentParser(description="Calculate RTC offset between Telemetry CSV and MP4 videos.")
    parser.add_argument("--logs_dir", required=True, help="Directory containing .CSV telemetry logs")
    parser.add_argument("--media_dir", required=True, help="Directory containing .MP4 videos")
    parser.add_argument("--date", required=True, help="Target date in YYYY-MM-DD format")

    args = parser.parse_args()

    result, err = calculate_time_drift(args.logs_dir, args.media_dir, args.date)
    if err:
        print(f"Error: {err}")
        return

    dive_start = result['dive_start']
    vid_start = result['vid_start']

    print(f"Dive start epoch (CSV): {dive_start} ({datetime.fromtimestamp(dive_start, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')})")
    print(f"Video start epoch (MP4): {vid_start} ({datetime.fromtimestamp(vid_start, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')})")
    print(f"First video: {os.path.basename(result['first_video'])}")

    diff = result['diff']
    print(f"\nTime difference (CSV - Video): {diff} seconds ({diff/3600:.2f} hours)")

if __name__ == '__main__':
    main()
