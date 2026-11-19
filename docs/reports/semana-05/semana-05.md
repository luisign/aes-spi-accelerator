# [PT-BR] Relatório da semana 05 - trilha de Design RTL

## 1. Objetivo da semana
 
Implementar o front-end SPI com o banco de registradores (`minisoc_spi`) e o modelo RTL do PLL (`minisoc_pll_mock`), e validá-los com um _testbench_ de exemplo que acessa todos os registradores pelo protocolo SPI e habilita o PLL.

## 2. Modificações de arquivos no repositório

| Módulo | Descrição |
|---|---|
| `rtl/minisoc_spi/minisoc_spi.sv` | Módulo front-end SPI, banco de registradores e status |
| `rtl/minisoc_pll/minisoc_pll_mock.sv` | Módulo do modelo RTL do PLL mockado |
| `tb/minisoc_spi_pll_tb.sv` | _Testbench_ com SPI ligado ao PLL |
| `tb/minisoc_aes_key_exp_tb.sv` e `tb/minisoc_aes_dp_tb.sv` | _Testbenches_ atualizados com esperas de borda reescritas para corrigir os avisos de _lint_ |
| `Makefile` e `scripts/arquivos.f` | Arquivos atualizados com os novos módulos e _testbench_ |


## 3. Módulo PLL (`minisoc_pll_mock`)

Este módulo é um modelo comportamental somente para simulação, para que o restante do sistema (os outros três subsistemas, SPI, AES, e memória) possa ser verificado. Além do _reset_ (`rst_n`) e do sinal de _clock_ (`clk_ref_i`) que são de referência, este módulo possui quatro sinais principais: `enable_i`, sinal que liga e desliga o PLL (`1` = habilita, `0` = desabilita), vindo do bit `PLL_ENABLE` do registrador `SYSTEM_CONTROL` do SPI, `div_sel_i`, que é o seletor de 2 bits que escolhe o divisor do _clock_ de referência (`00 = /1`, `01 = /2`, `10 = /4` e `11 = /8`), vindo do campo `PLL_DIV_SEL` do `SYSTEM_CONTROL`, `locked_o`, para indicar que o PLL concluiu a aquisição e que o _clock_ do sistema está liberado, sendo lido pelo software no bit `PLL_LOCKED` do `SYSTEM_STATUS`, e o `sys_clk_o`, que é o _clock_ do sistema, gerado a partir da divisão do _clock_ de referência `clk_ref_i` e usado pelo domínio do AES.

Quando `minisoc_pll_mock` está desabilitado, ou seja, quando `enable_i = 0`, os sinais de saída `locked_o` e `sys_clk_o` ficam em `0`. Quando `enable_i` vai para `1`, o módulo espera um número pseudoaleatório de ciclos de `clk_ref_i` (de `16` a `47`, gerado por um LFSR de 16 bits) e então `locked_o = 1`. Depois do _lock_, o `sys_clk_o` é liberado, com a frequência definida por `div_sel_i` (2 GHz, 1 GHz, 500 MHz ou 250 MHz). Se `div_sel_i` for alterado com o PLL habilitado, o módulo bloqueia o _clock_, `locked_o` vai para `0` e readquire o _lock_ com o novo divisor.

## 4. Módulo SPI (`minisoc_spi`)

### 4.1. Registradores

| Endereço | Registrador | Acesso (_read_ (R) e/ou _write_ (W)) |
|---|---|---|
| `0x00` a `0x03` | `KEY0` a `KEY3` | R/W |
| `0x04` a `0x07` | `IV0` a `IV3` | R/W |
| `0x08`, `0x09` | `COUNTER_HI`, `COUNTER_LO` | R/W |
| `0x0A` | `NUM_BLOCKS` | R/W |
| `0x0B` | `AES_CONTROL: START [0]` (_write-one-pulse_), `DECRYPT [1]`, `MODE [4:2]` | R/W |
| `0x0C` | `AES_STATUS: BUSY [0]`, `DONE [1]`, `ERROR [2]`, `BLOCKS_DONE [11:3]` | R |
| `0x0D` | `VERSION` | R |
| `0x0E` | `SYSTEM_CONTROL: MEM_SEL_AES [0]`, `PLL_ENABLE [1]`, `PLL_DIV_SEL [3:2]` | R/W |
| `0x0F` | `SYSTEM_STATUS: PLL_LOCKED [0]` | R |
| `0x3F` | `NOP` | Não tem |

## 5. _Testbench_ (`minisoc_spi_pll_tb`)

## 6. Execução e resultados

O comando `make` executa o _lint_, compilação e simulação dos quatro _testbenches_ do projeto. O _log_ completo está em `docs/reports/semana-05/semana-05-make.log`.
