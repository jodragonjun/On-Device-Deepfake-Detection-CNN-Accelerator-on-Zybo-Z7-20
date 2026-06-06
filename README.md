# On-Device Deepfake Detection CNN Accelerator on Zybo Z7-20

<p align="center">
  <b>On-Device AI · FPGA CNN Accelerator · Verilog-2001 RTL · Deepfake Detection</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/HDL-Verilog--2001-blue">
  <img src="https://img.shields.io/badge/Board-Zybo%20Z7--20-green">
  <img src="https://img.shields.io/badge/FPGA-Zynq--7000-orange">
  <img src="https://img.shields.io/badge/Task-Deepfake%20Detection-red">
  <img src="https://img.shields.io/badge/Design-Modular%20RTL-purple">
</p>

> From Python-trained CNN to synthesizable Verilog RTL  
> A modular FPGA-based deepfake detection accelerator for on-device real/fake image classification

---

## Overview

This project implements an end-to-end FPGA-based deepfake image classification accelerator on the **Digilent Zybo Z7-20** board.

A lightweight CNN model is trained in Python using the **WildDeepfake** dataset, quantized into fixed-point representation, exported as hardware-readable HEX files, and reconstructed as a fully synthesizable **Verilog-2001 RTL** design.

The objective of this project is not simply to run a neural network model, but to demonstrate the complete transition from a software-trained CNN into a hardware-oriented inference accelerator.

This repository documents the full flow:

