#!/usr/bin/env python3
"""
[PT-BR] script implementa do AES-128 os modos ECB, CBC e CTR em Python para gerar os vetores de teste que o testbench com a memoria (tb/minisoc_aes_top_tb.sv) le com o comando $readmemh.
Convencao do Block Guide:

Um bloco AES de 128 bits ocupa 4 palavras consecutivas da memoria, a palavra 0 e [127:96] e a palavra 3 e [31:0] (byte 0 do bloco na palavra 0, bits [31:24]). O resultado substitui os blocos de entrada.
CTR: entrada da cifra = IV XOR {64'b0, contador}; contador de 64 bits incrementado por bloco, comecando no valor programado; saida = entrada XOR cifra(entrada da cifra). A decifragem em CTR e identica a cifragem.
CBC: cifra C[i] = E(P[i] ^ C[i-1]) com C[-1] = IV; decifra P[i] = D(C[i]) ^ C[i-1].

Os arquivos são gerados em tb/vectors/ com uma palavra de 32 bits em hexadecimal por linha:
Caso: _cfg.hex: 15 palavras: KEY0..3, IV0..3, COUNTER_HI, COUNTER_LO, NUM_BLOCKS, MODE, DECRYPT, EXPECT_ERROR, REGION_WORDS;
Caso: _in.hex: conteudo inicial da memoria (REGION_WORDS palavras, a partir do endereco 0);
Caso: _exp.hex: conteudo esperado da memoria apos a operacao;
Nomes dos casos validos: <modo>_<enc|dec>_<N>blk (modo = ecb, cbc, ctr e N = 1, 2, 256);
Nomes dos casos de configuracao invalida: err_nblocks0, err_nblocks257, err_mode6, err_mode7.

Comandos no terminal para uso desse script:
python3 scripts/gen_vectors.py # gera os arquivos tb/vectors/*.hex
python3 scripts/gen_vectors.py --selftest # so executa as autochecagens do modelo
"""
import argparse
import os
import random
import sys

MODES = {"ecb": 0, "cbc": 1, "ctr": 5} # valor do campo MODE
SIZES = [1, 2, 256]
SEED = 20261127
POLY = 0x11B

# AES-128 (FIPS-197):
def gf_mul(a, b):
    r = 0
    while b:
        if b & 1:
            r ^= a
        a <<= 1
        if a & 0x100:
            a ^= POLY
        b >>= 1
    return r

def _build_sbox():
    sbox = [0] * 256
    for x in range(256):
        inv = 0 if x == 0 else next(y for y in range(1, 256) if gf_mul(x, y) == 1)
        r = inv
        for i in range(1, 5):
            r ^= ((inv << i) | (inv >> (8 - i))) & 0xFF
        sbox[x] = r ^ 0x63
    inv_sbox = [0] * 256
    for x, y in enumerate(sbox):
        inv_sbox[y] = x
    return sbox, inv_sbox

SBOX, INV_SBOX = _build_sbox()

def key_expansion(key):
    """Devolve as 11 chaves de rodada"""
    assert len(key) == 16
    w = [list(key[4 * i:4 * i + 4]) for i in range(4)]
    rcon = 1
    for i in range(4, 44):
        t = w[i - 1][:]
        if i % 4 == 0:
            t = t[1:] + t[:1]
            t = [SBOX[b] for b in t]
            t[0] ^= rcon
            rcon = gf_mul(rcon, 2)
        w.append([a ^ b for a, b in zip(w[i - 4], t)])
    return [bytes(sum(w[4 * r:4 * r + 4], [])) for r in range(11)]

def _xor(a, b):
    return bytes(x ^ y for x, y in zip(a, b))

def _shift_rows(s, inverse=False):
    out = [0] * 16
    for c in range(4):
        for r in range(4):
            src_c = (c - r) % 4 if inverse else (c + r) % 4
            out[r + 4 * c] = s[r + 4 * src_c]
    return bytes(out)

def _mix_columns(s, inverse=False):
    coef = (14, 11, 13, 9) if inverse else (2, 3, 1, 1)
    out = bytearray(16)
    for c in range(4):
        col = s[4 * c:4 * c + 4]
        for r in range(4):
            v = 0
            for k in range(4):
                v ^= gf_mul(col[k], coef[(k - r) % 4])
            out[4 * c + r] = v
    return bytes(out)

def encrypt_block(block, round_keys):
    s = _xor(block, round_keys[0])
    for r in range(1, 11):
        s = bytes(SBOX[b] for b in s)
        s = _shift_rows(s)
        if r < 10:
            s = _mix_columns(s)
        s = _xor(s, round_keys[r])
    return s

def decrypt_block(block, round_keys):
    s = _xor(block, round_keys[10])
    for r in range(1, 11):
        s = _shift_rows(s, inverse=True)
        s = bytes(INV_SBOX[b] for b in s)
        s = _xor(s, round_keys[10 - r])
        if r < 10:
            s = _mix_columns(s, inverse=True)
    return s

