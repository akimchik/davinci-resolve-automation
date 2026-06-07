import pandas as pd
import matplotlib.pyplot as plt
import os
import sys
import glob

def generate_telemetry(logs_dir, target_date, output_png, output_lua):
    print(f"Generating telemetry for {target_date}...")

    # 1. Load and combine all logs for the target date
    log_files = glob.glob(os.path.join(logs_dir, "*.csv"))
    all_data = []

    for f in log_files:
        try:
            df = pd.read_csv(f)
            # Filter by ISO8601 column if it exists
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
    df_combined['Depth'] = pd.to_numeric(df_combined['Depth'], errors='coerce').fillna(0)
    df_combined['Temperature'] = pd.to_numeric(df_combined['Temperature'], errors='coerce').fillna(0)

    # Filter for active dive time (Depth > 0.5m)
    active_dive = df_combined[df_combined['Depth'] > 0.5].copy()
    if active_dive.empty:
        active_dive = df_combined

    # 3. Generate Depth Profile PNG
    plt.figure(figsize=(10, 2), dpi=100)
    plt.plot(active_dive['Time'], active_dive['Depth'], color='white', linewidth=2)
    plt.gca().invert_yaxis()
    plt.axis('off')
    plt.savefig(output_png, transparent=True, bbox_inches='tight', pad_inches=0)
    plt.close()

    # 4. Generate Lua Metadata for Animation
    min_time = active_dive['Time'].min()
    max_time = active_dive['Time'].max()
    max_d = active_dive['Depth'].max()
    min_d = active_dive['Depth'].min()

    time_range = max_time - min_time if max_time > min_time else 1
    depth_range = max_d - min_d if max_d > min_d else 1

    with open(output_lua, 'w') as f:
        f.write("local Telemetry = {\n")
        f.write(f"    max_depth = {max_d},\n")
        f.write(f"    min_temp = {active_dive['Temperature'].min()},\n")
        f.write(f"    max_temp = {active_dive['Temperature'].max()},\n")
        f.write("    points = {\n")

        for _, row in active_dive.iterrows():
            norm_x = (row['Time'] - min_time) / time_range
            norm_y = (row['Depth'] - min_d) / depth_range
            f.write(f"        {{ t={int(row['Time'])}, d={row['Depth']}, temp={row['Temperature']}, x={norm_x}, y={norm_y} }},\n")

        f.write("    }\n}\nreturn Telemetry\n")

    print(f"Success: Assets generated at {output_png} and {output_lua}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python generate_telemetry.py <logs_dir> <date> <out_png> <out_lua>")
        sys.exit(1)

    generate_telemetry(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
