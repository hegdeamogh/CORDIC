# Pipelined CORDIC Engine

A fully pipelined 16-stage CORDIC processor implemented in SystemVerilog, supporting both **rotation mode** (angle → sin/cos) and **vectoring mode** (rectangular → magnitude/phase) on a single shared datapath.

---

## Architecture

### Algorithm

CORDIC (COordinate Rotation DIgital Computer) computes trigonometric functions using only shift and add operations. At each iteration i, the datapath updates three state variables:

```
x[i+1] = x[i] − d[i] · y[i] · 2⁻ⁱ
y[i+1] = y[i] + d[i] · x[i] · 2⁻ⁱ
z[i+1] = z[i] − d[i] · arctan(2⁻ⁱ)
```

The rotation direction `d[i]` is determined by the operating mode:
- **Rotation mode**: `d[i] = sign(z[i])` — drives residual angle z to zero
- **Vectoring mode**: `d[i] = −sign(y[i])` — drives y component to zero

The shift operation `· 2⁻ⁱ` is a compile-time wire reconnection — zero hardware cost.

### CORDIC Gain

Each iteration implicitly scales the vector magnitude by `1/cos(arctan(2⁻ⁱ)) > 1`. Over 16 iterations this accumulates to a gain of K ≈ 1.6468. In rotation mode this is pre-compensated by initializing `x_in = 1/K ≈ 0.6073`, so outputs emerge at the correct magnitude.

### Pipeline Structure

```
x_in ──► [Stage 0] ──► [Stage 1] ──► ... ──► [Stage 15] ──► x_out
y_in ──► [Stage 0] ──► [Stage 1] ──► ... ──► [Stage 15] ──► y_out
z_in ──► [Stage 0] ──► [Stage 1] ──► ... ──► [Stage 15] ──► z_out
```

- 16 pipeline stages, one per CORDIC iteration
- Each stage: 3 adders + hardwired shift + sign comparator
- Latency: 16 clock cycles
- Throughput: 1 result per clock cycle

### Fixed-Point Format

| Signal | Format | Width | Range |
|--------|--------|-------|-------|
| x, y | Q2.14 (signed) | 16 bits | [−2, +2) |
| z | Q3.13 (signed) | 16 bits | [−4, +4) |

To interpret raw output values: divide by 2¹⁴ = 16384 for x/y, divide by 2¹³ = 8192 for z.

Example: x_out = 11613 → 11613 / 16384 = **0.7089 ≈ cos(45°) = 0.7071**

---

## File Structure

```
cordic/
├── cordic_stage.sv    # Single pipeline stage — shift/add datapath, ATAN LUT, registers
├── cordic_top.sv      # Top-level — generate loop instantiating 16 cordic_stage modules
├── cordic_tb.sv       # Self-checking testbench — rotation and vectoring mode tests
├── cordic_ref.py      # Python golden reference — integer fixed-point simulation
└── waveform.png       # Vivado simulation waveform
```

---

## Port Description

### `cordic_top`

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | input | 1 | Clock |
| rst_n | input | 1 | Active-low synchronous reset |
| mode | input | 1 | 0 = vectoring, 1 = rotation |
| valid_input | input | 1 | Input data valid |
| x_input | input | 16 | x component, Q2.14 |
| y_input | input | 16 | y component, Q2.14 |
| z_input | input | 16 | Target angle (rotation) or 0 (vectoring), Q3.13 |
| valid_output | output | 1 | Output data valid — asserts 16 cycles after valid_input |
| x_output | output | 16 | cos(θ) or magnitude, Q2.14 |
| y_output | output | 16 | sin(θ) or ~0, Q2.14 |
| z_output | output | 16 | ~0 or phase angle, Q3.13 |

---

## Operating Modes

### Rotation Mode (`mode = 1`)

Computes sin and cos of a given angle.

| Input | Value |
|-------|-------|
| x_input | K = 0.6073 → `16'h26DA` in Q2.14 |
| y_input | 0 |
| z_input | Target angle in Q3.13 (e.g. 45° = `16'h1922`) |

| Output | Interpretation |
|--------|---------------|
| x_output | cos(θ) in Q2.14 |
| y_output | sin(θ) in Q2.14 |

### Vectoring Mode (`mode = 0`)

Computes magnitude and phase of a rectangular input vector.

| Input | Value |
|-------|-------|
| x_input | x component in Q2.14 |
| y_input | y component in Q2.14 |
| z_input | 0 |

| Output | Interpretation |
|--------|---------------|
| x_output | Magnitude × K in Q2.14 |
| z_output | Phase angle in Q3.13 |

Note: vectoring mode magnitude output includes the CORDIC gain K ≈ 1.6468. Divide by K to recover true magnitude.

---

## Simulation

### Tools
- Vivado 2025.2.1 (simulation and synthesis)
- Python 3.1 (golden reference)

### Running the Testbench in Vivado

1. Add `cordic_stage.sv`, `cordic_top.sv`, `cordic_tb.sv` to project sources
2. Set `cordic_tb` as simulation top
3. Run Simulation → Run Behavioral Simulation
4. In TCL console: `run 1000ns`

### Expected Transcript Output

```
PASS: ROT 45deg | x_out=11613 y_out=11551
PASS: ROT 30deg | x_out=14191 y_out=8175
PASS: ROT 0deg  | x_out=16379 y_out=-36
PASS: VEC 45deg | mag=26984 phase=6458
```

### Golden Reference

Run `cordic_ref.py` to generate exact expected values using integer fixed-point arithmetic matching the RTL:

```bash
python3 cordic_ref.py
```

---

## Waveform

![Vivado simulation waveform](waveform.png)

The waveform shows:
- `valid_in` pulse at ~25 ns (45° rotation test input applied)
- `stage0_x_out` immediately reflects x_in = 9946 (K in Q2.14)
- `stage7_x_out` shows intermediate convergence at 11662
- `stage15_x_out` / `x_out` settle to 11613 ≈ cos(45°) × 16384
- `valid_out` asserts exactly 16 cycles after `valid_in`

---

## Key Design Decisions

**Why arctan(2⁻ⁱ) as the angle sequence?** Each angle must be smaller than the sum of all remaining angles — this convergence condition guarantees any target angle in [−π/2, π/2] is reachable. The arctan(2⁻ⁱ) sequence satisfies this; uniform angle steps do not.

**Why a pipelined architecture over iterative?** A pipelined design accepts one new input per clock cycle (throughput = 1/cycle) at the cost of 16-cycle latency, versus an iterative design that takes 16 cycles per input. For DSP applications requiring sustained throughput this is the correct tradeoff.

**Why Q2.14 for x/y and Q3.13 for z?** x/y values can grow to ~1.6468 (CORDIC gain) before correction, requiring 2 integer bits for range [−2, +2). z must cover [−π, +π] ≈ [−3.14, +3.14], requiring 3 integer bits for range [−4, +4). Both fit in 16 bits, keeping the datapath width uniform.

**Why a single shared datapath for both modes?** The only difference between rotation and vectoring mode is the sign decision for d[i] — one mux controlled by the mode bit. Sharing the datapath halves area versus two separate implementations.
