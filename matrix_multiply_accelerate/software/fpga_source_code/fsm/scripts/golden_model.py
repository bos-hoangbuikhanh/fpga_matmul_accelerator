#!/usr/bin/env python3
"""Generate 8x8 signed INT16 inputs and independent, full-width reference results."""

import argparse
from pathlib import Path
import random


SIZE = 8
DEFAULT_SEED = 20261026


def multiply(a, b):
    """Use Python integers, with no fixed-width truncation during accumulation."""
    for matrix in (a, b):
        if len(matrix) != SIZE or any(len(row) != SIZE for row in matrix):
            raise ValueError("Expected an 8x8 matrix")
        if any(not -32768 <= value <= 32767 for row in matrix for value in row):
            raise ValueError("Input is outside the signed INT16 range")
    c = [
        [sum(a[row][k] * b[k][col] for k in range(SIZE)) for col in range(SIZE)]
        for row in range(SIZE)
    ]
    if any(not -(1 << 34) <= value < (1 << 34) for row in c for value in row):
        raise ValueError("Output is outside the signed INT35 range")
    return c


def write_hex(path, matrix, width):
    digits = (width + 3) // 4
    mask = (1 << width) - 1
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(f"{value & mask:0{digits}x}\n" for row in matrix for value in row),
        encoding="ascii",
    )


def test_cases(seed):
    rng = random.Random(seed)

    def constant(value):
        return [[value for _ in range(SIZE)] for _ in range(SIZE)]

    def random_matrix():
        return [[rng.randint(-32768, 32767) for _ in range(SIZE)] for _ in range(SIZE)]

    identity = [[int(row == col) for col in range(SIZE)] for row in range(SIZE)]
    mixed_a = [[(row * 9 - col * 5 - 13) for col in range(SIZE)] for row in range(SIZE)]
    mixed_b = [[(col * 7 - row * 3 + 2) for col in range(SIZE)] for row in range(SIZE)]
    return {
        "tc01": (constant(0), constant(0)),
        "tc02": (identity, random_matrix()),
        "tc03": (constant(2), constant(3)),
        "tc04": (mixed_a, mixed_b),
        # Constant rows/columns exercise all four extrema combinations over eight MACs.
        "tc05": (
            [[-32768 if row % 2 == 0 else 32767 for _ in range(SIZE)] for row in range(SIZE)],
            [[-32768 if col % 2 == 0 else 32767 for col in range(SIZE)] for _ in range(SIZE)],
        ),
        "tc06": (random_matrix(), random_matrix()),
        "tc07a": (random_matrix(), identity),
        "tc07b": (random_matrix(), random_matrix()),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=DEFAULT_SEED)
    parser.add_argument(
        "--output-dir", type=Path, default=Path(__file__).resolve().parents[1],
        help="FSM project directory (default: the directory containing scripts/)",
    )
    args = parser.parse_args()
    cases = test_cases(args.seed)
    for name, (a, b) in cases.items():
        c = multiply(a, b)
        for suffix, matrix, width in (("a", a, 16), ("b", b, 16), ("c", c, 35)):
            write_hex(args.output_dir / "build" / "vectors" / f"{name}_{suffix}.hex", matrix, width)

    # The standalone example is independent of the random seed and is reproducible in synthesis.
    a, b = cases["tc04"]
    write_hex(args.output_dir / "memory" / "matrix_a.hex", a, 16)
    write_hex(args.output_dir / "memory" / "matrix_b.hex", b, 16)
    standalone_c = multiply(a, b)
    write_hex(args.output_dir / "memory" / "c_expected.hex", standalone_c, 35)
    bad_expected = [row[:] for row in standalone_c]
    bad_expected[7][7] += 1
    write_hex(args.output_dir / "build" / "vectors" / "standalone_bad_expected.hex", bad_expected, 35)
    print(f"Golden model: generated {len(cases)} cases and standalone ROMs (seed={args.seed})")


if __name__ == "__main__":
    main()
