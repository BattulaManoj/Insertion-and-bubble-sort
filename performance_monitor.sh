#!/bin/bash

# PROPER PERFORMANCE MONITORING WITH WORKING INPUT

echo "=== ACCURATE PERFORMANCE MONITORING ==="
echo

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="accurate_results_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

# Check if executable exists
if [ ! -f "memory_db" ]; then
    echo "Compiling program..."
    g++ -std=c++11 -o memory_db memory_db.cpp
    if [ $? -ne 0 ]; then
        echo "Compilation failed!"
        exit 1
    fi
fi

# Function to run sort with proper timing
run_sort_test() {
    local sort_name=$1
    local choice=$2
    local output_file="$RESULTS_DIR/${sort_name}_output.txt"
    local metrics_prefix="$RESULTS_DIR/${sort_name}"
    
    echo "🚀 RUNNING $sort_name..."
    echo "========================="
    
    # Start system monitoring
    echo "📊 Starting system monitoring..."
    vmstat 1 10 > "${metrics_prefix}_vmstat.txt" 2>&1 &
    VMSTAT_PID=$!
    
    # Run the sort test with proper input timing
    {
        echo "$choice"  # Select sort option
        sleep 5         # Wait for sort to complete
        echo "9"        # Exit program
    } | ./memory_db > "$output_file" 2>&1
    
    # Wait for monitoring to complete
    wait $VMSTAT_PID
    
    echo "✅ $sort_name completed"
    echo
}

# Run the tests
run_sort_test "bubble_sort" "2"
sleep 2
run_sort_test "insertion_sort" "3"

# Extract and analyze results
echo "🔍 ANALYZING RESULTS..."
echo "======================="

extract_metrics() {
    local sort_name=$1
    local output_file="$RESULTS_DIR/${sort_name}_output.txt"
    local vmstat_file="$RESULTS_DIR/${sort_name}_vmstat.txt"
    
    # Extract sort metrics
    local time=$(grep -i "time" "$output_file" | grep -oE "[0-9]+" | head -1)
    local swaps=$(grep -i "swap" "$output_file" | grep -oE "[0-9]+" | head -1)
    
    # Extract CPU usage from vmstat (average of last 5 samples)
    local cpu_idle=$(tail -5 "$vmstat_file" | awk '{sum += $15} END {print sum/5}')
    local cpu_usage=$((100 - ${cpu_idle%.*}))
    
    echo "$sort_name,$time,$swaps,$cpu_usage"
}

# Create results summary
echo "SORT_TYPE,TIME_MICROSECONDS,SWAPS,CPU_USAGE_PERCENT" > "$RESULTS_DIR/summary.csv"
extract_metrics "bubble_sort" >> "$RESULTS_DIR/summary.csv"
extract_metrics "insertion_sort" >> "$RESULTS_DIR/summary.csv"

# Display results
echo "📊 FINAL RESULTS:"
echo "================="
cat "$RESULTS_DIR/summary.csv"
echo

# Create detailed report
cat > "$RESULTS_DIR/FINAL_ANALYSIS.txt" << EOF
=== ACCURATE PERFORMANCE ANALYSIS ===
Test conducted: $(date)

SORTING RESULTS:
$(cat "$RESULTS_DIR/summary.csv")

SYSTEM METRICS DURING TESTS:
- CPU usage measured via vmstat
- Metrics collected during actual sorting operations
- 10 samples taken at 1-second intervals during each test

FILES GENERATED:
- Bubble sort output: bubble_sort_output.txt
- Insertion sort output: insertion_sort_output.txt  
- Bubble sort metrics: bubble_sort_vmstat.txt
- Insertion sort metrics: insertion_sort_vmstat.txt
- Summary: summary.csv

EOF

echo "✅ ACCURATE TESTING COMPLETE!"
echo "📁 Results in: $RESULTS_DIR/"
