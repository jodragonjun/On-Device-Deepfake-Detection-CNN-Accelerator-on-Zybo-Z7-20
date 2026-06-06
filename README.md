# On-Device Deepfake Detection CNN Accelerator on Zybo Z7-20

> From Python-trained CNN to synthesizable Verilog RTL  
> A modular FPGA-based deepfake detection accelerator for on-device real/fake image classification

---

## Overview

This project implements an end-to-end FPGA-based deepfake image classification accelerator on the **Digilent Zybo Z7-20** board.

A lightweight CNN model is trained in Python using the **WildDeepfake** dataset, quantized into fixed-point representation, exported as hardware-readable HEX files, and reconstructed as a fully synthesizable **Verilog-2001 RTL** design.

The main objective of this project is not simply to run a neural network model, but to demonstrate the complete transition from a software-trained CNN into a hardware-oriented inference accelerator.

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
