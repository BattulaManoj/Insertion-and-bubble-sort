# memory_db.jl

using Dates
using Printf

# -------------------------
# Performance Monitoring Functions
# -------------------------

# Function to get CPU usage
function get_cpu_usage()
    try
        # Read the first line of /proc/stat
        stat = readlines("/proc/stat")[1]
        values = split(stat)
        
        # Extract CPU times (user, nice, system, idle, iowait, etc.)
        user = parse(Int, values[2])
        nice = parse(Int, values[3])
        system = parse(Int, values[4])
        idle = parse(Int, values[5])
        iowait = parse(Int, values[6])
        
        # Calculate total and idle times
        total = user + nice + system + idle + iowait
        return (idle, total)
    catch e
        return (0, 1)  # Return default values if error
    end
end

# Function to calculate CPU usage percentage
function calculate_cpu_percentage(idle1, total1, idle2, total2)
    idle_diff = idle2 - idle1
    total_diff = total2 - total1
    
    if total_diff > 0
        usage = 100.0 * (total_diff - idle_diff) / total_diff
        return round(usage, digits=2)
    else
        return 0.0
    end
end

# Function to get disk I/O statistics
function get_disk_io()
    try
        # Read /proc/diskstats
        lines = readlines("/proc/diskstats")
        for line in lines
            if occursin(r"sd[a-z] |nvme|vd[a-z] ", line)  # Match physical disks
                values = split(line)
                if length(values) >= 14
                    # Return reads completed, sectors read, writes completed, sectors written
                    reads = parse(Int, values[4])
                    sectors_read = parse(Int, values[6])
                    writes = parse(Int, values[8])
                    sectors_written = parse(Int, values[10])
                    return (reads, sectors_read, writes, sectors_written)
                end
            end
        end
        return (0, 0, 0, 0)
    catch e
        return (0, 0, 0, 0)
    end
end

# Function to get memory usage
function get_memory_usage()
    try
        meminfo = readlines("/proc/meminfo")
        total_mem = 0
        free_mem = 0
        available_mem = 0
        
        for line in meminfo
            if startswith(line, "MemTotal:")
                total_mem = parse(Int, split(line)[2])
            elseif startswith(line, "MemFree:")
                free_mem = parse(Int, split(line)[2])
            elseif startswith(line, "MemAvailable:")
                available_mem = parse(Int, split(line)[2])
            end
        end
        
        if total_mem > 0
            usage_percent = 100.0 * (total_mem - available_mem) / total_mem
            return (total_mem, available_mem, round(usage_percent, digits=2))
        else
            return (0, 0, 0.0)
        end
    catch e
        return (0, 0, 0.0)
    end
end

# Performance monitoring function
function monitor_performance(monitor_duration::Int=10, sample_interval::Float64=0.5)
    println("📊 Starting system performance monitoring...")
    println("Duration: $monitor_duration seconds, Interval: $(sample_interval)s")
    println(string('-', 80))
    
    # Initial readings
    cpu_idle1, cpu_total1 = get_cpu_usage()
    disk_reads1, disk_sectors_read1, disk_writes1, disk_sectors_written1 = get_disk_io()
    mem_total, mem_available, mem_usage = get_memory_usage()
    
    # Storage for metrics
    cpu_usages = Float64[]
    memory_usages = Float64[]
    disk_reads = Int[]
    disk_writes = Int[]
    timestamps = Float64[]
    
    start_time = time()
    sample_count = 0
    
    println("Time(s) | CPU%  | Memory% | Disk R/W")
    println(string('-', 40))
    
    while (time() - start_time) < monitor_duration
        # Get current metrics
        cpu_idle2, cpu_total2 = get_cpu_usage()
        disk_reads2, disk_sectors_read2, disk_writes2, disk_sectors_written2 = get_disk_io()
        _, _, mem_usage_current = get_memory_usage()
        
        # Calculate CPU usage
        cpu_usage = calculate_cpu_percentage(cpu_idle1, cpu_total1, cpu_idle2, cpu_total2)
        
        # Calculate disk I/O delta
        disk_reads_delta = disk_reads2 - disk_reads1
        disk_writes_delta = disk_writes2 - disk_writes1
        
        # Store metrics
        push!(cpu_usages, cpu_usage)
        push!(memory_usages, mem_usage_current)
        push!(disk_reads, disk_reads_delta)
        push!(disk_writes, disk_writes_delta)
        push!(timestamps, time() - start_time)
        
        # Print current status
        elapsed = round(time() - start_time, digits=1)
        @printf("%7.1f | %5.1f | %7.1f | R:%-4d W:%-4d\n", 
                elapsed, cpu_usage, mem_usage_current, disk_reads_delta, disk_writes_delta)
        
        # Update previous values
        cpu_idle1, cpu_total1 = cpu_idle2, cpu_total2
        disk_reads1, disk_writes1 = disk_reads2, disk_writes2
        
        sample_count += 1
        sleep(sample_interval)
    end
    
    # Calculate averages
    avg_cpu = isempty(cpu_usages) ? 0.0 : mean(cpu_usages)
    avg_memory = isempty(memory_usages) ? 0.0 : mean(memory_usages)
    total_reads = sum(disk_reads)
    total_writes = sum(disk_writes)
    
    println(string('-', 80))
    println("📈 MONITORING SUMMARY:")
    println("Samples collected: $sample_count")
    println("Average CPU Usage: $(round(avg_cpu, digits=2))%")
    println("Average Memory Usage: $(round(avg_memory, digits=2))%")
    println("Total Disk Reads: $total_reads")
    println("Total Disk Writes: $total_writes")
    println("Monitoring duration: $(round(time() - start_time, digits=2)) seconds")
    
    return (cpu_usages, memory_usages, disk_reads, disk_writes, timestamps)
