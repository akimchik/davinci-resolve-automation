import pandas as pd
import matplotlib.pyplot as plt
import json
import os
import sys
import glob

def generate_telemetry(logs_dir, target_date, output_png, output_json):
    print(f"Generating telemetry for {target_date}...")

    # 1. Load and combine all logs for the target date
    log_files = glob.glob(os.path.join(logs_dir, "*.csv"))
    all_data = []

    for f in log_files:
        try:
            df = pd.read_csv(f)
            # Filter by ISO8601 column if it exists, else by file mtime (approximate)
            if 'ISO8601' in df.columns:
                df = df[df['ISO8601'].str.contains(target_date, na=False)]
                all_data.append(df)
        except Exception as e:
            print(f"Warning: Could not parse {f}: {e}")

    if not all_data:
        print(f"Error: No telemetry data found for {target_date}")
        return False

    df_combined = pd.concat(all_data).sort_values(by='Time')

    # 2. Process Data
    # Depth is in field 3 (usually), Temp in 2
    # Ensure they are numeric
    df_combined['Depth'] = pd.to_numeric(df_combined['Depth'], errors='coerce').fillna(0)
    df_combined['Temperature'] = pd.to_numeric(df_combined['Temperature'], errors='coerce').fillna(0)

    # Filter for active dive time (Depth > 0.5m)
    active_dive = df_combined[df_combined['Depth'] > 0.5].copy()
    if active_dive.empty:
        active_dive = df_combined # Fallback to full logs if no depth recorded

    # 3. Generate Depth Profile PNG
    # Use a high-quality, transparent plot
    plt.figure(figsize=(10, 2), dpi=100) # Wide and short for bottom overlay
    plt.plot(active_dive['Time'], active_dive['Depth'], color='white', linewidth=2)
    plt.gca().invert_yaxis() # Depth increases downwards

    # Stylize: Remove axes and background
    plt.axis('off')
    plt.savefig(output_png, transparent=True, bbox_inches='tight', pad_inches=0)
    plt.close()

    # 4. Generate JSON Metadata for Animation
    # We need normalized coordinates for the tracking dot
    # X = (time - min_time) / (max_time - min_time)
    # Y = (depth - min_depth) / (max_depth - min_depth)

    min_time = active_dive['Time'].min()
    max_time = active_dive['Time'].max()
    max_d = active_dive['Depth'].max()
    min_d = active_dive['Depth'].min()

    time_range = max_time - min_time if max_time > min_time else 1
    depth_range = max_d - min_d if max_d > min_d else 1

    telemetry_points = []
    # Sample at ~1Hz for performance (or all points if short)
    for index, row in active_dive.iterrows():
        # Normalized coordinates (0.0 to 1.0)
        # In Resolve Fusion:
        #   X 0.5 is center. Let's provide absolute normalized for mapping.
        norm_x = (row['Time'] - min_time) / time_range
        norm_y = (row['Depth'] - min_d) / depth_range

        telemetry_points.append({
            "t": int(row['Time']),
            "depth": float(row['Depth']),
            "temp": float(row['Temperature']),
            "x": float(norm_x),
            "y": float(norm_y)
        })

    summary = {
        "max_depth": float(max_d),
        "min_temp": float(active_dive['Temperature'].min()),
        "max_temp": float(active_dive['Temperature'].max()),
        "points": telemetry_points
    }

    with open(output_json, 'w') as f:
        json.dump(summary, f)

    print(f"Success: Assets generated at {output_png} and {output_json}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python generate_telemetry.py <logs_dir> <date> <out_png> <out_json>")
        sys.exit(1)

    generate_telemetry(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
