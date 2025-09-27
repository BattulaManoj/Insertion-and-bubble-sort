#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>
#include <iomanip>
#include <chrono>
#include <ctime>

using namespace std;
using namespace std::chrono;

// -------------------------
// Node structure for doubly linked list
// -------------------------
struct Node {
    vector<string> data;
    Node* prev;
    Node* next;
    
    Node(vector<string> rowData) : data(rowData), prev(nullptr), next(nullptr) {}
};

// -------------------------
// DoublyLinkedList class
// -------------------------
class DoublyLinkedList {
private:
    Node* head;
    Node* tail;
    string filename;
    int rowCount;
    int swapCount;
    
    Node* buildListRecursive(vector<vector<string>>& rows, int index, Node* prev) {
        if (index >= rows.size()) return nullptr;
        
        Node* newNode = new Node(rows[index]);
        newNode->prev = prev;
        newNode->next = buildListRecursive(rows, index + 1, newNode);
        
        if (index == rows.size() - 1) {
            tail = newNode;
        }
        
        return newNode;
    }
    
    void exportRecursive(Node* node, ofstream& file) {
        if (!node) return;
        
        for (size_t i = 0; i < node->data.size(); i++) {
            file << node->data[i];
            if (i != node->data.size() - 1) file << ",";
        }
        file << "\n";
        
        exportRecursive(node->next, file);
    }
    
    void freeMemoryRecursive(Node* node) {
        if (!node) return;
        freeMemoryRecursive(node->next);
        delete node;
    }

public:
    DoublyLinkedList() : head(nullptr), tail(nullptr), rowCount(0), swapCount(0) {}
    
    ~DoublyLinkedList() {
        freeMemoryRecursive(head);
    }
    
    void loadFromCSV(string file) {
        filename = file;
        rowCount = 0;
        swapCount = 0;
        
        ifstream inFile(filename);
        if (!inFile.is_open()) {
            cerr << "[ERROR] Could not open file: " << filename << endl;
            return;
        }
        
        vector<vector<string>> rows;
        string line;
        while (getline(inFile, line)) {
            vector<string> row;
            stringstream ss(line);
            string cell;
            
            while (getline(ss, cell, ',')) {
                row.push_back(cell);
            }
            
            rows.push_back(row);
        }
        inFile.close();
        
        if (rows.empty()) {
            head = nullptr;
            tail = nullptr;
        } else {
            head = buildListRecursive(rows, 0, nullptr);
            rowCount = rows.size();
        }
        
        cout << "[INFO] Loaded " << rowCount << " rows from " << filename << endl;
    }
    
    void exportToCSV(string outputFilename = "") {
        if (outputFilename.empty()) {
            outputFilename = filename;
        }
        
        ofstream outFile(outputFilename);
        if (!outFile.is_open()) {
            cerr << "[ERROR] Could not open file for writing: " << outputFilename << endl;
            return;
        }
        
        exportRecursive(head, outFile);
        outFile.close();
        
        cout << "[INFO] Exported " << rowCount << " rows to " << outputFilename << endl;
    }
    
    void display(int limit = 10) {
        cout << "\n=== STUDENT DATABASE RECORDS ===" << endl;
        cout << "Total records: " << rowCount << "\n" << endl;
        
        if (rowCount == 0) {
            cout << "No records found." << endl;
            return;
        }
        
        Node* temp = head;
        if (temp && !temp->data.empty()) {
            cout << left << setw(5) << "ID";
            cout << setw(10) << "School" << setw(5) << "Sex" << setw(5) << "Age";
            cout << setw(10) << "Address" << setw(10) << "FamSize" << setw(10) << "Passed" << endl;
            cout << string(55, '-') << endl;
        }
        
        int index = 1;
        temp = head->next;
        while (temp && index <= limit) {
            cout << left << setw(5) << index++;
            if (temp->data.size() >= 31) {
                cout << setw(10) << (temp->data[0].length() > 8 ? temp->data[0].substr(0, 7) + "." : temp->data[0]);
                cout << setw(5) << temp->data[1];
                cout << setw(5) << temp->data[2];
                cout << setw(10) << temp->data[3];
                cout << setw(10) << (temp->data[4].length() > 8 ? temp->data[4].substr(0, 7) + "." : temp->data[4]);
                cout << setw(10) << temp->data[30];
            }
            cout << endl;
            temp = temp->next;
        }
        
        if (rowCount > limit) {
            cout << "... and " << (rowCount - limit) << " more records" << endl;
        }
    }
    
