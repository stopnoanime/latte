#!/usr/bin/env bash
set -euo pipefail

# --- Simplified Configuration ---
URL="http://127.0.0.1:8000"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKLOAD="${ROOT}/workloads/alternator/large_objects.rn"
LATTE="${ROOT}/target/release/latte-alternator-new"
RESULTS_DIR="${ROOT}/results/simple-bench/$(date -u +%Y%m%dT%H%M%SZ)"

# Default cycles if not passed via environment variable
INSERT_CYCLES="${INSERT_CYCLES:-10000}"

mkdir -p "$RESULTS_DIR"
echo "Results will be saved to: $RESULTS_DIR"

# --- 1. Schema Setup ---
echo "Setting up schema..."
"$LATTE" schema "$WORKLOAD" "$URL" --request-compression off >/dev/null

# --- 2. Define Configurations ---
# Format: name|latte_arguments
read -r -d '' CONFIGS <<'EOF' || true
off|--request-compression off
default|--request-compression driver-default
gzip-1|--request-compression gzip --compression-level 1
gzip-5|--request-compression gzip --compression-level 5
gzip-9|--request-compression gzip --compression-level 9
zlib-1|--request-compression zlib --compression-level 1
zlib-5|--request-compression zlib --compression-level 5
zlib-9|--request-compression zlib --compression-level 9
strip|--enforce-header-whitelist true --request-compression off
no-strip|--enforce-header-whitelist false --request-compression off
EOF

echo "config,real_sec,exit_code" > "$RESULTS_DIR/summary.csv"

# --- 3. Run Benchmark Loop ---
while IFS='|' read -r config_name compression_args; do
    [[ -z "$config_name" ]] && continue
    
    echo "--------------------------------------------------"
    echo "Running config: $config_name"
    
    phase_dir="$RESULTS_DIR/$config_name"
    mkdir -p "$phase_dir"
    
    pcap_file="$phase_dir/traffic.pcap"
    time_file="$phase_dir/time.txt"
    
    # Start tcpdump in the background and capture its EXACT process ID
    # We assume passwordless sudo works perfectly here.
    #sudo tcpdump -i any -s 0 -w "$pcap_file" port 8000 > "$phase_dir/tcpdump.log" 2>&1 &
    sudo aa-exec -p unconfined tcpdump -i docker0 -s 0 -w "$pcap_file" port 8000 > "$phase_dir/tcpdump.log" 2>&1 &
    TCPDUMP_PID=$!
    
    # Give tcpdump a second to bind to the interface
    sleep 1
    
    # Run Latte workload (temporarily disable 'set -e' so a crash doesn't halt the script before we kill tcpdump)
    set +e
    # shellcheck disable=SC2086
    /usr/bin/time -p -o "$time_file" "$LATTE" run "$WORKLOAD" "$URL" \
        -f insert -d "$INSERT_CYCLES" \
        $compression_args \
        > "$phase_dir/latte.log" 2>&1
    EXIT_CODE=$?
    set -e
    
    # Safely stop ONLY our specific tcpdump process
    echo "Stopping tcpdump (PID: $TCPDUMP_PID)..."
    sudo kill -INT "$TCPDUMP_PID" 2>/dev/null || true
    wait "$TCPDUMP_PID" 2>/dev/null || true
    
    # Extract benchmark time
    real_sec=$(awk '/^real / {print $2}' "$time_file" || echo "0")
    
    # Log to summary
    echo "$config_name,$real_sec,$EXIT_CODE" >> "$RESULTS_DIR/summary.csv"
    echo "Finished $config_name. Exit code: $EXIT_CODE, Time: ${real_sec}s"

done <<<"$CONFIGS"

echo "--------------------------------------------------"
echo "Benchmark complete! Summary saved to: $RESULTS_DIR/summary.csv"