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
df_compression = df[df['config_name'].isin(['off', 'default'])]

sns.set_theme(style="whitegrid")
base_filename = os.path.splitext(args.csv_file)[0]

fig1, axes1 = plt.subplots(1, 2, figsize=(12, 6))

sns.barplot(
    data=df_headers,
    x='config_name',
    y='req_header_mb',
    ax=axes1[0],
    order=['no-strip', 'strip'],
    hue='config_name',
)
axes1[0].set_title('Header Size Comparison')
axes1[0].set_xlabel('Header Stripping Configuration')
axes1[0].set_ylabel('Total Request Header Size (MB)')

sns.barplot(
    data=df_headers,
    x='config_name',
    y='throughput',
    ax=axes1[1],
    order=['no-strip', 'strip'],
    hue='config_name',
)
axes1[1].set_title('Throughput Comparison')
axes1[1].set_xlabel('Header Stripping Configuration')
axes1[1].set_ylabel('Throughput (ops/sec)')

fig1.tight_layout()
out_headers = base_filename + '_headers_plot.png'
fig1.savefig(out_headers, dpi=300)
print(f"Saved header charts to {out_headers}")

fig2, axes2 = plt.subplots(1, 2, figsize=(12, 6))

sns.barplot(
    data=df_compression,
    x='config_name',
    y='req_total_mb',
    ax=axes2[0],
    order=['off', 'default'],
    hue='config_name',
)
axes2[0].set_title('Request Size Comparison')
axes2[0].set_xlabel('Compression Configuration')
axes2[0].set_ylabel('Total Request Size (MB)')

sns.barplot(
    data=df_compression,
    x='config_name',
    y='throughput',
    ax=axes2[1],
    order=['off', 'default'],
    hue='config_name',
)
axes2[1].set_title('Throughput Comparison')
axes2[1].set_xlabel('Compression Configuration')
axes2[1].set_ylabel('Throughput (ops/sec)')

fig2.tight_layout()
out_compression = base_filename + '_compression_plot.png'
fig2.savefig(out_compression, dpi=300)
print(f"Saved compression charts to {out_compression}")

plt.show()