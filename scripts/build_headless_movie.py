import pandas as pd
import subprocess
import json
import os
import glob
import argparse
from datetime import datetime, timezone

import shutil
FFMPEG = shutil.which("ffmpeg")
FFPROBE = shutil.which("ffprobe")
if not FFMPEG or not FFPROBE:
    raise FileNotFoundError("FFmpeg and FFprobe must be installed and in PATH.")

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

def format_srt_time(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds - int(seconds)) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

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
    else:
        print(f"Using default zero-offset (Camera RTC Sync). If out of sync, pass --offset.")

    # Filter videos to the target date's time window (telemetry bounds ± 12h) using the calculated offset
    day_start = dives[0]['Time'].min() - 43200  # 12h before first dive
    day_end = dives[-1]['Time'].max() + 43200   # 12h after last dive
    videos = [v for v in videos if (v['ts'] + calc_offset) >= day_start and (v['ts'] + calc_offset) <= day_end]
    print(f"Filtered to target date: {len(videos)} video(s)")

    if not videos:
        print("Error: No high-res videos found for the target date.")
        return

    # 4. Correlation & Overlay
    temp_dir = os.path.abspath(f"temp_slices_{args.mode}")
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
            # 5-Chapter Smart Highlights (~3.5-4 min representative dive summary)
            # 1. Entry / Initial Drop (40s)
            entry = dive[dive['Depth'] >= 2.0].head(1)
            if not entry.empty:
                t = entry.iloc[0]['Time']
                windows.append((t - 10, t + 30))
            # 2. Fastest Descent (45s)
            dive_diff = dive['Depth'].diff()
            if not dive_diff.empty:
                t = dive.iloc[dive_diff.argmax()]['Time']
                windows.append((t - 15, t + 30))
            # 3. Mid-Dive Exploration (50s)
            mid_time = d_start + (d_end - d_start) * 0.45
            mid_row = dive.iloc[(dive['Time'] - mid_time).abs().argsort()[:1]]
            if not mid_row.empty:
                t = mid_row.iloc[0]['Time']
                windows.append((t - 25, t + 25))
            # 4. Max Depth Apex (60s)
            max_t = dive.iloc[dive['Depth'].argmax()]['Time']
            windows.append((max_t - 30, max_t + 30))
            # 5. Ascent / Safety Stop Phase (40s)
            ascent = dive[(dive['Depth'] <= 5.0) & (dive['Time'] > d_start + (d_end - d_start) * 0.75)].head(1)
            if not ascent.empty:
                t = ascent.iloc[0]['Time']
                windows.append((t - 15, t + 25))
            # Guaranteed chronological order
            windows.sort(key=lambda x: x[0])
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

                    # Generate dynamic SRT
                    srt_path = os.path.join(temp_dir, f"sub_{d_idx}_{win_idx}_{os.path.basename(v['path'])}.srt")
                    slice_df = dive[(dive['Time'] >= overlap_start) & (dive['Time'] <= overlap_end)]

                    with open(srt_path, 'w') as f_srt:
                        for idx_s in range(len(slice_df)):
                            row = slice_df.iloc[idx_s]
                            rel_t = row['Time'] - overlap_start
                            if rel_t < 0: rel_t = 0

                            if idx_s + 1 < len(slice_df):
                                next_rel_t = slice_df.iloc[idx_s+1]['Time'] - overlap_start
                                end_t = min(next_rel_t, s_dur)
                            else:
                                end_t = min(rel_t + 1.0, s_dur)

                            f_srt.write(f"{idx_s+1}\n")
                            f_srt.write(f"{format_srt_time(rel_t)} --> {format_srt_time(end_t)}\n")
                            f_srt.write(f"Depth: {row['Depth']}m | Temp: {row['Temperature']}C\n\n")

                    escaped_srt = srt_path.replace(':', '\\\\:')

                    # STRICT 4K 60FPS QUALITY ENFORCEMENT
                    cmd = [FFMPEG, '-y', '-ss', str(s_start), '-t', str(s_dur), '-i', v['path'],
                           '-vf', f"subtitles='{escaped_srt}':force_style='FontSize=5,Alignment=9,BorderStyle=3,Outline=1,Shadow=0,MarginV=15,MarginR=15,FontName=Arial'",
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
            import shutil
            try:
                shutil.rmtree(temp_dir)
                print(f"Cleaned up temporary files in: {temp_dir}")
            except Exception as e:
                print(f"Warning: Failed to clean up {temp_dir}: {e}")
        else:
            print("\nCRITICAL ERROR: Final concatenation failed.")
    else:
        print("\nError: No correlated clips found. Check your CSV time vs Video creation time (use --offset if needed).")

if __name__ == "__main__":
    main()
