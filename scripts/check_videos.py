import glob
import os
import subprocess
import json
from datetime import datetime, timezone

def get_meta(f):
    import shutil
    ffprobe_cmd = shutil.which("ffprobe") or "/opt/homebrew/bin/ffprobe"
    cmd = [ffprobe_cmd, '-v', 'quiet', '-show_entries', 'format_tags=creation_time:format=duration', '-of', 'json', f]
    res = subprocess.run(cmd, capture_output=True, text=True)
    d = json.loads(res.stdout)
    tags = d.get('format', {}).get('tags', {})
    dur = float(d.get('format', {}).get('duration', 0))
    ts = tags.get('creation_time')
    if ts:
        return {'ts': datetime.strptime(ts[:19], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc).timestamp(), 'dur': dur}
    return None

media_dir = "/Volumes/Untitled/DCIM/100PRLNZ/"
d_start = 1780736530
d_end = 1780740437

videos = []
for f in glob.glob(os.path.join(media_dir, "*.MP4")):
    if "lowres" in f.lower() or "/._" in f: continue
    m = get_meta(f)
    if m:
        m['path'] = os.path.basename(f)
        videos.append(m)

videos.sort(key=lambda x: x['ts'])

print("Files in dive window (1780735930 to 1780741037):")
for v in videos:
    if v['ts'] > 1780700000 and v['ts'] < 1780800000: # Just June 6th roughly
        print(f"{v['path']}: start={v['ts']} ({datetime.fromtimestamp(v['ts'], tz=timezone.utc).strftime('%H:%M:%S')}), dur={v['dur']}, end={v['ts']+v['dur']}")