```text
Dataset
  -> Python CNN Training
  -> Fixed-Point Quantization
  -> Weight / Bias HEX Export
  -> Verilog RTL CNN Accelerator
  -> Python Golden Reference Verification
  -> Vivado Synthesis / Implementation
  -> Zybo Z7-20 FPGA Deployment

  Project Motivation

Deepfake media has become increasingly realistic and accessible due to the rapid development of generative AI.

Cloud-based deepfake detection can provide high accuracy, but it introduces several limitations:

Network dependency
Variable latency
Privacy risk from transmitting facial data
Continuous server and bandwidth cost
Limited usability in offline or embedded environments

This project explores deepfake detection from an on-device hardware acceleration perspective.

Instead of sending facial images to an external server, the inference path is mapped directly into FPGA logic.
The goal is to build a lightweight and deterministic CNN accelerator that can classify real and fake facial images inside the device.

Key Features
Lightweight CNN for real/fake deepfake image classification
FPGA-oriented model structure designed for RTL implementation
Verilog-2001 only, without SystemVerilog syntax
Fixed-point inference based on Q-format arithmetic
Layer-wise RTL reconstruction of Python-trained CNN
Modular hierarchy with separated datapath and control logic
FSM-based layer control
PE-array based convolution datapath
Streaming-style feature-map movement
Python golden-reference based verification
Vivado synthesis and implementation on Zybo Z7-20
UART-based board-level test flow
Target Platform
Item	Description
Board	Digilent Zybo Z7-20
SoC	Xilinx Zynq-7000 XC7Z020
FPGA Fabric	Programmable Logic, PL
Processor	ARM Processing System, PS
HDL	Verilog-2001
Toolchain	Xilinx Vivado
Dataset	WildDeepfake
Task	Binary classification, Real / Fake
Interface	AXI-Lite / UART-based test flow
Design Style	Modular RTL, FSM control, pipeline-oriented datapath
CNN Model Architecture

The CNN model is designed to be small enough for FPGA implementation while maintaining meaningful detection performance.

Input Image: 64 x 64 x 3
        |
        v
Conv1 + ReLU + MaxPool1
        |
        v
Conv2 + ReLU + MaxPool2
        |
        v
Conv3 + ReLU + MaxPool3
        |
        v
Global Average Pooling
        |
        v
Dense1 + ReLU
        |
        v
Dense2
        |
        v
Real / Fake Prediction

The model uses a compact 3-convolution structure and avoids large fully connected layers by using Global Average Pooling before the classifier.

This makes the model more suitable for FPGA implementation because it reduces:

Parameter memory
Intermediate feature-map storage
Dense-layer computation cost
Overall hardware resource pressure
Hardware Architecture

The RTL accelerator is designed as a hierarchical CNN inference engine.

cnn_full_inference_top
│
├── Feature Extractor
│   ├── Conv1 Top
│   │   ├── Address Generator
│   │   ├── Weight ROM
│   │   ├── Bias ROM
│   │   ├── PE Array
│   │   ├── Accumulator
│   │   └── ReLU / Output Control
│   │
│   ├── MaxPool1
│   │
│   ├── Conv2 Top
│   │   ├── Address Generator
│   │   ├── Weight ROM
│   │   ├── Bias ROM
│   │   ├── PE Array
│   │   ├── Accumulator
│   │   └── ReLU / Output Control
│   │
│   ├── MaxPool2
│   │
│   ├── Conv3 Top
│   │   ├── Address Generator
│   │   ├── Weight ROM
│   │   ├── Bias ROM
│   │   ├── PE Array
│   │   ├── Accumulator
│   │   └── ReLU / Output Control
│   │
│   └── MaxPool3
│
├── Classifier Tail
│   ├── Global Average Pooling
│   ├── Dense1
│   ├── Dense2
│   └── Prediction Logic
│
└── Control / Status Logic
    ├── FSM Control
    ├── Valid Signal Control
    ├── Done / Busy Status
    └── Output Register Interface

Each layer is separated into independent RTL modules.
This structure improves readability, verification, debugging, and future scalability.

Convolution Datapath

Each convolution layer is implemented using a PE-array based datapath.

For each output feature value, the accelerator performs:

output = ReLU( sum(input_feature x weight) + bias )

The convolution datapath consists of:

Address Generator
Generates feature-map and weight addresses based on output row, column, channel, input channel, and kernel index.
Weight ROM / Bias ROM
Stores trained parameters exported from Python in HEX format.
PE Module
Multiplies one feature value and one weight value.
PE Array
Groups multiple PE modules to compute several products in parallel.
Accumulator
Accumulates partial products to generate one convolution result.
Scaling / ReLU
Adjusts fixed-point scale and applies activation.
Valid Output Logic
Ensures that output data and metadata are aligned with the correct valid timing.
PE Array and Systolic-Style Design Note

This design uses a PE-array based convolution structure, not a full conventional 2D systolic array.

A traditional systolic array usually transfers activation and weight data between neighboring PEs every cycle, reusing data through a regular spatial dataflow.

In this project, feature and weight data are supplied by address generators and ROM/buffer structures.
The PE array performs parallel multiplication, and the accumulator performs reduction.

Therefore, the most accurate description of this design is:

PE-array based streaming convolution accelerator

or

systolic-style PE array convolution datapath

This distinction is important because the design adopts the PE-based parallel MAC concept of systolic architectures, but does not implement full PE-to-PE systolic data movement.

Serializer Module

The serializer module converts multiple parallel feature outputs into a single sequential stream.

Some internal blocks may generate multiple feature values at once, while the next stage expects one valid feature per cycle.

Example:

Parallel input:
data0, data1, data2, data3

Serialized output:
cycle 0 -> data0
cycle 1 -> data1
cycle 2 -> data2
cycle 3 -> data3

The serializer contains:

Input holding registers
Output index counter
IDLE / SEND FSM
Output mux
Valid signal generation
Row / column / channel metadata alignment

This module is important for connecting parallel computation blocks to stream-based CNN stages.

Fixed-Point Representation

The Python-trained model is converted into fixed-point format for hardware inference.

Floating-point arithmetic is expensive in FPGA logic, so this project uses fixed-point arithmetic to reduce hardware cost.

Typical arithmetic flow:

Q8.8 feature x Q8.8 weight = Q16.16 product
partial products are accumulated
bias is added
result is scaled back
ReLU is applied

Using fixed-point arithmetic enables:

Lower resource usage
Simpler arithmetic logic
More predictable RTL behavior
Easier comparison with Python integer golden reference
Verification Strategy

The RTL design is verified using a Python golden-reference flow.

For each stage, Python generates the expected output using the same fixed-point arithmetic policy.
The Verilog simulation output is then compared against the Python reference.

Verification checks include:

Output feature-map count
Data correctness
Row metadata correctness
Column metadata correctness
Channel metadata correctness
Valid signal timing
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

This verification flow ensures that the RTL implementation follows the Python model at the cycle-level and stage-level.

FPGA Implementation Result

The design was synthesized and implemented using Vivado for the Zybo Z7-20 target board.

Implementation analysis focuses on:

LUT usage
Flip-flop usage
DSP usage
BRAM usage
Timing closure
Critical path analysis

The design follows synthesis-aware RTL coding rules and avoids non-synthesizable modeling in the hardware path.

Representative implementation result:

Timing closure achieved
WNS  > 0
TNS  = 0
Failing endpoints = 0

The most critical resource in the current design is BRAM, mainly due to:

Weight ROM storage
Intermediate feature-map buffers
Layer-wise parameter memory

Future optimization will focus on memory banking, weight sharing, packing, and buffer reuse.

Board-Level Test Flow

The current board-level test flow uses PS-PL control and UART-based communication.

PC
 |
 | UART
 v
Zynq PS
 |
 | AXI-Lite control
 v
CNN Accelerator in PL
 |
 v
Prediction Result

The PS controls inference execution, while the PL performs CNN computation.

Typical control signals include:

Signal	Description
start	Start CNN inference
busy	Accelerator is running
done	Inference completed
pred	Final real/fake prediction
logit	Final classification score
Experimental Result

The FPGA inference result reproduced the target test-set behavior using the RTL accelerator.

Representative WildDeepfake test-set result:

Total samples : 6768
Correct       : 5165
Accuracy      : 76.3%

Real samples  : 2440 / 3370
Fake samples  : 2725 / 3398

This result demonstrates that the Python-trained lightweight CNN can be reconstructed into RTL and executed as an FPGA-based inference accelerator.

Repository Structure

Recommended repository structure:

deepfake-fpga-accelerator/
│
├── README.md
│
├── docs/
│   ├── architecture.md
│   ├── verification.md
│   ├── implementation_result.md
│   └── presentation/
│
├── python/
│   ├── train/
│   ├── quantization/
│   ├── golden_reference/
│   └── hex_export/
│
├── rtl/
│   ├── top/
│   ├── common/
│   ├── conv/
│   │   ├── conv1/
│   │   ├── conv2/
│   │   └── conv3/
│   ├── pool/
│   ├── gap/
│   ├── dense/
│   ├── memory/
│   ├── control/
│   └── interface/
│
├── sim/
│   ├── testbench/
│   ├── input_hex/
│   ├── weight_hex/
│   ├── bias_hex/
│   └── expected_output/
│
├── vivado/
│   ├── constraints/
│   ├── reports/
│   └── scripts/
│
└── board_test/
    ├── uart_gui/
    ├── ps_code/
    └── test_logs/
Design Philosophy

This project follows a hardware-first design philosophy.

The CNN model was not treated as a black-box software model.
Instead, each layer was reconstructed into RTL modules with explicit control, memory access, fixed-point arithmetic, and cycle-level verification.

The design prioritizes:

Synthesizable Verilog-2001 RTL
Hierarchical module separation
FSM-based control
Deterministic datapath behavior
Layer-wise verification
Python-to-RTL consistency
FPGA resource awareness
Future extensibility toward pipelined inference
What This Project Demonstrates

This project demonstrates practical AI semiconductor design capability by connecting the following domains:

Deep learning model training
Dataset preprocessing
Fixed-point quantization
Hardware parameter export
Verilog RTL design
CNN datapath construction
FSM-based control design
Testbench-based verification
Vivado synthesis and implementation
FPGA board-level testing

The project bridges the gap between machine learning and digital hardware design.

Limitations

The current design is a functional FPGA CNN accelerator prototype.

There are still several limitations:

Input resolution is limited to 64 x 64
Cross-domain generalization requires improvement
BRAM usage is relatively high
Current structure is not yet fully layer-pipelined
UART-based test flow is slower than a camera/DMA-based real-time system
Full 2D systolic PE-to-PE data reuse is not implemented

These limitations define the direction for future optimization.

Future Work

Planned improvements include:

AXI-DMA based image transfer
Camera input based real-time demonstration
Layer-level pipeline optimization
Multi-lane serializer/deserializer structure
BRAM banking and memory reuse optimization
Weight ROM compression or sharing
Improved face crop and alignment preprocessing
Higher-resolution input experiment
Cross-domain evaluation using FaceForensics++
FPS/Watt measurement on FPGA board
Keywords
Keyword	Meaning
FPGA	Reconfigurable hardware device
CNN	Convolutional Neural Network
RTL	Register Transfer Level hardware design
PE	Processing Element
MAC	Multiply-Accumulate operation
FSM	Finite State Machine
BRAM	FPGA internal block memory
DSP	FPGA arithmetic block for multiplication/MAC
Q8.8	16-bit fixed-point format with 8 fractional bits
AXI-Lite	Lightweight control bus between PS and PL
Golden Reference	Software-generated expected result for RTL verification
Timing Closure	Meeting target clock timing constraints
Final Goal

The final goal of this project is to build a complete on-device deepfake detection accelerator that performs CNN inference on the Zybo Z7-20 FPGA board.

This project shows how a trained neural network can be transformed into a real hardware accelerator through:

Python Model
  -> Fixed-Point Quantization
  -> Hardware Parameter Export
  -> Modular Verilog RTL
  -> Layer-wise Simulation
  -> FPGA Implementation
  -> Board-Level Inference

The project aims to demonstrate a practical hardware implementation flow for AI semiconductor and FPGA-based accelerator design.
