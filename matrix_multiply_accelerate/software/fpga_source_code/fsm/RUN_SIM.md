# How to run the FSM accelerator simulation

Run `scripts/run_sim.sh` to generate test vectors and execute the MAC, PE array,
matrix accelerator and standalone checker tests.

## 1. Open the project directory

```bash
cd /home/hoangb/workspace/fpga/fpga_matmul_accelerator/matrix_multiply_accelerate/software/fpga_source_code/fsm
```

Run the commands below from this directory.

## 2. Choose your simulator setup

### Use the simulator already downloaded for this workspace

The development session downloaded Icarus Verilog into `/tmp`. If those files
are still present, run:

```bash
IVERILOG=/tmp/fsm-iverilog/iverilog \
VVP=/tmp/fsm-iverilog/root/usr/bin/vvp \
bash scripts/run_sim.sh
```

These paths are temporary and may disappear after a reboot or cleanup. The
`IVERILOG` path above is a wrapper that locates the extracted compiler support
files; use that wrapper rather than the extracted compiler binary directly.

### Use installed tools

Requirements are Bash, Python 3 and Icarus Verilog, which provides both
`iverilog` and `vvp`. No extra Python packages or FPGA hardware are required.

On Ubuntu/Debian, install missing tools with:

```bash
sudo apt update
sudo apt install iverilog python3
```

Check that the executables are available:

```bash
command -v python3 iverilog vvp
```

Then run:

```bash
bash scripts/run_sim.sh
```

Calling the script with `bash` does not require setting executable permissions.
The script resolves its own project directory, so calling it by absolute path
also works from another directory.

## 3. Read the results

The script generates reference matrices, compiles each testbench as
Verilog-2001, and runs all four testbenches in sequence. A successful run includes:

```text
MAC Testbench: PASS
PE Array Testbench: PASS
Repeated START: PASS
Control interface/reset recovery: PASS
Matrix Accelerator: PASS
All 64 Output Values: PASS
Standalone Top: PASS
All simulations: PASS
```

Individual lines also include check counts or timing details. The accelerator
test compares 576 output values across nine completed computations. The
standalone test checks both correct expectations and deliberately corrupted
expectations; successfully detecting the corruption is a passing test.

The script stops at the first failure and returns a nonzero exit status. The
final `All simulations: PASS` line appears only if every testbench succeeds.
Immediately after the command, inspect its status with:

```bash
echo $?
```

`0` means success. A matrix mismatch prints its row, column, expected value and
actual value.

## Optional commands

Use a different repeatable random seed with installed tools:

```bash
SEED=12345 bash scripts/run_sim.sh
```

Use a different seed with the local simulator:

```bash
SEED=12345 \
IVERILOG=/tmp/fsm-iverilog/iverilog \
VVP=/tmp/fsm-iverilog/root/usr/bin/vvp \
bash scripts/run_sim.sh
```

The default seed is `20261026`. You can also set `PYTHON` to the path of your
Python 3 executable. `IVERILOG` and `VVP` each accept an executable path.

Generate matrices and expected results without running a simulator:

```bash
python3 scripts/golden_model.py --seed 20261026
```

## Generated files and troubleshooting

Each run regenerates:

- `build/vectors/`: input and expected-output test vectors.
- `build/tb_*.vvp`: compiled simulation executables.
- `memory/matrix_a.hex`, `memory/matrix_b.hex`, `memory/c_expected.hex`:
  standalone ROM contents. These use a fixed mixed-sign example regardless of
  the random seed.

The `build/` directory is ignored by Git. Edit the golden model to change
generated matrices; manually edited hex files are overwritten by the runner.

| Problem | Action |
| --- | --- |
| `Simulator executable 'iverilog' is unavailable` | Install Icarus Verilog or use the local `IVERILOG` and `VVP` overrides above. |
| A `/tmp/fsm-iverilog/...` executable is unavailable | Use installed tools; the temporary download has been removed. |
| `python3: command not found` | Install Python 3 or set `PYTHON=/path/to/python3`. |
| `scripts/run_sim.sh: No such file or directory` | Run the `cd` command in step 1, or call the script by absolute path. |
| A test prints `FAIL` | Read the first failure and mismatch details; the script returns nonzero and stops there. |

See [README.md](README.md) for the architecture, interface contract and full
verification coverage.
