# SRAM Wrapper Verification Plan & Documentation

## 1. Introduction
This document describes the UVM-based verification environment for the SRAM wrapper project.
The primary goal is to perform an A/B Test (Back-to-Back) verifying that a new SRAM cell (`dut_new`) can safely replace the original cell (`dut_ori`).

## 2. Verification Strategy
- **Methodology**: UVM (Universal Verification Methodology) + SVA (SystemVerilog Assertions).
- **Topology**: Both `dut_ori` (Golden) and `dut_new` share the exact same stimulus.
- **Checking Mechanism**: Instead of a UVM scoreboard and reference model, an inline SVA checker (`mem_sva_checker.sv`) is used to directly compare output responses (`rdata_ori === rdata_new`) in a cycle-accurate manner.

## 3. Environment Architecture
### 3.1. DUT Interface (`mem_if.sv`)
Supports parameterization of `ADDR_WIDTH` and `DATA_WIDTH`. Contains signals for Port A and Port B.
- Command modes: NOP(0), READ(1), WRITE(2).
- Write Enable Mask (`wem`) is active low.

### 3.2. UVC Components (`mem_uvc_pkg.sv`)
- **mem_item**: Sequence item avoiding `uvm_field_int` macros for performance. Explicitly overrides `do_copy`, `do_compare`, `do_print`.
- **mem_driver**: Drives Port A and B in parallel based on `cmd_a` and `cmd_b`.
- **mem_sequencer & mem_agent**: Standard UVM active agent topology. No monitor/scoreboard is included per project constraints.

### 3.3. Testbench Top (`tb_top.sv`)
Instantiates the dual DUTs, the interface, and the SVA checker. Also handles `$dumpfile` for open-source EDA waveform viewing.

## 4. Test Scenarios (Smoke Tests)
- `mem_sp_test`: Single Port mode test. Port B is constrained to NOP.
- `mem_sdp_test`: Simple Dual Port mode test. Port A is write-only, Port B is read-only.

## 5. Getting Started
To run the smoke tests using the provided Makefile:

```bash
# Run SDP test
make all TEST=mem_sdp_test

# Run SP test
make run TEST=mem_sp_test
```

To view waveforms:
```bash
make wave
```