# Modos de operacao (blocos de 16 bytes):
def ecb(blocks, key, decrypt):
    rk = key_expansion(key)
    f = decrypt_block if decrypt else encrypt_block
    return [f(b, rk) for b in blocks]

def cbc(blocks, key, iv, decrypt):
    rk = key_expansion(key)
    out, prev = [], iv
    for b in blocks:
        if decrypt:
            out.append(_xor(decrypt_block(b, rk), prev))
            prev = b
        else:
            c = encrypt_block(_xor(b, prev), rk)
            out.append(c)
            prev = c
    return out

def ctr(blocks, key, iv, counter):
    rk = key_expansion(key)
    out = []
    for i, b in enumerate(blocks):
        ctr_val = (counter + i) & 0xFFFFFFFFFFFFFFFF
        inp = _xor(iv, ctr_val.to_bytes(16, "big"))
        out.append(_xor(b, encrypt_block(inp, rk)))
    return out

def run_mode(mode, blocks, key, iv, counter, decrypt):
    if mode == "ecb":
        return ecb(blocks, key, decrypt)
    if mode == "cbc":
        return cbc(blocks, key, iv, decrypt)
    if mode == "ctr":
        return ctr(blocks, key, iv, counter)
    raise ValueError(mode)

# Autochecagens com vetores publicados:
def h(s):
    return bytes.fromhex(s)

