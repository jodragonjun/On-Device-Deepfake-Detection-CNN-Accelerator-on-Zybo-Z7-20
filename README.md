# FPGA-Based Fixed-Point CNN Inference Accelerator

This project implements a Verilog-2002 based fixed-point CNN inference accelerator for FPGA deployment.

## Architecture

Input Image  
→ Conv1 → ReLU → Pool1  
→ Conv2 → ReLU → Pool2  
→ Conv3 → ReLU → Pool3  
→ Flatten  
→ Dense1 → ReLU  
→ Dense2  
→ Threshold-based Binary Classification

## Repository Structure

- `rtl/` : Synthesizable Verilog-2002 RTL modules
- `tb/` : Testbenches for unit and integration verification
- `data/` : Fixed-point weights, biases, input images, and golden outputs
- `scripts/` : Python scripts for quantization and golden reference generation
- `docs/` : Architecture, verification, and synthesis reports
- `vivado/` : Constraint and project generation scripts

## Verification

The RTL output is verified layer-by-layer against Python golden reference outputs.
