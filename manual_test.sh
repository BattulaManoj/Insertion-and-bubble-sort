#!/bin/bash

# manual_test.sh - COMPLETE MANUAL PERFORMANCE TESTING SCRIPT

echo "=== MANUAL PERFORMANCE TESTING ==="
echo "🎯 FOLLOW THESE STEPS CAREFULLY"
echo "================================"
echo

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="manual_test_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "📋 PREPARATION:"
echo "1. Open TWO terminal windows"
echo "2. This terminal (Terminal 1) - for monitoring"
echo "3. Another terminal (Terminal 2) - for running your program"
echo

# Check if memory_db exists
if [ ! -f "memory_db" ]; then
    echo "❌ Error: memory_db not found!"
    echo "Please make sure you're in the correct directory"
    echo "and that memory_db is compiled."
    exit 1
fi

echo "🚀 PHASE 1: BUBBLE SORT TEST"
echo "============================="
echo
echo "IN TERMINAL 2, RUN THESE COMMANDS:"
echo "----------------------------------"
echo "Step 1: Run the program"
echo "  ./memory_db"
echo
echo "Step 2: Enter this sequence:"
echo "  2 [Enter]   ← Bubble Sort"
echo "  [Wait for completion message - should see 'Time taken: XXX microseconds']"
echo "  9 [Enter]   ← Exit"
echo
echo "Step 3: Note down the results shown:"
echo "  - Time taken: ______ microseconds"
echo "  - Swaps: ______"
echo

echo "IN TERMINAL 1 (THIS TERMINAL), PRESS ENTER WHEN READY TO START MONITORING..."
read -p "Press Enter to start Bubble Sort monitoring..."

echo "📊 Monitoring Bubble Sort performance..."
echo "Collecting system metrics for 10 seconds..."

# Monitor CPU, memory, and disk I/O during the test
echo "=== System Monitoring Started ===" > "$RESULTS_DIR/bubble_monitor.log"
vmstat 1 10 >> "$RESULTS_DIR/bubble_monitor.log" 2>&1 &
VMSTAT_PID=$!

# Also collect disk I/O stats if iostat is available
if command -v iostat &> /dev/null; then
    iostat -dx 1 10 >> "$RESULTS_DIR/bubble_disk.log" 2>&1 &
    IOSTAT_PID=$!
fi

echo "⏳ Monitoring for 10 seconds..."
sleep 10

# Stop monitoring
kill $VMSTAT_PID 2>/dev/null
kill $IOSTAT_PID 2>/dev/null 2>/dev/null

echo "✅ BUBBLE SORT MONITORING COMPLETE"
echo
echo "IN TERMINAL 2: Did you complete the Bubble Sort test? (y/n)"
read -r answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "❌ Please complete the Bubble Sort test in Terminal 2 first!"
    exit 1
fi

echo
echo "🚀 PHASE 2: INSERTION SORT TEST"  
echo "==============================="
echo
echo "IN TERMINAL 2, RUN THESE COMMANDS:"
echo "----------------------------------"
echo "Step 1: Run the program again"
echo "  ./memory_db"
echo
echo "Step 2: Enter this sequence:"
echo "  3 [Enter]   ← Insertion Sort"
echo "  [Wait for completion message - should see 'Time taken: XXX microseconds']"  
echo "  9 [Enter]   ← Exit"
echo
echo "Step 3: Note down the results shown:"
echo "  - Time taken: ______ microseconds"
echo "  - Swaps: ______"
echo

echo "IN TERMINAL 1 (THIS TERMINAL), PRESS ENTER WHEN READY..."
read -p "Press Enter to start Insertion Sort monitoring..."

echo "📊 Monitoring Insertion Sort performance..."
echo "Collecting system metrics for 10 seconds..."

echo "=== System Monitoring Started ===" > "$RESULTS_DIR/insertion_monitor.log"
vmstat 1 10 >> "$RESULTS_DIR/insertion_monitor.log" 2>&1 &
VMSTAT_PID=$!

if command -v iostat &> /dev/null; then
    iostat -dx 1 10 >> "$RESULTS_DIR/insertion_disk.log" 2>&1 &
    IOSTAT_PID=$!
fi

echo "⏳ Monitoring for 10 seconds..."
sleep 10

# Stop monitoring
kill $VMSTAT_PID 2>/dev/null
kill $IOSTAT_PID 2>/dev/null 2>/dev/null

echo "✅ INSERTION SORT MONITORING COMPLETE"
echo

# Collect manual results
echo
echo "📝 ENTER YOUR RESULTS"
echo "====================="
echo

echo "BUBBLE SORT RESULTS:"
read -p "Time taken (microseconds): " BUBBLE_TIME
read -p "Number of swaps: " BUBBLE_SWAPS

echo
echo "INSERTION SORT RESULTS:"
read -p "Time taken (microseconds): " INSERTION_TIME  
read -p "Number of swaps: " INSERTION_SWAPS