    // Bubble Sort implementation
    void bubbleSort(int sortColumn = 2) {
        if (!head || !head->next) return;
        
        cout << "\n=== BUBBLE SORT (Column " << sortColumn << ") ===" << endl;
        swapCount = 0;
        auto start = high_resolution_clock::now();
        
        bool swapped;
        Node* current;
        Node* lastSorted = nullptr;
        
        do {
            swapped = false;
            current = head->next;
            
            while (current->next != lastSorted && current->next != nullptr) {
                if (current->data.size() > sortColumn && current->next->data.size() > sortColumn) {
                    if (current->data[sortColumn] > current->next->data[sortColumn]) {
                        swap(current->data, current->next->data);
                        swapped = true;
                        swapCount++;
                    }
                }
                current = current->next;
            }
            lastSorted = current;
        } while (swapped);
        
        auto end = high_resolution_clock::now();
        auto duration = duration_cast<microseconds>(end - start);
        
        cout << "Sort completed!" << endl;
        cout << "Number of swaps: " << swapCount << endl;
        cout << "Time taken: " << duration.count() << " microseconds" << endl;
    }
    
    // CORRECTED Insertion Sort implementation
    void insertionSort(int sortColumn = 2) {
        if (!head || !head->next || !head->next->next) return;
        
        cout << "\n=== INSERTION SORT (Column " << sortColumn << ") ===" << endl;
        swapCount = 0;
        auto start = high_resolution_clock::now();
        
        // Start from the second data node (skip header)
        Node* current = head->next->next;
        
        while (current != nullptr) {
            vector<string> key = current->data;
            Node* j = current->prev;
            
            // Move elements that are greater than key to one position ahead
            while (j != head && j->data.size() > sortColumn && 
                   key.size() > sortColumn && j->data[sortColumn] > key[sortColumn]) {
                // Shift the element to the right
                j->next->data = j->data;
                j = j->prev;
                swapCount++; // Count each shift as a swap
            }
            
            // Insert the key at the correct position
            j->next->data = key;
            current = current->next;
        }
        
        auto end = high_resolution_clock::now();
        auto duration = duration_cast<microseconds>(end - start);
        
        cout << "Sort completed!" << endl;
        cout << "Number of swaps: " << swapCount << endl;
        cout << "Time taken: " << duration.count() << " microseconds" << endl;
    }
    
    // DEBUG VERSION - Shows what's happening during sort
    void insertionSortDebug(int sortColumn = 2) {
        if (!head || !head->next || !head->next->next) return;
        
        cout << "\n=== INSERTION SORT DEBUG (Column " << sortColumn << ") ===" << endl;
        swapCount = 0;
        auto start = high_resolution_clock::now();
        
        Node* current = head->next->next;
        int elementCount = 0;
        
        while (current != nullptr) {
            elementCount++;
            vector<string> key = current->data;
            Node* j = current->prev;
            int shifts = 0;
            
            cout << "Element " << elementCount << ": key = " 
                 << (key.size() > sortColumn ? key[sortColumn] : "N/A") << endl;
            
            while (j != head && j->data.size() > sortColumn && 
                   key.size() > sortColumn && j->data[sortColumn] > key[sortColumn]) {
                cout << "  Shifting: " << j->data[sortColumn] << " > " << key[sortColumn] << endl;
                j->next->data = j->data;
                j = j->prev;
                shifts++;
                swapCount++;
            }
            
            j->next->data = key;
            cout << "  Shifts for this element: " << shifts << endl;
            current = current->next;
        }
        
        auto end = high_resolution_clock::now();
        auto duration = duration_cast<microseconds>(end - start);
        
        cout << "Sort completed!" << endl;
        cout << "Total swaps: " << swapCount << endl;
        cout << "Time taken: " << duration.count() << " microseconds" << endl;
    }
    
    // Simple array-based insertion sort for comparison
    void insertionSortSimple(int sortColumn = 2) {
        if (!head || !head->next) return;
        
        cout << "\n=== SIMPLE INSERTION SORT (Column " << sortColumn << ") ===" << endl;
        swapCount = 0;
        auto start = high_resolution_clock::now();
        
        // Convert linked list to vector for simpler sorting
        vector<vector<string>> data;
        Node* temp = head->next; // Skip header
        while (temp != nullptr) {
            data.push_back(temp->data);
            temp = temp->next;
        }
        
        // Perform insertion sort on the vector
        for (int i = 1; i < data.size(); i++) {
            vector<string> key = data[i];
            int j = i - 1;
            
            while (j >= 0 && data[j].size() > sortColumn && 
                   key.size() > sortColumn && data[j][sortColumn] > key[sortColumn]) {
                data[j + 1] = data[j];
                j--;
                swapCount++;
            }
            data[j + 1] = key;
        }
        
        // Copy sorted data back to linked list
        temp = head->next;
        for (int i = 0; i < data.size() && temp != nullptr; i++) {
            temp->data = data[i];
            temp = temp->next;
        }
        
        auto end = high_resolution_clock::now();
        auto duration = duration_cast<microseconds>(end - start);
        
        cout << "Sort completed!" << endl;
        cout << "Number of swaps: " << swapCount << endl;
        cout << "Time taken: " << duration.count() << " microseconds" << endl;
    }
    
