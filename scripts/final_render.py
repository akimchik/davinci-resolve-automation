import pandas as pd
import subprocess
import json
import os
import glob
import argparse
from datetime import datetime, timedelta

FFMPEG = "/opt/homebrew/bin/ffmpeg"
FFPROBE = "/opt/homebrew/bin/ffprobe"

def run_cmd(cmd):
    print(f"Executing: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
    return result

def get_video_metadata(file_path):
    cmd = [FFPROBE, '-v', 'quiet', '-select_streams', 'v:0', '-show_entries', 
           'format_tags=creation_time:format=duration', '-of', 'json', file_path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(res.stdout)
    tags = data.get('format', {}).get('tags', {})
    duration = float(data.get('format', {}).get('duration', 0))
    
    creation_time = tags.get('creation_time')
    if creation_time:
        # Standard: 2026-06-08T10:00:00.000000Z
        dt = datetime.strptime(creation_time[:19], '%Y-%m-%dT%H:%M:%S')
        return {'start_utc': dt, 'duration': duration}
    return None

def detect_dives(df):
    df = df.sort_values(by='Time')
    df['gap'] = df['Time'].diff() > 300
    df['session_id'] = df['gap'].cumsum()
    dives = []
    for _, group in df.groupby('session_id'):
        if group['Depth'].max() > 1.0:
            dives.append(group)
    return dives

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True, help="Date format YYYY-MM-DD")
    parser.add_argument("--logs_dir", required=True)
    parser.add_argument("--media_dir", required=True)
    parser.add_argument("--output", default="final_dive_movie.mp4")
    parser.add_argument("--mode", choices=['highlights', 'full'], default='highlights')
    args = parser.parse_args()

    # 1. Load Logs
    print("--- Phase 1: Loading Telemetry ---")
    log_files = glob.glob(os.path.join(args.logs_dir, "*.csv"))
    if not log_files:
        print("No logs found.")
        return

    all_data = [pd.read_csv(f) for f in log_files]
    df_all = pd.concat(all_data)
    df_all = df_all[df_all['ISO8601'].str.startswith(args.date)]
    dives = detect_dives(df_all)
    print(f"Found {len(dives)} dives on {args.date}")

    # 2. Discover Media
    print("\n--- Phase 2: Discovering Media ---")
    media_files = glob.glob(os.path.join(args.media_dir, "*.MP4"))
    video_inventory = []
    for f in media_files:
        if "lowres" in f.lower() or "/._" in f: continue
        meta = get_video_metadata(f)
        if meta:
            meta['path'] = f
            video_inventory.append(meta)
    
    video_inventory.sort(key=lambda x: x['start_utc'])
    print(f"Indexed {len(video_inventory)} high-res videos.")

    # 3. Correlation & Highlight Selection
    print("\n--- Phase 3: Correlating and Slicing ---")
    processed_slices = []
    os.makedirs("temp_slices", exist_ok=True)

    for dive_idx, dive in enumerate(dives):
        print(f"Dive #{dive_idx+1}: {len(dive)} points.")
        
        targets = []
        if args.mode == 'highlights':
            # Target: Max Depth
            max_depth_time = dive.loc[dive['Depth'].idxmax(), 'Time']
            targets.append(max_depth_time)
            # Target: First significant descent
            descent = dive[dive['Depth'].diff() > 0.5].head(1)
            if not descent.empty: targets.append(descent.iloc[0]['Time'])
        else:
            # Full movie: process all videos in dive range
            pass

        # Create windows (60s around targets)
        windows = []
        for t in targets:
            windows.append((t - 30, t + 30))

        # Process Windows
        for win_idx, (w_start, w_end) in enumerate(windows):
            # Find videos covering this window
            for vid in video_inventory:
                vid_start_epoch = vid['start_utc'].timestamp()
                vid_end_epoch = vid_start_epoch + vid['duration']
                
                # Check overlap
                overlap_start = max(w_start, vid_start_epoch)
                overlap_end = min(w_end, vid_end_epoch)
                
                if overlap_start < overlap_end:
                    slice_start_in_vid = overlap_start - vid_start_epoch
                    slice_duration = overlap_end - overlap_start
                    
                    output_slice = f"temp_slices/slice_{dive_idx}_{win_idx}.mp4"
                    
                    # Generate Telemetry Filter
                    # For POC: just first point of slice
                    telemetry_row = dive[(dive['Time'] >= overlap_start)].head(1)
                    if telemetry_row.empty: continue
                    
                    label = f"{telemetry_row.iloc[0]['Depth']:.1f}m | {telemetry_row.iloc[0]['Temperature']:.1f}C"
                    
                    cmd = [
                        FFMPEG, '-y', '-ss', str(slice_start_in_vid), '-t', str(slice_duration),
                        '-i', vid['path'],
                        '-vf', f"drawtext=text='{label}':x=w-tw-100:y=100:fontsize=100:fontcolor=white:shadowcolor=black:shadowx=4:shadowy=4",
                        '-c:v', 'h264_videotoolbox', '-b:v', '60M', '-c:a', 'copy',
                        output_slice
                    ]
                    run_cmd(cmd)
                    processed_slices.append(output_slice)

    # 4. Concatenate
    if processed_slices:
        print("\n--- Phase 4: Joining Slices ---")
        concat_file = "temp_slices/list.txt"
        with open(concat_file, 'w') as f:
            for s in processed_slices:
                f.write(f"file '../{s}'\n")
        
        final_cmd = [
            FFMPEG, '-y', '-f', 'concat', '-safe', '0', '-i', concat_file,
            '-c', 'copy', args.output
        ]
        run_cmd(final_cmd)
        print(f"\nSUCCESS! Headless Movie Rendered to: {args.output}")
    else:
        print("\nNo matching slices found to process.")

if __name__ == "__main__":
    main()
