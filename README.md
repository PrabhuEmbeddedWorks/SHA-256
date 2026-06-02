# SHA-256

## Overview

This project presents a **Dual-Thread Fine-Grained Pipelined (DT-FGP) SHA-256 Hardware Accelerator** implemented using **Verilog HDL** for FPGA platforms.

The proposed architecture addresses performance limitations of conventional SHA-256 hardware implementations by introducing:

- Dual-thread interleaved execution
- Fine-grained pipelined datapath
- Shared datapath resource utilization
- Hazard-aware scheduling
- Optimized arithmetic units using 4:2 compressors

The design targets **Xilinx FPGA platforms** and is validated using **Vivado Design Suite 2025.2**.

---

## Project Objectives

The objectives of this project are:

- Study performance limitations of conventional SHA-256 hardware architectures.
- Improve SHA-256 throughput without multicore hardware replication.
- Implement a dual-thread pipelined FPGA architecture.
- Reduce critical path delay using arithmetic optimization.
- Maintain balanced throughput, area utilization, and power efficiency.

---

## Architecture Overview

The DT-FGP SHA-256 architecture consists of:

### 1. Dual-Thread Execution Engine
Two independent message streams are processed concurrently.

- Thread A
- Thread B

Interleaved scheduling enables continuous pipeline utilization.

### 2. Fine-Grained Pipelined Datapath

The SHA-256 round function is divided into:

- Stage 1 : Round Logic Computation
- Stage 2 : Round Completion & Register Update

Pipeline separation eliminates long combinational critical paths.

### 3. Shared Datapath Architecture

Instead of duplicating complete SHA-256 cores, both threads share:

- Arithmetic units
- Compression logic
- Control resources

This reduces FPGA resource overhead.

### 4. Optimized Arithmetic Structure

The design employs:

- 4:2 Compressors
- Cascaded 3:2 Adders
- Shifted Carry Propagation

to reduce addition chain delay.

### 5. Control Logic

Centralized FSM-based control manages:

- Initialization
- Thread scheduling
- Round progression
- Final hash accumulation

---

## Technologies Used

| Category | Tool / Technology |
|----------|------------------|
| HDL | Verilog HDL |
| FPGA Toolchain | Xilinx Vivado 2025.2 |
| Simulation | Vivado Simulator |
| Verification | NIST SHA-256 Test Vectors |
| FPGA Platforms | Artix-7, Kintex UltraScale+ |

---

## Project File Structure
```text
SHA256-FPGA/
│
│
├── Codes_Vivado/
│   ├── compressor_4to2.v
│   ├── sha256_k_constants.v
│   ├── sha256_novel_core.v
│   ├── sha256_novel_top.v
│   ├── sha256_novel_wrapper.v
│   ├── sha256_w_mem_novel.v
│   └── tb_sha256_novel.v
│
├── Results/
│   │
│   ├── Artix/
│   │   ├── Power.txt
│   │   ├── Timing summary.txt
│   │   └── Utilization.txt
│   │
│   └── Kintex Ultrascale/
│       ├── Power.txt
│       ├── Timing summary.txt
│       └── Utilization.txt

```
### File Description

| File                         | Purpose                      |
| ---------------------------- | ---------------------------- |
| `compressor_4to2.v`          | 4:2 Compressor Module        |
| `sha256_k_constants.v`       | SHA-256 Round Constants      |
| `sha256_novel_core.v`        | DT-FGP SHA-256 Core          |
| `sha256_novel_top.v`         | Top-Level Integration Module |
| `sha256_novel_wrapper.v`     | FPGA Interface Wrapper       |
| `sha256_w_mem_novel.v`       | Message Scheduler            |
| `tb_sha256_novel.v`          | Verification Testbench       |
| `Results/Artix/`             | Artix-7 Reports              |
| `Results/Kintex_UltraScale/` | Kintex UltraScale+ Reports   |


## Expected Output

Example SHA-256 Output:

Input:
abc

Output:
BA7816BF8F01CFEA414140DE5DAE2223