    int getRecordCount() { return rowCount; }
    int getSwapCount() { return swapCount; }
};

void printMenu() {
    cout << "\n=== MEMORY DATABASE WITH SORTING ALGORITHMS ===" << endl;
    cout << "1. Display records (first 10)" << endl;
    cout << "2. Bubble Sort by Age" << endl;
    cout << "3. Insertion Sort by Age" << endl;
    cout << "4. Insertion Sort (Debug) by Age" << endl;
    cout << "5. Simple Insertion Sort by Age" << endl;
    cout << "6. Bubble Sort by Passed Status" << endl;
    cout << "7. Insertion Sort by Passed Status" << endl;
    cout << "8. Export sorted data to CSV" << endl;
    cout << "9. Reload from CSV" << endl;
    cout << "10. Performance Comparison" << endl;
    cout << "11. Exit" << endl;
    cout << "Enter your choice: ";
}

void runPerformanceTest() {
    cout << "\n=== PERFORMANCE COMPARISON ===" << endl;
    
    // Test Bubble Sort
    cout << "\n--- BUBBLE SORT ---" << endl;
    DoublyLinkedList db1;
    db1.loadFromCSV("student-data.csv");
    db1.bubbleSort(2);
    
    // Test Insertion Sort
    cout << "\n--- INSERTION SORT ---" << endl;
    DoublyLinkedList db2;
    db2.loadFromCSV("student-data.csv");
    db2.insertionSort(2);
    
    // Test Simple Insertion Sort
    cout << "\n--- SIMPLE INSERTION SORT ---" << endl;
    DoublyLinkedList db3;
    db3.loadFromCSV("student-data.csv");
    db3.insertionSortSimple(2);
    
    cout << "\n=== RESULTS ===" << endl;
    cout << "Bubble Sort: " << db1.getSwapCount() << " swaps" << endl;
    cout << "Insertion Sort: " << db2.getSwapCount() << " swaps" << endl;
    cout << "Simple Insertion Sort: " << db3.getSwapCount() << " swaps" << endl;
}

int main() {
    DoublyLinkedList db;
    string input;
    
    cout << "=== MEMORY DATABASE WITH SORTING ALGORITHMS ===" << endl;
    cout << "Loading data from student-data.csv..." << endl;
    db.loadFromCSV("student-data.csv");
    
    int choice;
    do {
        printMenu();
        getline(cin, input);
        try {
            choice = input.empty() ? 0 : stoi(input);
        } catch (const exception& e) {
            choice = 0;
        }
        
        switch (choice) {
            case 1: db.display(); break;
            case 2: 
                db.loadFromCSV("student-data.csv");
                db.bubbleSort(2);
                db.display(10);
                break;
            case 3:
                db.loadFromCSV("student-data.csv");
                db.insertionSort(2);
                db.display(10);
                break;
            case 4:
                db.loadFromCSV("student-data.csv");
                db.insertionSortDebug(2);
                db.display(10);
                break;
            case 5:
                db.loadFromCSV("student-data.csv");
                db.insertionSortSimple(2);
                db.display(10);
                break;
            case 6:
                db.loadFromCSV("student-data.csv");
                db.bubbleSort(30);
                db.display(10);
                break;
            case 7:
                db.loadFromCSV("student-data.csv");
                db.insertionSort(30);
                db.display(10);
                break;
            case 8:
                cout << "Enter output filename: ";
                getline(cin, input);
                db.exportToCSV(input.empty() ? "sorted_student-data.csv" : input);
                break;
            case 9:
                db.loadFromCSV("student-data.csv");
                break;
            case 10:
                runPerformanceTest();
                break;
            case 11:
                cout << "Exiting... Goodbye!" << endl;
                break;
            default:
                cout << "Invalid choice. Please try again." << endl;
                break;
        }
        
        if (choice != 11) {
            cout << "\nPress Enter to continue...";
            getline(cin, input);
        }
    } while (choice != 11);
    
    return 0;
}
