import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import argparse
import os
import sys

parser = argparse.ArgumentParser(description='Plot HTTP benchmark results from CSV.')
parser.add_argument('csv_file', help='Path to the traffic_analysis.csv file')
args = parser.parse_args()

if not os.path.isfile(args.csv_file):
    print(f"Error: File '{args.csv_file}' not found.")
    sys.exit(1)

try:
    df = pd.read_csv(args.csv_file)
except Exception as e:
    print(f"Error reading CSV: {e}")
    sys.exit(1)

df['req_header_mb'] = df['req_header_bytes'] / (1024 * 1024)
df['req_total_mb'] = df['req_total_bytes'] / (1024 * 1024)

df_headers = df[df['config_name'].isin(['strip', 'no-strip'])]
df_off_default = df[df['config_name'].isin(['off', 'default'])]

sns.set_theme(style="whitegrid")

fig, axes = plt.subplots(1, 3, figsize=(18, 6))

sns.barplot(
    data=df_headers,
    x='config_name',
    y='req_header_mb',
    ax=axes[0],
    order=['no-strip', 'strip'],
    hue='config_name',
)
axes[0].set_title('Header Size Comparison')
axes[0].set_xlabel('Header Stripping Configuration')
axes[0].set_ylabel('Total Request Header Size (MB)')

sns.barplot(
    data=df_off_default,
    x='config_name',
    y='req_total_mb',
    ax=axes[1],
    order=['off', 'default'],
    hue='config_name',
)
axes[1].set_title('Request Size Comparison')
axes[1].set_xlabel('Compression Configuration')
axes[1].set_ylabel('Total Request Size (MB)')

sns.barplot(
    data=df_off_default,
    x='config_name',
    y='throughput',
    ax=axes[2],
    order=['off', 'default'],
    hue='config_name',
)
axes[2].set_title('Throughput Comparison')
axes[2].set_xlabel('Compression Configuration')
axes[2].set_ylabel('Throughput (ops/sec)')

plt.tight_layout()

output_filename = os.path.splitext(args.csv_file)[0] + '_plot.png'
plt.savefig(output_filename, dpi=300)
print(f"Saved charts to {output_filename}")

plt.show()