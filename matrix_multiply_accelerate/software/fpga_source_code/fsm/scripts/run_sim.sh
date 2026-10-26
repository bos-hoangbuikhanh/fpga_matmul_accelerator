#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_dir"

python_bin="${PYTHON:-python3}"
iverilog_bin="${IVERILOG:-iverilog}"
vvp_bin="${VVP:-vvp}"
"$python_bin" scripts/golden_model.py --seed "${SEED:-20261026}"

for tool in "$iverilog_bin" "$vvp_bin"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Simulator executable '$tool' is unavailable. Install Icarus Verilog or set IVERILOG and VVP." >&2
        exit 127
    fi
done

mkdir -p build
core_sources=(rtl/mac.v rtl/pe_array.v rtl/matrix_buffer.v rtl/matrix_controller.v rtl/matrix_accelerator.v)

run_test() {
    local top="$1"
    shift
    "$iverilog_bin" -g2001 -Wall -s "$top" -o "build/$top.vvp" "tb/$top.v" "$@"
    "$vvp_bin" "build/$top.vvp"
}

run_test tb_mac rtl/mac.v
run_test tb_pe_array rtl/mac.v rtl/pe_array.v
run_test tb_matrix_accelerator "${core_sources[@]}"
run_test tb_standalone_top "${core_sources[@]}" rtl/standalone_top.v

echo "All simulations: PASS"
