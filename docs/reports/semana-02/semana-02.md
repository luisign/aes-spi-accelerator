# [PT-BR] Relatório da semana 02 - trilha de Design RTL

## 1. Objetivo da semana

O presente relatório aborda de forma geral o que foi realizado na semana 02 da trilha de Design RTL do programa CI Expert. A semana teve como objetivo o desenvolvimento e a validação de alguns dos módulos combinacionais principais do projeto do algoritmo AES-128, especificamente a tabela de substituição S-box (com base na norma FIPS-197), o módulo de substituição de bytes (**SubBytes**) e o módulo de reordenação de linhas (**ShiftRows**), que são responsáveis por realizar as duas transformações iniciais do algoritmo de criptografia AES, explicados no relatório da semana 01 (`docs/reports/semana-01/semana-01.md`).

## 2. Estrutura de módulos e arquivos novos no repositório

- `scripts/gen_sbox.py`: gerador automatizado por linguagem Python da S-box baseado nas equações da FIPS-197;
- `rtl/minisoc_aes/minisoc_aes_sbox.sv`: módulo combinacional da tabela S-box;
- `rtl/minisoc_aes/minisoc_aes_sub_bytes.sv`: módulo combinacional de 128 bits contendo 16 instâncias em paralelo da `minisoc_aes_sbox`, para a operação **SubBytes**;
- `rtl/minisoc_aes/minisoc_aes_shift_rows.sv`: módulo combinacional da operação **ShiftRows** sobre a matriz do estado de 128 bits;
- `scripts/arquivos.f`: contém a lista e o caminho dos arquivos de RTL e de _testbench_ para serem compilados/simulados;
- `Makefile`: novo _script_ para automatizar a compilação, _lint_ e simulação.