def selftest():
    # FIPS-197 do apendice B e C.1 do Block Guide:
    for key, pt, ct in [
        ("2b7e151628aed2a6abf7158809cf4f3c", "3243f6a8885a308d313198a2e0370734", "3925841d02dc09fbdc118597196a0b32"),
        ("000102030405060708090a0b0c0d0e0f", "00112233445566778899aabbccddeeff", "69c4e0d86a7b0430d8cdb78070b4c55a"),
    ]:
        rk = key_expansion(h(key))
        assert encrypt_block(h(pt), rk) == h(ct), "FIPS-197: cifragem"
        assert decrypt_block(h(ct), rk) == h(pt), "FIPS-197: decifragem"
        assert key_expansion(h("2b7e151628aed2a6abf7158809cf4f3c"))[10] == h("d014f9a8c9ee2589e13f0cc8b6630ca6")

    # NIST SP 800-38A, F.1.1 (ECB-AES128) e F.2.1 (CBC-AES128):
    key = h("2b7e151628aed2a6abf7158809cf4f3c")
    pt = [h("6bc1bee22e409f96e93d7e117393172a"), h("ae2d8a571e03ac9c9eb76fac45af8e51"),
          h("30c81c46a35ce411e5fbc1191a0a52ef"), h("f69f2445df4f9b17ad2b417be66c3710")]
    ecb_ct = [h("3ad77bb40d7a3660a89ecaf32466ef97"), h("f5d3d58503b9699de785895a96fdbaaf"),
              h("43b1cd7f598ece23881b00e3ed030688"), h("7b0c785e27e8ad3f8223207104725dd4")]
    cbc_ct = [h("7649abac8119b246cee98e9b12e9197d"), h("5086cb9b507219ee95db113a917678b2"),
              h("73bed6b8e3c1743b7116e69e22229516"), h("3ff1caa1681fac09120eca307586e1a7")]
    iv = h("000102030405060708090a0b0c0d0e0f")
    assert ecb(pt, key, False) == ecb_ct and ecb(ecb_ct, key, True) == pt, "NIST ECB"
    assert cbc(pt, key, iv, False) == cbc_ct and cbc(cbc_ct, key, iv, True) == pt, "NIST CBC"

    # NIST SP 800-38A, F.5.1: o primeiro bloco do CTR coincide (contador 0, IV = bloco inicial) (do segundo bloco em diante o NIST soma 1 ao bloco inteiro, aqui o contador e combinado por XOR):
    ctr_iv = h("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
    ctr_ct0 = h("874d6191b620e3261bef6864990db6ce")
    assert ctr([pt[0]], key, ctr_iv, 0) == [ctr_ct0], "NIST CTR (bloco 1)"
    # Com os 64 bits baixos do IV em zero, XOR e soma coincidem: checagem do segundo bloco em diante:
    iv0 = h("f0f1f2f3f4f5f6f700000000000000" + "00")
    ks = [encrypt_block(_xor(iv0, i.to_bytes(16, "big")), key_expansion(key)) for i in range(2)]
    assert ctr(pt[:2], key, iv0, 0) == [_xor(pt[0], ks[0]), _xor(pt[1], ks[1])]

    # Referencia externa, se disponivel (opcional): pycryptodome:
    try:
        from Crypto.Cipher import AES as _A # type: ignore
        rnd = random.Random(1)
        for _ in range(20):
            k = bytes(rnd.randrange(256) for _ in range(16))
            v = bytes(rnd.randrange(256) for _ in range(16))
            data = [bytes(rnd.randrange(256) for _ in range(16)) for _ in range(5)]
            blob = b"".join(data)
            assert b"".join(ecb(data, k, False)) == _A.new(k, _A.MODE_ECB).encrypt(blob)
            assert b"".join(cbc(data, k, v, False)) == _A.new(k, _A.MODE_CBC, iv=v).encrypt(blob)
            assert b"".join(cbc(cbc(data, k, v, False), k, v, True)) == blob
            # CTR: com os 64 bits baixos do IV em zero, XOR e soma coincidem com o CTR padrao:
            v0 = v[:8] + bytes(8)
            c0 = rnd.getrandbits(32)
            ref = _A.new(k, _A.MODE_CTR, nonce=b"", initial_value=int.from_bytes(v0, "big") + c0).encrypt(blob)
            assert b"".join(ctr(data, k, v0, c0)) == ref
        return "OK (FIPS-197, NIST SP 800-38A e pycryptodome: ECB, CBC e CTR)"
    except ImportError:
        return "OK (FIPS-197 e NIST SP 800-38A; pycryptodome nao instalado, referencia externa pulada)"

# Geracao dos vetores:
def words(data):
    """bytes (multiplo de 4) -> lista de palavras de 32 bits (big-endian)."""
    return [int.from_bytes(data[i:i + 4], "big") for i in range(0, len(data), 4)]

def write_hex(path, ws):
    with open(path, "w") as f:
        for w in ws:
            f.write(f"{w:08x}\n")

def make_case(out_dir, name, mode_name, mode_val, nblocks, decrypt, expect_error=False, region_blocks=None, counter=None):
    rnd = random.Random(f"{SEED}-{name}")
    rb = lambda n: bytes(rnd.randrange(256) for _ in range(n))
    key, iv = rb(16), rb(16)
    if counter is None:
        counter = rnd.getrandbits(64) if mode_name == "ctr" else 0
    n_data = region_blocks if region_blocks is not None else nblocks
    plain = [rb(16) for _ in range(n_data)]

    if expect_error:
        mem_in = plain
        mem_exp = plain # configuracao invalida: memoria inalterada
    else:
        res = run_mode(mode_name, plain, key, iv, counter, False)
        if decrypt:
            mem_in = res # entrada = texto cifrado, esperado = texto claro
            mem_exp = plain
            assert run_mode(mode_name, mem_in, key, iv, counter, True) == mem_exp
        else:
            mem_in = plain
            mem_exp = res

    cfg = (words(key) + words(iv) + [counter >> 32, counter & 0xFFFFFFFF]
           + [nblocks, mode_val, 1 if decrypt else 0, 1 if expect_error else 0, 4 * n_data])
    write_hex(os.path.join(out_dir, f"{name}_cfg.hex"), cfg)
    write_hex(os.path.join(out_dir, f"{name}_in.hex"), words(b"".join(mem_in)))
    write_hex(os.path.join(out_dir, f"{name}_exp.hex"), words(b"".join(mem_exp)))

def generate(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    names = []
    for mode_name, mode_val in MODES.items():
        for decrypt in (False, True):
            for n in SIZES:
                name = f"{mode_name}_{'dec' if decrypt else 'enc'}_{n}blk"
                # No CTR de 256 blocos o contador atravessa a fronteira de 32 bits
                # (COUNTER_LO -> COUNTER_HI), sem estourar os 64 bits
                counter = 0x00000000FFFFFF80 if (mode_name == "ctr" and n == 256) else None
                make_case(out_dir, name, mode_name, mode_val, n, decrypt, counter=counter)
                names.append(name)
    # Configuracoes invalidas: ERROR esperado, memoria inalterada (regiao de 2 blocos):
    make_case(out_dir, "err_nblocks0", "ecb", 0, 0, False, expect_error=True, region_blocks=2)
    make_case(out_dir, "err_nblocks257", "ecb", 0, 257, False, expect_error=True, region_blocks=2)
    make_case(out_dir, "err_mode6", "ecb", 6, 2, False, expect_error=True, region_blocks=2)
    make_case(out_dir, "err_mode7", "ecb", 7, 2, False, expect_error=True, region_blocks=2)
    names += ["err_nblocks0", "err_nblocks257", "err_mode6", "err_mode7"]
    return names


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join("tb", "vectors"), help="pasta de saida")
    ap.add_argument("--selftest", action="store_true", help="so executa as autochecagens do modelo")
    args = ap.parse_args()

    print("Autochecagem do modelo:", selftest())
    if args.selftest:
        return 0
    names = generate(args.out)
    print(f"OK: {len(names)} casos em {args.out}/  ({3 * len(names)} arquivos .hex)")
    for n in names:
        print("  ", n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
