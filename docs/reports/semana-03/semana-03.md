# [PT-BR] Relatório da semana 03 - trilha de Design RTL

## 1. Objetivo da semana

Completar as transformações de rodada do AES-128, diretas e inversas, validá-las com os valores intermediários da FIPS-197 e definir a microarquitetura do sistema (`docs/architecture/architecture_v1.0.md`). Na semana 02 foram feitos a S-box, as operações **SubBytes** e a **ShiftRows,** e nesta semana foram feitos o **MixColumns**, o **AddRoundKey** e as três transformações inversas: **InvSubBytes**, **InvShiftRows** e **InvMixColumns**. Além disso, foi criado o *testbench* `minisoc_aes_transforms_tb.sv` para realizar as verificações intermediárias.

## 2. Arquivos criados/modificados no repositório

| **Arquivo** | **Função** |
| --- | --- |
| `rtl/minisoc_aes/minisoc_aes_mix_columns.sv` | Implementa a operação **MixColumns**. |
| `rtl/minisoc_aes/minisoc_aes_add_round_key.sv` | Implementa a operação **AddRoundKey**. |
| `rtl/minisoc_aes/minisoc_aes_inv_sbox.sv` | S-box inversa (gerada pelo *script* `gen_sbox.py`). |
| `rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv` | Implementa a operação **InvSubBytes**. |
| `rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv` | Implementa a operação **InvShiftRows**. |
| `rtl/minisoc_aes/minisoc_aes_inv_mix_columns.sv` | Implementa a operação **InvMixColumns**. |
| `scripts/gen_sbox.py` | O *script* foi atualizado para gerar também a S-box inversa. |
| `tb/minisoc_aes_transforms_tb.sv` | *Testbench* de todas as transformações. |
| `docs/architecture/microarquitetura_v1.0.md` | Documento de microarquitetura. |
| `Makefile` e `scripts/arquivos.f` | Foram atualizados para o *testbench* `minisoc_aes_transforms_tb.sv`. |

## 3. Transformações de rodada

Com as novas operações, o ciclo de cifragem e de decifragem foi completo na semana 03. A cifragem aplica sequencialmente as transformações diretas em 10 rodadas, o fluxo de decifragem utiliza as operações inversas correspondentes para desfazer o processo. Note a estruturação desses processos a seguir:

- **MixColumns e InvMixColumns:** operam em cada coluna do estado (que são 4 bytes consecutivos) com multiplicações em **GF(2⁸)**. A operação **MixColumns** usa a matriz de coeficientes `02 03 01 01` (cada linha é a anterior rotacionada) e o InvMixColumns usa `0e 0b 0d 09`. Ambos são montados a partir de uma função chamada `xtime` (multiplicação por 2, com redução pelo polinômio `0x11B`): `3·a = xtime(a) ^ a`, `09·a = x8 ^ a`, `0b·a = x8 ^ x2 ^ a`, `0d·a = x8 ^ x4 ^ a` e `0e·a = x8 ^ x4 ^ x2`. Exemplo da norma FIPS-197 e de acordo com o documento de especificação *Block Guide* do MiniSoC AES: a coluna `d4bf5d30` vira `046681e5`, e a operação **InvMixColumns** desfaz o resultado.
- **AddRoundKey.** É um XOR de 128 bits entre o estado e a chave de rodada. Por ser um XOR, é a própria inversa, então não será necessário uma operação **InvAddRoundKey**.
- **InvShiftRows.** Rotaciona a linha `r` para a direita em `r` posições (a linha 0 não muda). O byte de saída `r + 4c` recebe o byte de entrada `r + 4·((c + 4 − r) mod 4)`.
- **InvSubBytes e S-box inversa.** O `gen_sbox.py` calcula a S-box inversa a partir da própria S-box (`inv[sbox[x]] = x`) e confere valores da FIPS-197 (`inv(00) = 52`, `inv(01) = 09`, `inv(ff) = 7d`, `inv(63) = 00`, `inv(ed) = 53`) e que ela é a inversa nas 256 entradas. O **InvSubBytes** aplica essa tabela a cada um dos 16 bytes do estado.

## 4. *Testbench* em `tb/minisoc_aes_transforms_tb.sv`

Assim como o *testbench* em `tb/minisoc_aes_sbox_sub_shift_tb.sv`, este termina com `PASS` ou `FAIL` (com `$fatal` em caso de falha) e cobre os nove módulos de rodada (as cinco diretas e as quatro inversas). O *testbench* realiza 5 tipos de verificações:

| Tipo de verificação | Quantidade de verificações |
| --- | --- |
| S-box e S-box inversa, com suas 256 entradas, contra referência calculada no próprio *testbench*. | 516 |
| Operações de cifragem: **SubBytes**, **ShiftRows**, **MixColumns** e **AddRoundKey**. | 40 |
| Operações de decifragem: **InvShiftRows**, **InvSubBytes**, **InvMixColumns** e **AddRoundKey**. | 39 |
| Propriedades `Inv(F(x)) = x` e comparação com modelo de referência da norma. | 1200 |
| **Total** | **1795** |

## 5. Execução

O comando `make` executou o *lint*, compilação e simulação no VCS sem erros nem avisos. O *log* completo está no repositório do projeto, em `docs/reports/semana-03/semana-03-make.log`.
