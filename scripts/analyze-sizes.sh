#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_benchmark_results_folder>"
    echo "Example: $0 ./results/simple-bench/20260528T102201Z"
    exit 1
fi

RESULTS_DIR="${1%/}" # Strip trailing slash if present

if [ ! -d "$RESULTS_DIR" ]; then
    echo "Error: Directory '$RESULTS_DIR' does not exist."
    exit 1
fi

if ! command -v tshark &> /dev/null; then
    echo "Error: 'tshark' is required to analyze the pcaps."
    echo "Install it with: sudo apt install tshark"
    exit 1
fi

# --- Handle Output Directory Mirroring ---
if [[ "$RESULTS_DIR" =~ ^\./results(/|$) ]]; then
    OUTPUT_DIR="${RESULTS_DIR/.\/results/./outputs}"
elif [[ "$RESULTS_DIR" =~ ^results(/|$) ]]; then
    OUTPUT_DIR="${RESULTS_DIR/results/outputs}"
else
    OUTPUT_DIR="outputs/$RESULTS_DIR"
fi

# Create the mirrored directory layout
mkdir -p "$OUTPUT_DIR"
OUT_CSV="$OUTPUT_DIR/traffic_analysis.csv"

# Write CSV Header (Added 'throughput')
echo "config_name,time_sec,total_wire_bytes,req_total_bytes,req_header_bytes,req_body_bytes,throughput" > "$OUT_CSV"

echo "Scanning $RESULTS_DIR for pcaps..."

# Find all pcap files in the subdirectories
for pcap in "$RESULTS_DIR"/*/traffic.pcap; do
    [ -e "$pcap" ] || continue # Skip if glob didn't match anything
    
    config_dir=$(dirname "$pcap")
    config_name=$(basename "$config_dir")
    time_file="$config_dir/time.txt"
    latte_log="$config_dir/latte.log"
    
    # Extract time from time.txt
    real_sec="0"
    if [ -f "$time_file" ]; then
        real_sec=$(awk '/^real / {print $2}' "$time_file")
    fi

    # Extract throughput from latte.log
    throughput="0"
    if [ -f "$latte_log" ]; then
        # Matches the line starting with "Throughput [op/s]" and prints the 3rd column (the number)
        throughput=$(awk '/^[[:space:]]*Throughput[[:space:]]+\[op\/s\]/ {print $3}' "$latte_log")
    fi
    
    echo "  -> Analyzing config: $config_name"
    
    # 1. Total bytes on the wire (All L2 frames, both directions)
    total_wire=$(tshark -r "$pcap" -T fields -e frame.len 2>/dev/null | awk '{s+=$1} END {print s+0}')
    
    # 2. Total bytes sent by client in TCP payload (Requests to port 8000)
    req_total=$(tshark -r "$pcap" -Y "tcp.dstport == 8000" -T fields -e tcp.len 2>/dev/null | awk '{s+=$1} END {print s+0}')
    
    # 3. Total HTTP body bytes sent by client (Sum of HTTP Content-Length)
    req_body=$(tshark -r "$pcap" -Y "tcp.dstport == 8000 and http.request" -T fields -e http.content_length 2>/dev/null | awk '{s+=$1} END {print s+0}')
    
    # 4. Request Header bytes (Total TCP payload minus the Body payload)
    req_header=$((req_total - req_body))
    
    # Append to CSV
    echo "$config_name,$real_sec,$total_wire,$req_total,$req_header,$req_body,$throughput" >> "$OUT_CSV"
done

echo "--------------------------------------------------"
echo "Analysis complete! Saved to: $OUT_CSV"
echo "Summary preview:"
echo "--------------------------------------------------"
# Print a nicely formatted table to the terminal
column -s, -t < "$OUT_CSV"