end

# Utility function for mean calculation
function mean(x::Vector)
    isempty(x) && return 0.0
    return sum(x) / length(x)
end

# -------------------------
# Node structure for doubly linked list
# -------------------------
mutable struct Node
    data::Vector{String}
    prev::Union{Node, Nothing}
    next::Union{Node, Nothing}
    
    function Node(data::Vector{String})
        new(data, nothing, nothing)
    end
end

# -------------------------
# DoublyLinkedList class
# -------------------------
mutable struct DoublyLinkedList
    head::Union{Node, Nothing}
    tail::Union{Node, Nothing}
    filename::String
    rowCount::Int
    swapCount::Int
    
    function DoublyLinkedList()
        new(nothing, nothing, "", 0, 0)
    end
end

# Load from CSV file
function loadFromCSV!(db::DoublyLinkedList, filename::String)
    db.filename = filename
    db.rowCount = 0
    db.swapCount = 0
    
    if !isfile(filename)
        println("[ERROR] Could not open file: $filename")
        return
    end
    
    rows = Vector{Vector{String}}()
    open(filename, "r") do file
        for line in eachline(file)
            row = split(line, ',')
            row = String.(row)
            push!(rows, row)
        end
    end
    
    if isempty(rows)
        db.head = nothing
        db.tail = nothing
    else
        db.head = buildListRecursive(rows, 1, nothing)
        db.rowCount = length(rows)
        # Set tail pointer
        temp = db.head
        while temp !== nothing && temp.next !== nothing
            temp = temp.next
        end
        db.tail = temp
    end
    
    println("[INFO] Loaded $(db.rowCount) rows from $filename")
end

# Recursive function to build the doubly linked list
function buildListRecursive(rows::Vector{Vector{String}}, index::Int, prev::Union{Node, Nothing})
    if index > length(rows)
        return nothing
    end
    
    newNode = Node(rows[index])
    newNode.prev = prev
    newNode.next = buildListRecursive(rows, index + 1, newNode)
    
    return newNode
end

# Export to CSV file
function exportToCSV(db::DoublyLinkedList, outputFilename::String="")
    if isempty(outputFilename)
        outputFilename = db.filename
    end
    
    open(outputFilename, "w") do file
        exportRecursive(db.head, file)
    end
    
    println("[INFO] Exported $(db.rowCount) rows to $outputFilename")
end

# Recursive export function
function exportRecursive(node::Union{Node, Nothing}, file::IOStream)
    if node === nothing
        return
    end
    
    join(file, node.data, ',')
    write(file, '\n')
    
    exportRecursive(node.next, file)
end

