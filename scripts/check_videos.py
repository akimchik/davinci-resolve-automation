import glob
import os
import subprocess
import json
import argparse
import shutil
from datetime import datetime, timezone

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
        return {'ts': dt.timestamp(), 'dur': dur, 'path': os.path.basename(f)}
    return None

def analyze_videos_in_window(media_dir, window_start, window_end):
    videos = []
    for f in glob.glob(os.path.join(media_dir, "*.MP4")):
        if "lowres" in f.lower() or "/._" in f:
            continue
        m = get_meta(f)
        if m:
            videos.append(m)

    videos.sort(key=lambda x: x['ts'])

    filtered_videos = []
    for v in videos:
        # Check if the video time overlaps with the target window broadly
        if v['ts'] > window_start and v['ts'] < window_end:
            filtered_videos.append(v)

    return filtered_videos

def main(args=None):
    parser = argparse.ArgumentParser(description="Check video metadata within a specific epoch window.")
    parser.add_argument("--media_dir", required=True, help="Directory containing .MP4 videos")
    parser.add_argument("--start", type=float, required=True, help="Start epoch timestamp")
    parser.add_argument("--end", type=float, required=True, help="End epoch timestamp")

    parsed = parser.parse_args(args)

    videos = analyze_videos_in_window(parsed.media_dir, parsed.start, parsed.end)

    print(f"Files in dive window ({parsed.start} to {parsed.end}):")
    if not videos:
        print("No videos found in the specified window.")
        return 1

    for v in videos:
        start_fmt = datetime.fromtimestamp(v['ts'], tz=timezone.utc).strftime('%H:%M:%S')
        end_epoch = v['ts'] + v['dur']
        print(f"{v['path']}: start={v['ts']} ({start_fmt}), dur={v['dur']:.1f}, end={end_epoch:.1f}")
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
