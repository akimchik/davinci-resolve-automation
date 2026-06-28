import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os
import sys
import glob
import argparse

def generate_telemetry(logs_dir, target_date, output_png, output_lua, dive_id=None, list_only=False):
    print(f"Generating telemetry for {target_date}...")

    log_files = glob.glob(os.path.join(logs_dir, "*.csv"))
    all_data = []

    for f in log_files:
        try:
            df = pd.read_csv(f)
            if 'ISO8601' in df.columns:
                df = df[df['ISO8601'].str.startswith(target_date, na=False)]
                all_data.append(df)
        except Exception as e:
            print(f"Warning: Could not parse {f}: {e}")

    if not all_data:
        print(f"Error: No telemetry data found for {target_date}")
        return False

    df_combined = pd.concat(all_data).sort_values(by='Time')

    df_combined['Depth'] = pd.to_numeric(df_combined['Depth'], errors='coerce').fillna(0)
    df_combined['Temperature'] = pd.to_numeric(df_combined['Temperature'], errors='coerce').fillna(0)
    df_combined['Time'] = pd.to_numeric(df_combined['Time'], errors='coerce') + 3600

    df_combined['gap'] = df_combined['Time'].diff() > 300
    df_combined['session_id'] = df_combined['gap'].cumsum()

    dive_sessions = []
    for sid, group in df_combined.groupby('session_id'):
        if group['Depth'].max() > 1.0:
            dive_sessions.append(group)

    if not dive_sessions:
        print("Error: No valid dive sessions found (depth > 1.0m)")
        return False

    if list_only:
        print(f"\n--- Dive Summary for {target_date} ---")
        for i, active_dive in enumerate(dive_sessions):
            min_time = active_dive['Time'].min()
            max_time = active_dive['Time'].max()
            max_d = active_dive['Depth'].max()
            duration = int((max_time - min_time) / 60)

            start_str = pd.to_datetime(min_time, unit='s').strftime('%H:%M:%S')
            end_str = pd.to_datetime(max_time, unit='s').strftime('%H:%M:%S')

            print(f"Dive #{i+1}: {start_str} - {end_str} | Max Depth: {max_d:.1f}m | Duration: {duration} min")
        print("---------------------------------------")
        return True

    print(f" - Detected {len(dive_sessions)} valid dive sessions.")

    dives_metadata = []

    for i, active_dive in enumerate(dive_sessions):
        current_idx = i + 1
        if dive_id and current_idx != dive_id:
            continue

        curr_png = output_png.replace(".png", f"_{current_idx}.png")

        surface_start = active_dive[active_dive['Depth'] < 0.5].head(1)
        if surface_start.empty:
            surface_start = active_dive.head(1)

        lat = surface_start['Latitude'].iloc[0] if 'Latitude' in surface_start.columns else 0.0
        lon = surface_start['Longitude'].iloc[0] if 'Longitude' in surface_start.columns else 0.0

        plt.figure(figsize=(10, 2), dpi=100)
        plt.plot(active_dive['Time'], active_dive['Depth'], color='white', linewidth=2)
        plt.gca().invert_yaxis()
        plt.axis('off')
        plt.savefig(curr_png, transparent=True, bbox_inches='tight', pad_inches=0)
        plt.close()

        min_time = active_dive['Time'].min()
        max_time = active_dive['Time'].max()
        max_d = active_dive['Depth'].max()
        min_d = active_dive['Depth'].min()
        min_t = active_dive['Temperature'].min()
        max_t = active_dive['Temperature'].max()

        time_range = max_time - min_time if max_time > min_time else 1
        depth_range = max_d - min_d if max_d > min_d else 1

        points = []
        for _, row in active_dive.iterrows():
            points.append({
                't': int(row['Time']),
                'd': float(row['Depth']) if not pd.isna(row['Depth']) else 0,
                'temp': float(row['Temperature']) if not pd.isna(row['Temperature']) else 0,
                'x': (row['Time'] - min_time) / time_range,
                'y': (row['Depth'] - min_d) / depth_range
            })

        dives_metadata.append({
            'dive_idx': current_idx,
            'start_time': int(min_time),
            'end_time': int(max_time),
            'max_depth': float(max_d),
            'min_temp': float(min_t),
            'max_temp': float(max_t),
            'lat': float(lat),
            'lon': float(lon),
            'graph_path': curr_png,
            'points': points
        })

    with open(output_lua, 'w') as f:
        f.write("local Telemetry = {\n")
        f.write("    dives = {\n")
        for dive in dives_metadata:
            f.write("        {\n")
            f.write(f"            dive_idx = {dive['dive_idx']},\n")
            f.write(f"            max_depth = {dive['max_depth']},\n")
            f.write(f"            min_temp = {dive['min_temp']},\n")
            f.write(f"            lat = {dive['lat']},\n")
            f.write(f"            lon = {dive['lon']},\n")
            f.write(f"            start_time = {dive['start_time']},\n")
            f.write(f"            end_time = {dive['end_time']},\n")
            f.write(f"            graph_path = [[{dive['graph_path']}]],\n")
            f.write("            points = {\n")
            for p in dive['points']:
                f.write(f"                {{ t={p['t']}, d={p['d']}, temp={p['temp']}, x={p['x']}, y={p['y']} }},\n")
            f.write("            }\n")
            f.write("        },\n")
        f.write("    }\n}\nreturn Telemetry\n")

    print(f"Success: Assets generated for {len(dives_metadata)} dives.")
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("logs_dir")
    parser.add_argument("target_date")
    parser.add_argument("output_png", nargs="?", default="")
    parser.add_argument("output_lua", nargs="?", default="")
    parser.add_argument("--dive_id", type=int, default=None, help="Process a specific dive")
    parser.add_argument("--list_only", action="store_true", help="Print summary without generating assets")
    args = parser.parse_args()

    generate_telemetry(args.logs_dir, args.target_date, args.output_png, args.output_lua, args.dive_id, args.list_only)
