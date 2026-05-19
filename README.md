# Deepfake Detection Accelerator on Zybo Z7-20

> From Python-trained CNN to Verilog RTL:  
> Hardware implementation of a WildDeepfake-based deepfake detector on FPGA

---

## Abstract

This project presents an end-to-end hardware implementation flow for a
deepfake image classification accelerator targeting the Zybo Z7-20 FPGA board.
A convolutional neural network is first trained in Python using the
WildDeepfake dataset, then converted into a hardware-oriented inference
architecture implemented in Verilog-RTL.

Unlike a pure software-based deepfake detector, this project focuses on mapping
the trained CNN model into a deterministic, cycle-level hardware pipeline.
The design follows a fully modular RTL hierarchy composed of convolution,
activation, pooling, memory, address-generation, and control blocks.

The objective is not only to classify real and fake facial images, but also to
demonstrate how an AI model can be transformed into an FPGA-deployable
accelerator through fixed-point representation, layer-wise verification,
stream-based dataflow, and synthesis-aware hardware design.

---

## Project Motivation

Deepfake detection is becoming increasingly important as synthetic facial media
becomes more realistic and accessible. However, deploying deepfake detectors on
edge devices requires more than model accuracy. It requires efficient hardware
execution, predictable latency, and resource-aware architecture.

This project explores that problem from a digital hardware design perspective:

- Train a CNN-based deepfake detector in Python
- Extract trained weights and biases into hardware-readable HEX format
- Reconstruct the inference path in Verilog RTL
- Verify each CNN stage against Python golden reference data
- Synthesize and implement the design on Zybo Z7-20
- Move toward real FPGA-based inference rather than software-only simulation

---

## Target Platform

| Item | Description |
|---|---|
| Board | Digilent Zybo Z7-20 |
| FPGA SoC | Xilinx Zynq-7000 XC7Z020 |
| HDL | Verilog-2001 |
| Toolchain | Xilinx Vivado |
| Dataset | WildDeepfake |
| Task | Real / Fake classification |
| Design Style | Modular RTL, FSM-based control, pipeline-oriented datapath |

---

## System Overview

```text
WildDeepfake Dataset
        |
        v
Python Training / Preprocessing
        |
        v
Weight & Bias Extraction
        |
        v
Fixed-Point / HEX Conversion
        |
        v
Verilog RTL CNN Accelerator
        |
        v
Simulation with Python Golden Reference
        |
        v
Vivado Synthesis / Implementation
        |
        v
Zybo Z7-20 FPGA Deployment
```

---

## Hardware Architecture

The CNN inference engine is designed as a hierarchical hardware pipeline.
Input Image ( PS )
    |
    v
Conv1  -> ReLU -> Pool1
    |
    v
Conv2  -> ReLU -> Pool2
    |
    v
Conv3  -> ReLU -> Pool3
    |
    v
Dense / Classifier
    |
    v
Real / Fake Prediction

Each layer is implemented as an independent RTL module and verified stage by
stage. The design avoids behavioral black-box modeling and follows synthesizable
Verilog-2001 coding rules.

---

## Verification Strategy

The RTL design is verified using a Python golden-reference flow.

For each CNN stage, the expected output is generated in Python and compared
against Verilog simulation output. Verification checks include:

Output feature-map count
Data correctness
Row / column / channel metadata correctness
X/Z unknown-state detection
Layer-by-layer consistency

Example verification result:

[TB DONE]
conv3 count          = 18432 / expected 18432
pool3 count          = 4608 / expected 4608
conv3 data err count = 0
pool3 data err count = 0
conv3 meta err count = 0
pool3 meta err count = 0
x/z err count        = 0
total err count      = 0

[PASS] Conv1 + Pool1 + Conv2 + Pool2 + Conv3 + Pool3 verification PASS

---

## Design Philosophy

This project is not a simple neural network demo.

It is a hardware reconstruction of a trained deepfake detector, built under
realistic FPGA constraints.

The design prioritizes:

Synthesizable Verilog-2001 RTL
Hierarchical module separation
FSM-based control structure
Stream-oriented feature-map movement
Layer-wise verification against software reference
Resource-aware FPGA implementation
Future extensibility toward pipelined inference


---

## Final Goal

The final goal of this project is to build a complete FPGA-based deepfake
detection accelerator that performs CNN inference on Zybo Z7-20 using weights
trained from the WildDeepfake dataset.

This repository documents the full transition from machine learning model to
digital hardware:

Dataset -> Python Model -> Fixed-Point Parameters -> RTL Modules -> Simulation Verification -> FPGA Implementation

The project aims to demonstrate practical AI semiconductor design capability by
bridging deep learning, digital logic design, and FPGA system implementation.
