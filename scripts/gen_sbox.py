#!/usr/bin/env python3
"""Gera as tabelas do AES em SystemVerilog:
  - rtl/minisoc_aes/minisoc_aes_sbox.sv
  - rtl/minisoc_aes/minisoc_aes_inv_sbox.sv
"""
import os
import sys

POLY = 0x11B


def gf_mul(a: int, b: int) -> int:
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
    if a == 0:
        return 0
    for x in range(1, 256):
        if gf_mul(a, x) == 1:
            return x
    raise ValueError("sem inverso")


def rotl8(x: int, n: int) -> int:
    return ((x << n) | (x >> (8 - n))) & 0xFF


def sbox_value(x: int) -> int:
    """b' = b ^ rotl(b,1) ^ rotl(b,2) ^ rotl(b,3) ^ rotl(b,4) ^ 0x63, com b = inv(x)."""
    b = gf_inv(x)
    return b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 0x63


def write_module(path: str, name: str, desc: str, table: list) -> None:
    lines = []
    lines.append(f"module {name} (")
    lines.append("  input  logic [7:0] data_i,")
    lines.append("  output logic [7:0] data_o")
    lines.append(");")
    lines.append("")
    lines.append("  always_comb begin")
    lines.append("    unique case (data_i)")
    for i, v in enumerate(table):
        lines.append(f"      8'h{i:02x}: data_o = 8'h{v:02x};")
    lines.append("    endcase")
    lines.append("  end")
    lines.append("")
    lines.append("endmodule")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main() -> int:
    sbox = [sbox_value(i) for i in range(256)]

    inv_sbox = [0] * 256
    for x, y in enumerate(sbox):
        inv_sbox[y] = x

    assert sbox[0x00] == 0x63, "sbox(00) deveria ser 63"
    assert sbox[0x53] == 0xED, "sbox(53) deveria ser ed"
    assert sbox[0x01] == 0x7C and sbox[0xFF] == 0x16, "cantos da S-box incorretos"
    assert len(set(sbox)) == 256, "a S-box deve ser uma permutacao (256 valores distintos)"

    assert inv_sbox[0x63] == 0x00 and inv_sbox[0xED] == 0x53, "inv_sbox incorreta"
    assert inv_sbox[0x00] == 0x52 and inv_sbox[0x01] == 0x09, "cantos da inv_sbox incorretos"
    assert inv_sbox[0xFF] == 0x7D, "inv_sbox(ff) deveria ser 7d"
    assert all(inv_sbox[sbox[x]] == x and sbox[inv_sbox[x]] == x for x in range(256)), \
        "inv_sbox deve ser a inversa da S-box"

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rtl = os.path.join(root, "rtl", "minisoc_aes")

    p1 = os.path.join(rtl, "minisoc_aes_sbox.sv")
    p2 = os.path.join(rtl, "minisoc_aes_inv_sbox.sv")
    write_module(p1, "minisoc_aes_sbox",
                 "S-box do AES", sbox)
    write_module(p2, "minisoc_aes_inv_sbox",
                 "S-box inversa do AES", inv_sbox)

    print(f"OK: {p1} gerado (256 entradas).")
    print(f"OK: {p2} gerado (256 entradas).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
