import pandas as pd
import subprocess
import json
import os
import glob
import argparse
from datetime import datetime, timezone

import shutil
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
FFPROBE = shutil.which("ffprobe") or "/opt/homebrew/bin/ffprobe"

def run_cmd(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Command Error: {' '.join(cmd)}")
        print(f"Stderr: {result.stderr}")
    return result

def get_meta(f):
    try:
        # Extract creation_time, duration, width, height
        cmd = [
            FFPROBE, '-v', 'quiet', '-select_streams', 'v:0',
            '-show_entries', 'format_tags=creation_time:format=duration:stream=width,height',
            '-of', 'json', f
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        d = json.loads(res.stdout)

        fmt = d.get('format', {})
        tags = fmt.get('tags', {})
        dur = float(fmt.get('duration', 0))

        # Get dimensions from streams
        streams = d.get('streams', [])
        width = 0
        if streams:
            width = int(streams[0].get('width', 0))

        ts = tags.get('creation_time')
        if ts and width >= 3000: # Explicitly filter for 4K/high-res (ignore proxy/lowres)
            dt = datetime.strptime(ts[:19], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
            return {'ts': dt.timestamp(), 'dur': dur, 'width': width}
    except Exception as e:
        print(f"Error parsing metadata for {f}: {e}")
    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True)
    parser.add_argument("--logs_dir", required=True)
    parser.add_argument("--media_dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--mode", choices=['highlights', 'full'], default='full')
    parser.add_argument("--offset", type=int, default=None, help="Force manual offset in seconds. If omitted, calculates automatically.")
    parser.add_argument("--dive_list", type=str, default="", help="Comma-separated list of dive IDs to process (e.g., '1,3'). If empty, processes all.")
    parser.add_argument("--gap", type=int, default=7200, help="Seconds of gap to split a new dive session (default: 7200 = 2 hours)")
    args = parser.parse_args()

    # Parse dive list
    target_dives = []
    if args.dive_list:
        target_dives = [int(d.strip()) for d in args.dive_list.split(',')]

    # 1. Load Logs
    log_files = glob.glob(os.path.join(args.logs_dir, "*.csv"))
    if not log_files:
        print(f"Error: No logs found in {args.logs_dir}")
        return
    df = pd.concat([pd.read_csv(f) for f in log_files])

    # Filter by Date FIRST to avoid combining multiple days
    df = df[df['ISO8601'].str.startswith(args.date, na=False)]
    if df.empty:
        print(f"Error: No logs matching date {args.date} found.")
        return

    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
    df = df.dropna(subset=['Time']).sort_values(by='Time')

    # 2. Dive Detection
    # INCREASE GAP to avoid splitting single dives (e.g., battery changes, GPS drops)
    df['session'] = (df['Time'].diff() > args.gap).cumsum()
    dives = [g for _, g in df.groupby('session') if g['Depth'].max() > 1.0]
    print(f"Detected Dives: {len(dives)}")

    if not dives:
        print("Error: No valid dives detected in telemetry.")
        return

    # 3. Media Discovery
    videos = []
    for f in glob.glob(os.path.join(args.media_dir, "*.MP4")):
        m = get_meta(f)
        if m:
            m['path'] = f
            videos.append(m)

    videos.sort(key=lambda x: x['ts'])
    print(f"Indexed High-Res Videos (all): {len(videos)}")

    # Dynamic Offset Calculation
    calc_offset = 0
    if args.offset is not None:
        calc_offset = args.offset
        print(f"Using manual offset: {calc_offset}s")
    elif videos:
        # Calculate drift based on first dive and first video in the directory
        first_dive_start = dives[0]['Time'].min()
        first_video_start = videos[0]['ts']
        calc_offset = first_dive_start - first_video_start
        if abs(calc_offset) > 43200:
            print(f"[Warning] Massive time gap detected ({calc_offset/3600:.1f} hours). Ensure no proxy clips are throwing off the timeline.")
        else:
            print(f"Auto-calculated offset (CSV - Video): {calc_offset:.0f}s")

    # Filter videos to the target date's time window (telemetry bounds ± 12h) using the calculated offset
    day_start = dives[0]['Time'].min() - 43200  # 12h before first dive
    day_end = dives[-1]['Time'].max() + 43200   # 12h after last dive
    videos = [v for v in videos if (v['ts'] + calc_offset) >= day_start and (v['ts'] + calc_offset) <= day_end]
    print(f"Filtered to target date: {len(videos)} video(s)")

    if not videos:
        print("Error: No high-res videos found for the target date.")
        return

    # 4. Correlation & Overlay
    temp_dir = os.path.abspath("temp_slices")
    os.makedirs(temp_dir, exist_ok=True)
    processed = []

    for d_idx, dive in enumerate(dives):
        current_dive_id = d_idx + 1
        if target_dives and current_dive_id not in target_dives:
            continue

        d_start, d_end = dive['Time'].min(), dive['Time'].max()
        print(f"Processing Dive #{current_dive_id}: {d_start} to {d_end}")

        windows = []
        if args.mode == 'highlights':
            # Target: Max Depth
            max_t = dive.loc[dive['Depth'].idxmax(), 'Time']
            windows.append((max_t - 30, max_t + 30))
            # Target: Rapid descent
            descent = dive[dive['Depth'].diff() > 0.5].head(1)
            if not descent.empty:
                desc_t = descent.iloc[0]['Time']
                windows.append((desc_t - 30, desc_t + 30))
        else:
            # Full Dive Mode: Use the entire dive window + padding
            windows.append((d_start - 60, d_end + 60))

        for win_idx, (w_start, w_end) in enumerate(windows):
            for v in videos:
                # APPLY OFFSET to Video Time to match CSV Time
                v_start = v['ts'] + calc_offset
                v_end = v_start + v['dur']

                overlap_start = max(w_start, v_start)
                overlap_end = min(w_end, v_end)

                if overlap_start < overlap_end:
                    # Calculate timestamps relative to the actual video file
                    s_start = overlap_start - v_start
                    s_dur = overlap_end - overlap_start
                    out_s = os.path.join(temp_dir, f"s_{d_idx}_{win_idx}_{os.path.basename(v['path'])}")

                    # Fetch telemetry
                    t_row = dive[(dive['Time'] >= overlap_start)].head(1)
                    if t_row.empty: t_row = dive.tail(1)

                    label = f"{t_row['Depth'].iloc[0]:.1f}m | {t_row['Temperature'].iloc[0]:.1f}C"
                    escaped_label = label.replace(':', '\\:').replace('|', '\\|')

                    # STRICT 4K 60FPS QUALITY ENFORCEMENT
                    cmd = [FFMPEG, '-y', '-ss', str(s_start), '-t', str(s_dur), '-i', v['path'],
                           '-vf', f"drawtext=text='{escaped_label}':x=w-tw-100:y=100:fontsize=80:fontcolor=white:box=1:boxcolor=black@0.5",
                           '-c:v', 'h264_videotoolbox', '-b:v', '80M', '-r', '60', '-c:a', 'aac', '-b:a', '320k', out_s]

                    res = run_cmd(cmd)
                    if res.returncode != 0:
                        print("Falling back to libx264...")
                        # High quality fallback
                        cmd[cmd.index('h264_videotoolbox')] = 'libx264'
                        cmd[cmd.index('-b:v')] = '-crf'
                        cmd[cmd.index('80M')] = '18'
                        cmd.insert(cmd.index('-crf') + 2, '-preset')
                        cmd.insert(cmd.index('-preset') + 1, 'fast')
                        res = run_cmd(cmd)

                    if os.path.exists(out_s):
                        processed.append(out_s)
                        print(f" -> Merged: {os.path.basename(v['path'])} | Extracted {s_dur:.1f}s | Output: {os.path.basename(out_s)}")
                    else:
                        print(f" -> Failed to create slice from {os.path.basename(v['path'])}")

    # 5. Concatenate Results
    if processed:
        list_path = os.path.join(temp_dir, "list.txt")
        with open(list_path, 'w') as f:
            for p in processed:
                f.write(f"file '{p}'\n")

        final_cmd = [FFMPEG, '-y', '-f', 'concat', '-safe', '0', '-i', list_path, '-c', 'copy', os.path.abspath(args.output)]
        res = run_cmd(final_cmd)

        if res.returncode == 0 and os.path.exists(args.output):
            print(f"\nSUCCESS! Rendered: {os.path.abspath(args.output)}")
        else:
            print("\nCRITICAL ERROR: Final concatenation failed.")
    else:
        print("\nError: No correlated clips found. Check your CSV time vs Video creation time (use --offset if needed).")

if __name__ == "__main__":
    main()