# Analyze system metrics function
analyze_metrics() {
    local file=$1
    local test_name=$2
    
    echo
    echo "📊 $test_name SYSTEM METRICS:"
    if [ -f "$file" ]; then
        # Get the last 5 samples (skip headers)
        tail -n +3 "$file" | tail -5 > "$RESULTS_DIR/temp_analysis.txt"
        
        if [ -s "$RESULTS_DIR/temp_analysis.txt" ]; then
            # CPU usage analysis (idle time is column 15, usage = 100 - idle)
            avg_idle=$(awk '{sum += $15} END {printf "%.1f", sum/NR}' "$RESULTS_DIR/temp_analysis.txt")
            cpu_usage=$(echo "100 - $avg_idle" | bc -l 2>/dev/null | xargs printf "%.1f" 2>/dev/null || echo "N/A")
            
            # Memory analysis (free memory in KB, column 4)
            avg_mem_free=$(awk '{sum += $4} END {printf "%.0f", sum/NR}' "$RESULTS_DIR/temp_analysis.txt")
            
            # I/O analysis (if available)
            avg_io=$(awk '{sum += $9 + $10} END {printf "%.1f", sum/NR}' "$RESULTS_DIR/temp_analysis.txt" 2>/dev/null || echo "0")
            
            echo "  Average CPU Usage: ${cpu_usage}%"
            echo "  Average Free Memory: ${avg_mem_free} KB"
            echo "  Average I/O operations: ${avg_io}/sec"
            
            echo "  Sample metrics:"
            tail -3 "$file" | head -1 | awk '{print "    CPU idle: "$15"%, Free mem: "$4"KB, I/O: "$9+$10"/sec"}'
        else
            echo "  No valid metrics data"
        fi
    else
        echo "  No metrics file found"
    fi
}

# Create final report
cat > "$RESULTS_DIR/FINAL_REPORT.txt" << EOF
=== MANUAL PERFORMANCE TEST RESULTS ===
Test conducted: $(date)
Test method: Manual execution with system monitoring

SORTING ALGORITHM RESULTS:
--------------------------
BUBBLE SORT:
- Time: $BUBBLE_TIME microseconds
- Swaps: $BUBBLE_SWAPS

INSERTION SORT:  
- Time: $INSERTION_TIME microseconds
- Swaps: $INSERTION_SWAPS

PERFORMANCE COMPARISON:
----------------------
EOF

# Add comparison to report
if [ ! -z "$BUBBLE_TIME" ] && [ ! -z "$INSERTION_TIME" ] && [[ "$BUBBLE_TIME" =~ ^[0-9]+$ ]] && [[ "$INSERTION_TIME" =~ ^[0-9]+$ ]]; then
    if [ "$BUBBLE_TIME" -lt "$INSERTION_TIME" ]; then
        diff=$((INSERTION_TIME - BUBBLE_TIME))
        ratio=$(echo "scale=2; $INSERTION_TIME / $BUBBLE_TIME" | bc)
        cat >> "$RESULTS_DIR/FINAL_REPORT.txt" << EOF
Bubble Sort was faster by $diff microseconds
Insertion Sort took ${ratio}x longer
EOF
    else
        diff=$((BUBBLE_TIME - INSERTION_TIME))  
        ratio=$(echo "scale=2; $BUBBLE_TIME / $INSERTION_TIME" | bc)
        cat >> "$RESULTS_DIR/FINAL_REPORT.txt" << EOF
Insertion Sort was faster by $diff microseconds
Bubble Sort took ${ratio}x longer
EOF
    fi
else
    echo "Could not calculate comparison (invalid time values)" >> "$RESULTS_DIR/FINAL_REPORT.txt"
fi

cat >> "$RESULTS_DIR/FINAL_REPORT.txt" << EOF

SYSTEM METRICS COLLECTED:
-------------------------
- CPU and memory usage during each test
- Disk I/O statistics
- Files: bubble_monitor.log, insertion_monitor.log

FILES GENERATED:
----------------
- Bubble sort metrics: bubble_monitor.log
- Insertion sort metrics: insertion_monitor.log
- Disk I/O stats: bubble_disk.log, insertion_disk.log
- This summary: FINAL_REPORT.txt

EOF

# Display results to user
echo
echo "✅ TESTING COMPLETE!"
echo "==================="
echo "📁 All results saved in: $RESULTS_DIR/"
echo "📄 Final report: $RESULTS_DIR/FINAL_REPORT.txt"
echo

# Show system analysis
analyze_metrics "$RESULTS_DIR/bubble_monitor.log" "BUBBLE SORT"
analyze_metrics "$RESULTS_DIR/insertion_monitor.log" "INSERTION SORT"

echo
echo "🔍 TO VIEW DETAILED RESULTS:"
echo "   cat $RESULTS_DIR/FINAL_REPORT.txt"
echo "   ls -la $RESULTS_DIR/"
echo
echo "📊 YOUR SORTING RESULTS:"
echo "   Bubble Sort:    $BUBBLE_TIME microseconds, $BUBBLE_SWAPS swaps"
echo "   Insertion Sort: $INSERTION_TIME microseconds, $INSERTION_SWAPS swaps"

# Cleanup
rm -f "$RESULTS_DIR/temp_analysis.txt"

echo
echo "🎉 Manual testing completed successfully!"
