import pandas as pd
import subprocess
import os
import glob
import argparse
from datetime import datetime, timezone
import json

FFMPEG = "/opt/homebrew/bin/ffmpeg"
FFPROBE = "/opt/homebrew/bin/ffprobe"

def get_meta(f):
    try:
        cmd = [FFPROBE, '-v', 'quiet', '-show_entries', 'format_tags=creation_time:format=duration', '-of', 'json', f]
        res = subprocess.run(cmd, capture_output=True, text=True)
        d = json.loads(res.stdout)
        tags = d.get('format', {}).get('tags', {})
        dur = float(d.get('format', {}).get('duration', 0))
        ts = tags.get('creation_time')
        if ts:
            return {'ts': datetime.strptime(ts[:19], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc).timestamp(), 'dur': dur}
    except: pass
    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True)
    parser.add_argument("--logs_dir", required=True)
    parser.add_argument("--media_dir", required=True)
    parser.add_argument("--output", default="dive_movie.mp4")
    parser.add_argument("--mode", choices=['highlights', 'full'], default='highlights')
    args = parser.parse_args()

    logs = glob.glob(os.path.join(args.logs_dir, "*.csv"))
    if not logs: print("Error: No logs"); return
        
    df = pd.concat([pd.read_csv(f) for f in logs])
    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
    df = df.dropna(subset=['Time']).sort_values(by='Time')
    
    df['session'] = (df['Time'].diff() > 300).cumsum()
    dives = [g for _, g in df.groupby('session') if g['Depth'].max() > 1.0]
    print(f"Detected Dives: {len(dives)}")

    videos = []
    for f in glob.glob(os.path.join(args.media_dir, "*.MP4")):
        if "lowres" in f.lower(): continue
        m = get_meta(f)
        if m: m['path'] = f; videos.append(m)
    print(f"Indexed Videos: {len(videos)}")

    os.makedirs("temp_slices", exist_ok=True)
    processed = []

    for d_idx, dive in enumerate(dives):
        d_start, d_end = dive['Time'].min(), dive['Time'].max()
        
        targets = []
        if args.mode == 'highlights':
            targets.append(dive.loc[dive['Depth'].idxmax(), 'Time'])
            descent = dive[dive['Depth'].diff() > 0.5].head(1)
            if not descent.empty: targets.append(descent.iloc[0]['Time'])
        else:
            targets.append(d_start + (d_end - d_start)/2)

        windows = []
        for t in targets:
            if args.mode == 'highlights':
                windows.append((t - 30, t + 30))
            else:
                windows.append((d_start - 3600, d_end + 3600))

        for win_idx, (w_start, w_end) in enumerate(windows):
            for v in videos:
                v_start = v['ts']
                v_end = v_start + v['dur']
                overlap_start = max(w_start, v_start)
                overlap_end = min(w_end, v_end)
                
                if overlap_start < overlap_end:
                    s_start = overlap_start - v_start
                    s_dur = overlap_end - overlap_start
                    out_s = os.path.abspath(f"temp_slices/s_{d_idx}_{win_idx}_{os.path.basename(v['path'])}.mp4")
                    
                    t = dive[(dive['Time'] >= overlap_start)].head(1)
                    if t.empty: t = dive.head(1)
                    label = f"{t['Depth'].iloc[0]:.1f}m | {t['Temperature'].iloc[0]:.1f}C"
                    
                    cmd = [FFMPEG, '-y', '-ss', str(s_start), '-t', str(s_dur), '-i', v['path'], 
                           '-vf', f"drawtext=text='{label}':x=w-tw-100:y=100:fontsize=80:fontcolor=white:box=1:boxcolor=black@0.5",
                           '-c:v', 'h264_videotoolbox', '-b:v', '60M', '-c:a', 'copy', out_s]
                    
                    res = subprocess.run(cmd, capture_output=True)
                    if res.returncode != 0:
                        cmd[cmd.index('h264_videotoolbox')] = 'libx264'
                        subprocess.run(cmd, capture_output=True)
                    
                    processed.append(out_s)

    if processed:
        list_path = os.path.abspath("temp_slices/list.txt")
        with open(list_path, 'w') as f:
            for p in processed: f.write(f"file '{p}'\n")
        
        subprocess.run([FFMPEG, '-y', '-f', 'concat', '-safe', '0', '-i', list_path, '-c', 'copy', os.path.abspath(args.output)], capture_output=True)
        print(f"SUCCESS! Rendered: {os.path.abspath(args.output)}")
    else:
        print("Error: No correlated clips found.")

if __name__ == "__main__":
    main()
