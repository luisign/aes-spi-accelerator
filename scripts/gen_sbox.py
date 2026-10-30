#!/usr/bin/env python3

import os
import sys

POLY = 0x11B

def gf_mul(a: int, b: int) -> int:
    """Multiplicacao em GF(2^8) (shift-and-add com reducao por 0x11B)."""
    r = 0
    for _ in range(8):
        if b & 1:
            r ^= a
        carry = a & 0x80
        a = (a << 1) & 0xFF
        if carry:
            a ^= POLY & 0xFF
        b >>= 1
    return r

def gf_inv(a: int) -> int:
    """Inverso multiplicativo por forca bruta; 0 -> 0."""
    if a == 0:
        return 0
    for x in range(1, 256):
        if gf_mul(a, x) == 1:
            return x
    raise ValueError("sem inverso (nao deveria acontecer)")

def rotl8(x: int, n: int) -> int:
    return ((x << n) | (x >> (8 - n))) & 0xFF

def sbox_value(x: int) -> int:
    """b' = b ^ rotl(b,1) ^ rotl(b,2) ^ rotl(b,3) ^ rotl(b,4) ^ 0x63, com b = inv(x)."""
    b = gf_inv(x)
    return b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 0x63

def main() -> int:
    sbox = [sbox_value(i) for i in range(256)]

    # Auto-checagem contra valores conhecidos da FIPS-197
    assert sbox[0x00] == 0x63, "sbox(00) deveria ser 63"
    assert sbox[0x53] == 0xED, "sbox(53) deveria ser ed"
    assert sbox[0x01] == 0x7C and sbox[0xFF] == 0x16, "cantos da tabela incorretos"
    assert len(set(sbox)) == 256, "a s-box deve ser uma permutacao (256 valores distintos)"

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "rtl", "minisoc_aes", "minisoc_aes_sbox.sv")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    lines = []
    lines.append("// =============================================================================")
    lines.append("// Arquivo da s-box gerada em scripts/gen_sbox.py")
    lines.append("// Para regenerar a s-box: python3 scripts/gen_sbox.py")
    lines.append("// =============================================================================")
    lines.append("module minisoc_aes_sbox (")
    lines.append("  input  logic [7:0] data_i,")
    lines.append("  output logic [7:0] data_o")
    lines.append(");")
    lines.append("")
    lines.append("  always_comb begin")
    lines.append("    unique case (data_i)")
    for i, v in enumerate(sbox):
        lines.append(f"      8'h{i:02x}: data_o = 8'h{v:02x};")
    lines.append("    endcase")
    lines.append("  end")
    lines.append("")
    lines.append("endmodule")

    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"OK: {out} gerado (256 entradas).")
    return 0

if __name__ == "__main__":
    sys.exit(main())
