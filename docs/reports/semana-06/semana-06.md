# [PT-BR] Relatório da semana 06 - trilha de Design RTL

## 1. Objetivo da semana
 
Implementar a memória compartilhada (`minisoc_memory`) e o _engine_ AES com o controlador de acesso em blocos à memória (`minisoc_aes_top`), com os modos **ECB**, **CBC** e **CTR** em cifragem e decifragem, detecção de configuração inválida e um _testbench_ comparado com um modelo de referência em software.

## 2. Modificações e criações de arquivos no repositório

| Arquivo | Função |
|---|---|
| `rtl/minisoc_mem/minisoc_memory.sv` | Memória 1024 x 32 bits com posse por `MEM_SEL_AES` |
| `rtl/minisoc_aes/minisoc_aes_top.sv` | _Engine_ AES: FSM, modos e acesso em blocos à memória |
| `scripts/gen_vectors.py` | Modelo de referência em Python (**AES-128**, **ECB**, **CBC** e **CTR**) e gerador dos vetores |
| `tb/vectors/` | 66 arquivos `.hex` gerados pelo modelo (22 casos, 3 arquivos cada) |
| `tb/minisoc_aes_top_tb.sv` | _Testbench_ de `minisoc_aes_top` com `minisoc_memory` |
| `Makefile` e `scripts/arquivos.f` | Atualizados com os novos módulos e o _testbench_ |

## 3. Memória compartilhada (`minisoc_memory`)

## 4. _Engine_ AES (`minisoc_aes_top`)

## 5. Modelo de referência (`scripts/gen_vectors.py`)

## 6. _Testbench_ de bloco (`minisoc_aes_top_tb`)

## 7. Execução e resultados

## 8. Limitações
