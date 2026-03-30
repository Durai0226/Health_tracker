import '../../../exam_prep/models/study_material_model.dart';

/// Comprehensive study materials for GATE (Computer Science)
final List<StudyMaterial> gateStudyMaterials = [
  // ==================== DATA STRUCTURES ====================
  
  StudyMaterial(
    id: 'gate_ds_arrays_linked_lists',
    title: 'Arrays & Linked Lists',
    description: 'Fundamentals, operations, and complexity analysis',
    subjectId: 'data_structures',
    topicId: 'arrays_lists',
    type: StudyMaterialType.notes,
    content: '''
# Arrays & Linked Lists for GATE

## Arrays

### Definition
Contiguous memory allocation for homogeneous elements.

### Time Complexity
| Operation | Time |
|-----------|------|
| Access by index | O(1) |
| Search (unsorted) | O(n) |
| Search (sorted) | O(log n) |
| Insertion at end | O(1) |
| Insertion at position | O(n) |
| Deletion | O(n) |

### 2D Arrays

**Row-major order**
Address(A[i][j]) = Base + ((i × cols) + j) × size

**Column-major order**
Address(A[i][j]) = Base + ((j × rows) + i) × size

## Linked Lists

### Types
1. **Singly Linked List**: Next pointer only
2. **Doubly Linked List**: Next and Prev pointers
3. **Circular Linked List**: Last node points to first

### Time Complexity
| Operation | Singly | Doubly |
|-----------|--------|--------|
| Access | O(n) | O(n) |
| Search | O(n) | O(n) |
| Insert at head | O(1) | O(1) |
| Insert at tail | O(n)/O(1)* | O(1) |
| Delete at head | O(1) | O(1) |
| Delete at tail | O(n) | O(1) |
*O(1) if tail pointer maintained

### Advantages over Arrays
- Dynamic size
- Easy insertion/deletion
- No memory wastage

### Disadvantages
- Extra memory for pointers
- No random access
- Not cache friendly

## Common Operations

### Reverse a Linked List
```
prev = null, curr = head
while curr:
    next = curr.next
    curr.next = prev
    prev = curr
    curr = next
return prev
```

### Detect Cycle (Floyd's Algorithm)
- Slow pointer: 1 step
- Fast pointer: 2 steps
- If they meet, cycle exists

### Find Middle Element
- Slow: 1 step, Fast: 2 steps
- When fast reaches end, slow is at middle

## GATE Important Points
1. Memory calculation for arrays
2. Pointer manipulation in linked lists
3. Time complexity comparisons
4. Space overhead analysis
''',
    tags: ['arrays', 'linked lists', 'data structures', 'gate'],
    estimatedReadTime: 12,
    createdAt: DateTime(2024, 1, 15),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'gate_ds_trees',
    title: 'Trees - Binary Trees & BST',
    description: 'Tree traversals, BST operations, balanced trees',
    subjectId: 'data_structures',
    topicId: 'trees',
    type: StudyMaterialType.notes,
    content: '''
# Trees for GATE

## Binary Tree Basics

### Properties
- Max nodes at level i: 2^i
- Max nodes in tree of height h: 2^(h+1) - 1
- Min height for n nodes: ⌊log₂n⌋
- Number of leaves in full BT with n internal nodes: n + 1

### Types
- **Full/Proper**: Every node has 0 or 2 children
- **Complete**: All levels filled except possibly last (left-filled)
- **Perfect**: All internal nodes have 2 children, all leaves at same level
- **Skewed**: All nodes have only one child

## Tree Traversals

### Depth-First
| Traversal | Order | Use Case |
|-----------|-------|----------|
| Inorder | Left, Root, Right | BST sorted order |
| Preorder | Root, Left, Right | Copy tree, prefix expression |
| Postorder | Left, Right, Root | Delete tree, postfix expression |

### Breadth-First (Level Order)
Use queue: Enqueue root, then for each node, dequeue, visit, enqueue children.

### Traversal from Two Others
- Inorder + Preorder → Unique tree
- Inorder + Postorder → Unique tree
- Preorder + Postorder → NOT unique (need inorder)

## Binary Search Tree (BST)

### Property
Left subtree < Root < Right subtree (for all nodes)

### Operations Complexity
| Operation | Average | Worst (Skewed) |
|-----------|---------|----------------|
| Search | O(log n) | O(n) |
| Insert | O(log n) | O(n) |
| Delete | O(log n) | O(n) |

### Deletion Cases
1. **Leaf node**: Simply remove
2. **One child**: Replace with child
3. **Two children**: Replace with inorder successor/predecessor

## AVL Trees

### Balance Factor
BF = Height(Left) - Height(Right)
Must be -1, 0, or 1 for all nodes.

### Rotations
| Imbalance | Rotation |
|-----------|----------|
| LL | Right rotation |
| RR | Left rotation |
| LR | Left-Right rotation |
| RL | Right-Left rotation |

### Height Bounds
For n nodes: h ≤ 1.44 log₂(n+2)

## Red-Black Trees

### Properties
1. Every node is red or black
2. Root is black
3. Leaves (NIL) are black
4. Red node has black children
5. All paths have same black height

### Height Bound
h ≤ 2 log₂(n+1)

## B-Trees

### Properties (Order m)
- Root: 1 to m-1 keys
- Internal nodes: ⌈m/2⌉-1 to m-1 keys
- All leaves at same level

### Operations
All operations: O(log n)

## Heap

### Types
- **Max Heap**: Parent ≥ Children
- **Min Heap**: Parent ≤ Children

### Array Representation
- Parent(i) = (i-1)/2
- Left(i) = 2i + 1
- Right(i) = 2i + 2

### Complexity
| Operation | Time |
|-----------|------|
| Build Heap | O(n) |
| Insert | O(log n) |
| Extract Max/Min | O(log n) |
| Heapify | O(log n) |
''',
    tags: ['trees', 'bst', 'avl', 'heap', 'gate'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 16),
    rating: 4.9,
  ),

  // ==================== ALGORITHMS ====================
  
  StudyMaterial(
    id: 'gate_algo_sorting',
    title: 'Sorting Algorithms - Complete Analysis',
    description: 'All sorting algorithms with complexity analysis',
    subjectId: 'algorithms',
    topicId: 'sorting',
    type: StudyMaterialType.notes,
    content: '''
# Sorting Algorithms for GATE

## Comparison-Based Sorting

### Bubble Sort
- Compare adjacent, swap if needed
- Time: O(n²), Space: O(1)
- Stable, In-place
- Best case (sorted): O(n) with optimization

### Selection Sort
- Find minimum, place at beginning
- Time: O(n²) always, Space: O(1)
- Not stable, In-place
- Minimum swaps: O(n)

### Insertion Sort
- Insert each element in sorted portion
- Time: O(n²), Best: O(n), Space: O(1)
- Stable, In-place
- Good for small or nearly sorted data

### Merge Sort
- Divide and conquer
- Time: O(n log n) always, Space: O(n)
- Stable, Not in-place
- Recurrence: T(n) = 2T(n/2) + O(n)

### Quick Sort
- Partition around pivot
- Time: Average O(n log n), Worst O(n²)
- Not stable, In-place
- Recurrence: T(n) = T(k) + T(n-k-1) + O(n)

### Heap Sort
- Build max-heap, extract max repeatedly
- Time: O(n log n) always, Space: O(1)
- Not stable, In-place

## Comparison Summary

| Algorithm | Best | Average | Worst | Space | Stable |
|-----------|------|---------|-------|-------|--------|
| Bubble | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Selection | O(n²) | O(n²) | O(n²) | O(1) | No |
| Insertion | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Merge | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes |
| Quick | O(n log n) | O(n log n) | O(n²) | O(log n) | No |
| Heap | O(n log n) | O(n log n) | O(n log n) | O(1) | No |

## Non-Comparison Sorting

### Counting Sort
- Count occurrences, calculate positions
- Time: O(n + k), Space: O(k)
- k = range of input
- Stable

### Radix Sort
- Sort by digits (LSD or MSD)
- Time: O(d(n + k)), Space: O(n + k)
- d = number of digits, k = base
- Stable

### Bucket Sort
- Distribute into buckets, sort each
- Time: Average O(n + k), Worst O(n²)
- Space: O(n)
- Useful for uniformly distributed data

## Lower Bound

**Comparison-based sorting lower bound: Ω(n log n)**

Decision tree argument: n! permutations require log₂(n!) comparisons.
log₂(n!) = Θ(n log n)

## GATE Important Points

1. **Stability**: Merge sort, Insertion sort, Bubble sort, Counting sort
2. **In-place**: Quick sort, Heap sort, Selection sort, Insertion sort
3. **Best for nearly sorted**: Insertion sort O(n)
4. **Worst case guarantee**: Merge sort, Heap sort
5. **Cache efficient**: Quick sort (good locality)
''',
    tags: ['sorting', 'algorithms', 'complexity', 'gate'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 17),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'gate_algo_graphs',
    title: 'Graph Algorithms',
    description: 'BFS, DFS, shortest paths, MST algorithms',
    subjectId: 'algorithms',
    topicId: 'graphs',
    type: StudyMaterialType.notes,
    content: '''
# Graph Algorithms for GATE

## Graph Representations

### Adjacency Matrix
- Space: O(V²)
- Edge check: O(1)
- Good for dense graphs

### Adjacency List
- Space: O(V + E)
- Edge check: O(degree)
- Good for sparse graphs

## Traversals

### BFS (Breadth-First Search)
- Uses Queue
- Time: O(V + E)
- Applications: Shortest path (unweighted), level order

### DFS (Depth-First Search)
- Uses Stack (or recursion)
- Time: O(V + E)
- Applications: Cycle detection, topological sort, connected components

### DFS Edge Classification
| Edge Type | Tree | Condition |
|-----------|------|-----------|
| Tree Edge | Forms DFS tree | First visit |
| Back Edge | To ancestor | Creates cycle |
| Forward Edge | To descendant | - |
| Cross Edge | To non-ancestor/descendant | - |

## Shortest Path Algorithms

### Dijkstra's Algorithm
- **Constraint**: Non-negative weights
- **Time**: O((V + E) log V) with min-heap
- **Approach**: Greedy, relaxation

### Bellman-Ford Algorithm
- **Constraint**: Can handle negative weights
- **Time**: O(VE)
- **Detects**: Negative weight cycles
- **Approach**: Relax all edges V-1 times

### Floyd-Warshall Algorithm
- **Purpose**: All pairs shortest path
- **Time**: O(V³)
- **Space**: O(V²)
- **DP recurrence**: d[i][j] = min(d[i][j], d[i][k] + d[k][j])

## Minimum Spanning Tree

### Properties
- V-1 edges for V vertices
- No cycles
- Minimum total weight

### Prim's Algorithm
- Start from any vertex
- Add minimum weight edge to MST
- Time: O(E log V) with binary heap
- Better for dense graphs

### Kruskal's Algorithm
- Sort all edges
- Add edges if no cycle (use Union-Find)
- Time: O(E log E)
- Better for sparse graphs

## Topological Sort

### Conditions
- DAG (Directed Acyclic Graph) required
- Multiple valid orderings possible

### Algorithms
1. **DFS-based**: Reverse of finish times
2. **Kahn's (BFS)**: Process vertices with in-degree 0

## Strongly Connected Components

### Kosaraju's Algorithm
1. DFS on original graph, store finish order
2. Transpose graph
3. DFS on transpose in reverse finish order

### Tarjan's Algorithm
- Single DFS with low-link values
- Time: O(V + E)

## Important Formulas

### Tree (Connected Graph)
- Edges = V - 1
- Adding any edge creates exactly one cycle

### Complete Graph
- Edges = V(V-1)/2
- Each vertex: degree V-1

### Bipartite Graph
- No odd-length cycles
- 2-colorable
- Check: BFS/DFS coloring
''',
    tags: ['graphs', 'bfs', 'dfs', 'dijkstra', 'mst', 'gate'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 18),
    rating: 4.9,
  ),

  // ==================== OPERATING SYSTEMS ====================
  
  StudyMaterial(
    id: 'gate_os_process',
    title: 'Process Management & Scheduling',
    description: 'Process states, scheduling algorithms, synchronization',
    subjectId: 'operating_systems',
    topicId: 'process_management',
    type: StudyMaterialType.notes,
    content: '''
# Process Management for GATE

## Process States

### 5-State Model
New → Ready → Running → Waiting → Terminated

### Transitions
- **Admit**: New → Ready
- **Dispatch**: Ready → Running
- **Interrupt**: Running → Ready
- **I/O Wait**: Running → Waiting
- **I/O Complete**: Waiting → Ready
- **Exit**: Running → Terminated

## Process Control Block (PCB)

### Contents
- Process ID
- Process state
- Program counter
- CPU registers
- Memory management info
- I/O status
- Accounting info

## CPU Scheduling

### Criteria
- **CPU Utilization**: Keep CPU busy
- **Throughput**: Processes completed per time
- **Turnaround Time**: Submission to completion
- **Waiting Time**: Time in ready queue
- **Response Time**: Submission to first response

### Scheduling Algorithms

#### FCFS (First Come First Serve)
- Non-preemptive
- Simple, high waiting time
- Convoy effect problem

#### SJF (Shortest Job First)
- Non-preemptive
- Optimal average waiting time
- Starvation possible

#### SRTF (Shortest Remaining Time First)
- Preemptive SJF
- Optimal for average waiting time
- High overhead

#### Round Robin
- Preemptive, time quantum
- Fair, good response time
- Context switch overhead

#### Priority Scheduling
- Higher priority first
- Starvation possible (solved by aging)
- Can be preemptive or non-preemptive

### Formulas
- **Turnaround Time** = Completion - Arrival
- **Waiting Time** = Turnaround - Burst
- **Response Time** = First Run - Arrival

## Process Synchronization

### Critical Section Problem

**Requirements:**
1. **Mutual Exclusion**: One process at a time
2. **Progress**: No unnecessary blocking
3. **Bounded Waiting**: No starvation

### Peterson's Solution (2 processes)
```
flag[i] = true
turn = j
while (flag[j] && turn == j);
// Critical section
flag[i] = false
```

### Semaphores

**Types:**
- **Binary** (Mutex): 0 or 1
- **Counting**: Integer value

**Operations:**
- **wait(S)** / P(S): Decrement, block if < 0
- **signal(S)** / V(S): Increment, unblock if waiting

### Classic Problems

#### Producer-Consumer
- Buffer, mutex, full/empty semaphores
- Bounded buffer variant

#### Readers-Writers
- Multiple readers OR one writer
- Reader/Writer preference variants

#### Dining Philosophers
- 5 philosophers, 5 forks
- Deadlock prevention needed

## Deadlock

### Conditions (All Required)
1. **Mutual Exclusion**
2. **Hold and Wait**
3. **No Preemption**
4. **Circular Wait**

### Handling
1. **Prevention**: Remove one condition
2. **Avoidance**: Banker's algorithm
3. **Detection**: Resource allocation graph
4. **Recovery**: Terminate or preempt
''',
    tags: ['os', 'process', 'scheduling', 'synchronization', 'gate'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 19),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'gate_os_memory',
    title: 'Memory Management',
    description: 'Paging, segmentation, virtual memory',
    subjectId: 'operating_systems',
    topicId: 'memory_management',
    type: StudyMaterialType.notes,
    content: '''
# Memory Management for GATE

## Memory Hierarchy
Registers → Cache → Main Memory → Secondary Storage
(Faster/Smaller ←→ Slower/Larger)

## Address Binding

### Compile Time
- Absolute addresses generated
- Must recompile if location changes

### Load Time
- Relocatable code generated
- Addresses bound at loading

### Execution Time
- Addresses bound during execution
- Requires hardware support (MMU)

## Contiguous Allocation

### Fixed Partitioning
- Equal or unequal partitions
- Internal fragmentation

### Variable Partitioning
- Partitions created as needed
- External fragmentation

### Allocation Strategies
| Strategy | Description |
|----------|-------------|
| First Fit | First hole that fits |
| Best Fit | Smallest adequate hole |
| Worst Fit | Largest hole |

## Paging

### Concept
- Physical: Frames
- Logical: Pages
- No external fragmentation
- Internal fragmentation (last page)

### Address Translation
- Logical: Page Number + Page Offset
- Physical: Frame Number + Frame Offset

**Page number bits** = log₂(Number of pages)
**Offset bits** = log₂(Page size)

### Page Table Entry
- Frame number
- Valid/Invalid bit
- Protection bits
- Dirty bit
- Reference bit

### Multi-level Paging
Reduces page table size
- Two-level: Outer page table → Inner page table → Frame
- Memory accesses: levels + 1

### TLB (Translation Lookaside Buffer)
- Cache for page table entries
- Hit: 1 memory access
- Miss: levels + 2 accesses

**Effective Access Time (EAT)**
EAT = hit_ratio × (TLB + mem) + (1 - hit_ratio) × (TLB + n × mem)

## Segmentation

### Concept
- Logical division (code, data, stack)
- Variable size segments
- External fragmentation

### Segment Table
- Base address
- Limit (size)

### Address Translation
Logical: (segment, offset)
Physical: base[segment] + offset (if offset < limit)

## Virtual Memory

### Demand Paging
- Pages loaded only when needed
- Page fault on invalid access

### Page Replacement Algorithms

| Algorithm | Description | Belady's Anomaly |
|-----------|-------------|------------------|
| FIFO | Replace oldest | Yes |
| LRU | Replace least recently used | No |
| Optimal | Replace farthest future use | No |
| Clock | Circular queue with use bit | - |

### Thrashing
- Excessive paging
- CPU utilization drops
- Solution: Decrease multiprogramming

### Working Set Model
- Pages used in last Δ time units
- Keep working set in memory

### Page Fault Calculation
**Effective Access Time**
EAT = (1 - p) × ma + p × page_fault_time
- p = page fault rate
- ma = memory access time
''',
    tags: ['os', 'memory', 'paging', 'virtual memory', 'gate'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 20),
    rating: 4.8,
  ),

  // ==================== DBMS ====================
  
  StudyMaterial(
    id: 'gate_dbms_normalization',
    title: 'Normalization & Normal Forms',
    description: 'Functional dependencies, 1NF to BCNF',
    subjectId: 'dbms',
    topicId: 'normalization',
    type: StudyMaterialType.notes,
    content: '''
# Normalization for GATE

## Functional Dependency (FD)

### Definition
X → Y means: If two tuples have same X, they have same Y.

### Armstrong's Axioms
1. **Reflexivity**: If Y ⊆ X, then X → Y
2. **Augmentation**: If X → Y, then XZ → YZ
3. **Transitivity**: If X → Y and Y → Z, then X → Z

### Derived Rules
- **Union**: X → Y, X → Z ⟹ X → YZ
- **Decomposition**: X → YZ ⟹ X → Y, X → Z
- **Pseudo-transitivity**: X → Y, WY → Z ⟹ WX → Z

## Keys

### Definitions
- **Super Key**: Uniquely identifies tuples
- **Candidate Key**: Minimal super key
- **Primary Key**: Chosen candidate key
- **Prime Attribute**: Part of any candidate key
- **Non-prime Attribute**: Not part of any candidate key

### Finding Candidate Keys
1. Find attributes not in RHS of any FD (must be in key)
2. Find closure of these attributes
3. If closure = all attributes, done
4. Otherwise, try adding other attributes

## Normal Forms

### 1NF (First Normal Form)
- Atomic values only
- No repeating groups
- No multi-valued attributes

### 2NF (Second Normal Form)
- In 1NF
- No partial dependency
- Non-prime attributes fully dependent on entire candidate key

### 3NF (Third Normal Form)
- In 2NF
- No transitive dependency
- For X → A: X is superkey OR A is prime

### BCNF (Boyce-Codd Normal Form)
- In 3NF
- For X → A: X must be superkey
- Stronger than 3NF

### Summary
| NF | Condition |
|----|-----------|
| 1NF | Atomic values |
| 2NF | 1NF + No partial dependency |
| 3NF | 2NF + No transitive dependency |
| BCNF | Every determinant is superkey |

## Decomposition

### Properties
1. **Lossless Join**: Original relation recoverable
2. **Dependency Preserving**: All FDs enforceable

### Lossless Join Test
Decomposition of R into R1, R2 is lossless if:
R1 ∩ R2 → R1 OR R1 ∩ R2 → R2

### BCNF Decomposition
- Always lossless
- May not preserve dependencies

### 3NF Decomposition
- Always lossless (with synthesis algorithm)
- Always dependency preserving

## Closure & Canonical Cover

### Attribute Closure (X⁺)
Set of all attributes determined by X.

### Canonical Cover
- Minimal equivalent set of FDs
- No extraneous attributes
- Single attribute on RHS

## GATE Tips
1. Practice finding candidate keys
2. Identify partial vs transitive dependencies
3. Check lossless join condition
4. Know when to use 3NF vs BCNF decomposition
''',
    tags: ['dbms', 'normalization', 'functional dependency', 'gate'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 21),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'gate_dbms_transactions',
    title: 'Transactions & Concurrency Control',
    description: 'ACID properties, schedules, locking protocols',
    subjectId: 'dbms',
    topicId: 'transactions',
    type: StudyMaterialType.notes,
    content: '''
# Transactions & Concurrency for GATE

## ACID Properties

| Property | Description |
|----------|-------------|
| **Atomicity** | All or nothing |
| **Consistency** | Valid state to valid state |
| **Isolation** | Concurrent = Serial execution |
| **Durability** | Committed changes persist |

## Transaction States

New → Active → Partially Committed → Committed
          ↓              ↓
       Failed ←──────────┘
          ↓
       Aborted

## Schedules

### Types
- **Serial**: No interleaving
- **Concurrent**: Interleaved operations

### Serializability
Schedule is correct if equivalent to some serial schedule.

### Conflict Serializability
Two operations conflict if:
1. Different transactions
2. Same data item
3. At least one is write

**Test**: Construct precedence graph
- No cycle → Conflict serializable
- Topological order gives equivalent serial schedule

### View Serializability
- Considers read-from relationships
- Initial reads, final writes
- Weaker than conflict serializability

## Recoverability

### Recoverable Schedule
If Ti reads from Tj, then Tj commits before Ti.

### Cascadeless Schedule
Read only committed data.

### Strict Schedule
Write only after previous writer commits.

Strict ⊂ Cascadeless ⊂ Recoverable

## Concurrency Control

### Lock-Based Protocols

#### Types of Locks
- **Shared (S)**: Read lock, multiple allowed
- **Exclusive (X)**: Write lock, only one allowed

#### Lock Compatibility
|     | S | X |
|-----|---|---|
| S   | ✓ | ✗ |
| X   | ✗ | ✗ |

### Two-Phase Locking (2PL)
1. **Growing Phase**: Acquire locks only
2. **Shrinking Phase**: Release locks only

Guarantees conflict serializability.

### Strict 2PL
Hold all exclusive locks until commit/abort.
Prevents cascading rollback.

### Deadlock Handling

**Prevention:**
- Wait-Die: Older waits, younger aborts
- Wound-Wait: Older wounds, younger waits

**Detection:**
- Wait-for graph
- Cycle = Deadlock

## Timestamp-Based Protocols

### Rules
- Each transaction has timestamp TS(Ti)
- Each data item has W-TS, R-TS

### Thomas Write Rule
If TS(Ti) < W-TS(Q), ignore write (outdated).

## Isolation Levels

| Level | Dirty Read | Non-repeatable | Phantom |
|-------|------------|----------------|---------|
| Read Uncommitted | ✓ | ✓ | ✓ |
| Read Committed | ✗ | ✓ | ✓ |
| Repeatable Read | ✗ | ✗ | ✓ |
| Serializable | ✗ | ✗ | ✗ |

## Recovery

### Log-Based Recovery
- Write-Ahead Logging (WAL)
- Log record before data modification

### Operations
- **REDO**: Apply committed changes
- **UNDO**: Reverse uncommitted changes

### Checkpointing
- Reduces recovery time
- Fuzzy vs Sharp checkpoints
''',
    tags: ['dbms', 'transactions', 'acid', 'concurrency', 'gate'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 22),
    rating: 4.8,
  ),

  // ==================== COMPUTER NETWORKS ====================
  
  StudyMaterial(
    id: 'gate_cn_layers',
    title: 'Network Layers & Protocols',
    description: 'OSI model, TCP/IP, protocols at each layer',
    subjectId: 'computer_networks',
    topicId: 'network_layers',
    type: StudyMaterialType.notes,
    content: '''
# Computer Networks for GATE

## OSI Model (7 Layers)

| Layer | Name | PDU | Function |
|-------|------|-----|----------|
| 7 | Application | Data | User interface |
| 6 | Presentation | Data | Format, encryption |
| 5 | Session | Data | Dialog control |
| 4 | Transport | Segment | End-to-end delivery |
| 3 | Network | Packet | Routing |
| 2 | Data Link | Frame | Node-to-node delivery |
| 1 | Physical | Bit | Transmission medium |

## TCP/IP Model (4 Layers)

| Layer | Protocols |
|-------|-----------|
| Application | HTTP, FTP, SMTP, DNS |
| Transport | TCP, UDP |
| Internet | IP, ICMP, ARP |
| Network Access | Ethernet, WiFi |

## Data Link Layer

### Framing
- Character count
- Byte stuffing
- Bit stuffing

### Error Detection
- **Parity**: Single bit error
- **Checksum**: Sum of segments
- **CRC**: Polynomial division

### Flow Control
- **Stop-and-Wait**: One frame at a time
- **Sliding Window**: Multiple frames

### Sliding Window Protocols
| Protocol | Window Size | Efficiency |
|----------|-------------|------------|
| Stop-and-Wait | 1 | 1/(1+2a) |
| Go-Back-N | N | N/(1+2a) if N ≥ 1+2a |
| Selective Repeat | N | N/(1+2a) if N ≥ 1+2a |

a = propagation delay / transmission delay

### Window Size Limits
- Go-Back-N: N ≤ 2ⁿ - 1
- Selective Repeat: N ≤ 2ⁿ⁻¹

## Network Layer

### IPv4 Addressing
- 32-bit address
- Classes: A (1-126), B (128-191), C (192-223)

### Subnetting
- CIDR notation: IP/prefix
- Subnet mask determines network portion
- Hosts = 2^(32-prefix) - 2

### Routing Protocols
| Protocol | Type | Algorithm |
|----------|------|-----------|
| RIP | Distance Vector | Bellman-Ford |
| OSPF | Link State | Dijkstra |
| BGP | Path Vector | Policy-based |

### IP Header Fields
- Version, Header Length, TOS
- Total Length, ID
- Flags, Fragment Offset
- TTL, Protocol
- Header Checksum
- Source/Destination IP

## Transport Layer

### TCP vs UDP
| Feature | TCP | UDP |
|---------|-----|-----|
| Connection | Connection-oriented | Connectionless |
| Reliability | Reliable | Unreliable |
| Ordering | Ordered | Unordered |
| Header | 20-60 bytes | 8 bytes |
| Flow Control | Yes | No |

### TCP Connection
- 3-way handshake (SYN, SYN-ACK, ACK)
- 4-way termination (FIN, ACK, FIN, ACK)

### TCP Congestion Control
1. **Slow Start**: cwnd doubles per RTT
2. **Congestion Avoidance**: cwnd += 1 per RTT
3. **Fast Retransmit**: 3 duplicate ACKs
4. **Fast Recovery**: cwnd = ssthresh + 3

## Application Layer

### DNS
- Hierarchical naming
- Iterative vs Recursive queries
- Port 53

### HTTP
- Stateless protocol
- Methods: GET, POST, PUT, DELETE
- Port 80 (443 for HTTPS)

### Important Port Numbers
| Protocol | Port |
|----------|------|
| HTTP | 80 |
| HTTPS | 443 |
| FTP | 20/21 |
| SSH | 22 |
| Telnet | 23 |
| SMTP | 25 |
| DNS | 53 |
''',
    tags: ['networks', 'osi', 'tcp ip', 'protocols', 'gate'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 23),
    rating: 4.9,
  ),
];