# CORRECTED Display function
function display(db::DoublyLinkedList, limit::Int=10)
    println("\n=== STUDENT DATABASE RECORDS ===")
    println("Total records: $(db.rowCount)\n")
    
    if db.rowCount == 0
        println("No records found.")
        return
    end
    
    # Display header
    println(lpad("ID", 5), lpad("School", 10), lpad("Sex", 5), lpad("Age", 5),
            lpad("Address", 10), lpad("FamSize", 10), lpad("Passed", 10))
    println(repeat('-', 55))
    
    # Display data - CORRECTED COLUMN MAPPING
    index = 1
    temp = db.head === nothing ? nothing : db.head.next  # Skip header
    
    while temp !== nothing && index <= limit
        print(lpad(string(index), 5))
        if length(temp.data) >= 31  # Ensure we have enough columns
            school = temp.data[1]
            sex = temp.data[2]
            age = temp.data[3]
            address = temp.data[4]
            famsize = temp.data[5]
            passed = temp.data[31]  # Column 31 for passed status
            
            # Truncate long values for display
            school_disp = length(school) > 8 ? school[1:7] * "." : school
            famsize_disp = length(famsize) > 8 ? famsize[1:7] * "." : famsize
            passed_disp = length(passed) > 6 ? passed[1:5] * "." : passed
            
            print(lpad(school_disp, 10), lpad(sex, 5), lpad(age, 5))
            print(lpad(address, 10), lpad(famsize_disp, 10), lpad(passed_disp, 10))
        else
            println(" [Incomplete data: only $(length(temp.data)) columns]")
        end
        println()
        temp = temp.next
        index += 1
    end
    
    if db.rowCount > limit
        println("... and $(db.rowCount - limit) more records")
    end
end

# CORRECTED Bubble Sort implementation
function bubbleSort!(db::DoublyLinkedList, sortColumn::Int=2)
    if db.head === nothing || db.head.next === nothing
        return
    end
    
    # Check if column exists
    if length(db.head.next.data) < sortColumn
        println("[ERROR] Column $sortColumn does not exist. Data has only $(length(db.head.next.data)) columns.")
        return
    end
    
    # Get column name from header
    column_name = db.head.data[sortColumn]
    println("\n=== BUBBLE SORT (Column $sortColumn: $column_name) ===")
    db.swapCount = 0
    startTime = time()
    
    swapped = true
    lastSorted = nothing
    
    while swapped
        swapped = false
        current = db.head.next # Skip header
        
        while current !== nothing && current.next !== nothing && current.next !== lastSorted
            # Ensure both nodes have the column we're sorting by
            if length(current.data) >= sortColumn && length(current.next.data) >= sortColumn
                # Compare the values in the specified column
                if current.data[sortColumn] > current.next.data[sortColumn]
                    # Swap the entire row data
                    current.data, current.next.data = current.next.data, current.data
                    swapped = true
                    db.swapCount += 1
                end
            end
            current = current.next
        end
        lastSorted = current
    end
    
    endTime = time()
    duration = (endTime - startTime) * 1_000_000
    
    println("Sort completed!")
    println("Number of swaps: $(db.swapCount)")
    println("Time taken: $(round(Int, duration)) microseconds")
end

# CORRECTED Insertion Sort implementation
function insertionSort!(db::DoublyLinkedList, sortColumn::Int=2)
    if db.head === nothing || db.head.next === nothing || db.head.next.next === nothing
        return
    end
    
    # Check if column exists
    if length(db.head.next.data) < sortColumn
        println("[ERROR] Column $sortColumn does not exist. Data has only $(length(db.head.next.data)) columns.")
        return
    end
    
    # Get column name from header
    column_name = db.head.data[sortColumn]
    println("\n=== INSERTION SORT (Column $sortColumn: $column_name) ===")
    db.swapCount = 0
    startTime = time()
    
    # Start from the second data node (skip header)
    current = db.head.next.next
    
    while current !== nothing
        # Store the current row as key
        key_row = copy(current.data)
        prev_node = current.prev
        shifts = 0
        
        # Move backwards through sorted portion
        while prev_node !== db.head && prev_node !== nothing
            # Ensure both nodes have the column we're sorting by
            if length(prev_node.data) >= sortColumn && length(key_row) >= sortColumn
                if prev_node.data[sortColumn] > key_row[sortColumn]
                    # Shift the row to the right
                    prev_node.next.data = copy(prev_node.data)
                    prev_node = prev_node.prev
                    shifts += 1
                else
                    break
                end
            else
                break
            end
        end
        
        # Insert the key at correct position
        if prev_node !== nothing && prev_node.next !== nothing
            prev_node.next.data = key_row
        end
        
        db.swapCount += shifts
        current = current.next
    end
    
    endTime = time()
    duration = (endTime - startTime) * 1_000_000
    
    println("Sort completed!")
    println("Number of swaps: $(db.swapCount)")
    println("Time taken: $(round(Int, duration)) microseconds")
end

