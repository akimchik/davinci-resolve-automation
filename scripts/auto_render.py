import subprocess
import re
import os
import argparse

def parse_lua_config(file_path):
    config = {}
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Simple regex extraction
    paths = {
        'logs_dir': r'logs_dir\s*=\s*"([^"]+)"',
        'search_dir': r'search_dir\s*=\s*"([^"]+)"',
    }
    for key, pattern in paths.items():
        match = re.search(pattern, content)
        if match:
            config[key] = match.group(1)
    return config

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True)
    args = parser.parse_args()

    config = parse_lua_config("config.lua")
    if not config.get('logs_dir') or not config.get('search_dir'):
        print("Error: Could not parse paths from config.lua")
        return

    cmd = [
        "python3", "scripts/final_render.py",
        "--date", args.date,
        "--logs_dir", config['logs_dir'],
        "--media_dir", config['search_dir'],
        "--output", f"dive_movie_{args.date}.mp4"
    ]
    
    print(f"Running Headless Render for {args.date}...")
    subprocess.run(cmd)

if __name__ == "__main__":
    main()