# Performance comparison
function performanceComparison(db::DoublyLinkedList)
    println("\n=== PERFORMANCE COMPARISON ===")
    println("Testing on fresh data copies for fair comparison...\n")
    
    # Test 1: Bubble Sort by Age (Column 3)
    println("--- BUBBLE SORT BY AGE (Column 3) ---")
    dbBubbleAge = DoublyLinkedList()
    loadFromCSV!(dbBubbleAge, "student-data.csv")
    bubbleSort!(dbBubbleAge, 3)
    
    # Test 2: Insertion Sort by Age (Column 3)
    println("\n--- INSERTION SORT BY AGE (Column 3) ---")
    dbInsertionAge = DoublyLinkedList()
    loadFromCSV!(dbInsertionAge, "student-data.csv")
    insertionSort!(dbInsertionAge, 3)
    
    # Test 3: Bubble Sort by Passed Status (Column 31)
    println("\n--- BUBBLE SORT BY PASSED STATUS (Column 31) ---")
    dbBubblePassed = DoublyLinkedList()
    loadFromCSV!(dbBubblePassed, "student-data.csv")
    bubbleSort!(dbBubblePassed, 31)
    
    # Test 4: Insertion Sort by Passed Status (Column 31)
    println("\n--- INSERTION SORT BY PASSED STATUS (Column 31) ---")
    dbInsertionPassed = DoublyLinkedList()
    loadFromCSV!(dbInsertionPassed, "student-data.csv")
    insertionSort!(dbInsertionPassed, 31)
    
    println("\n=== FINAL RESULTS ===")
    println("SORTING BY AGE (Column 3):")
    println("Bubble Sort: $(dbBubbleAge.swapCount) swaps")
    println("Insertion Sort: $(dbInsertionAge.swapCount) swaps")
    
    println("\nSORTING BY PASSED STATUS (Column 31):")
    println("Bubble Sort: $(dbBubblePassed.swapCount) swaps")
    println("Insertion Sort: $(dbInsertionPassed.swapCount) swaps")
end

# Utility functions
function printMenu()
    println("\n=== MEMORY DATABASE WITH SORTING ALGORITHMS ===")
    println("1. Display records (first 10)")
    println("2. Bubble Sort by Age (Column 3)")
    println("3. Insertion Sort by Age (Column 3)")
    println("4. Bubble Sort by Passed Status (Column 31)")
    println("5. Insertion Sort by Passed Status (Column 31)")
    println("6. Export sorted data to CSV")
    println("7. Reload from CSV")
    println("8. Performance Comparison")
    println("9. System Performance Monitoring")
    println("10. Exit")
    print("Enter your choice: ")
end

# Main function
function main()
    db = DoublyLinkedList()
    
    println("=== MEMORY DATABASE WITH SORTING ALGORITHMS ===")
    println("Loading data from student-data.csv...")
    loadFromCSV!(db, "student-data.csv")
    
    # Show correct column mapping
    println("\n=== COLUMN MAPPING ===")
    if db.head !== nothing
        println("Age is in Column 3: '$(db.head.data[3])'")
        println("Passed Status is in Column 31: '$(db.head.data[31])'")
    end
    
    while true
        printMenu()
        choice_str = readline()
        if isempty(choice_str)
            println("Invalid choice. Please try again.")
            continue
        end
        
        choice = try
            parse(Int, choice_str)
        catch
            -1
        end
        
        if choice == 1
            display(db)
        elseif choice == 2
            loadFromCSV!(db, "student-data.csv")
            bubbleSort!(db, 3)  # Age is column 3
            display(db, 10)
        elseif choice == 3
            loadFromCSV!(db, "student-data.csv")
            insertionSort!(db, 3)  # Age is column 3
            display(db, 10)
        elseif choice == 4
            loadFromCSV!(db, "student-data.csv")
            bubbleSort!(db, 31)  # Passed status is column 31
            display(db, 10)
        elseif choice == 5
            loadFromCSV!(db, "student-data.csv")
            insertionSort!(db, 31)  # Passed status is column 31
            display(db, 10)
        elseif choice == 6
            print("Enter output filename (or press Enter for sorted_student-data.csv): ")
            input = readline()
            if isempty(input)
                input = "sorted_student-data.csv"
            end
            exportToCSV(db, input)
        elseif choice == 7
            loadFromCSV!(db, "student-data.csv")
            println("Database reloaded successfully!")
        elseif choice == 8
            performanceComparison(db)
        elseif choice == 9
            println("Starting performance monitoring...")
            monitor_performance(10, 0.5)  # Monitor for 10 seconds
        elseif choice == 10
            println("Exiting... Goodbye!")
            break
        else
            println("Invalid choice. Please try again.")
        end
        
        if choice != 10
            println("\nPress Enter to continue...")
            readline()
        end
    end
end

# Run the main function
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
