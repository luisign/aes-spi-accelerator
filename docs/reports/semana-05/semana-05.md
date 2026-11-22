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

O módulo do protocolo SPI foi implementado nesta semana, com as entradas do SPI `spi_sclk`, `spi_cs_n` e `spi_mosi`, e com a saída `spi_miso`. Esses sinais devem ser a comunicação entre o usuário e o módulo. O `spi_sclk` é o _clock_ dos bits enviados, o `spi_cs_n` avisa quando uma comunicação SPI começa e termina (em `0` durante a comunicação com o usuário), o `spi_mosi` é por onde o usuário envia os bits para o chip, e o `spi_miso` é por onde o chip devolve os bits quando o usuário pede para ler um registrador.

Além disso, há as saídas de configuração da lógica AES: `cfg_key_o`, `cfg_iv_o`, `cfg_counter_o`, `cfg_num_blocks_o`, `cfg_mode_o`, `cfg_decrypt_o` e `aes_start_o`. Esses sinais são os valores que o usuário escreve nos registradores e que o AES utiliza: a chave de criptografia, o vetor inicial (IV), o contador, a quantidade de blocos, o modo de operação (`ECB`, `CBC`, etc.) e se a operação é de cifrar ou decifrar. O `aes_start_o` é diferente dos outros: ele dá um pulso de 1 ciclo de _clock_ quando o usuário manda o `START`, e é gerado se o PLL estiver travado (`PLL_LOCKED = 1`).

Também há os sinais de controle do sistema (`mem_sel_aes_o`, `pll_enable_o` e `pll_div_sel_o`), que controlam as partes do sistema que ficam fora do AES: o `mem_sel_aes_o` escolhe quem usa a memória (`0` = usuário, pela interface `MEMORY DATA`, e `1` = AES), o `pll_enable_o` liga o PLL e o `pll_div_sel_o` escolhe a velocidade do _clock_ do sistema (`/1`, `/2`, `/4` ou `/8`), e os sinais de status do domínio `clk`, que são `aes_busy_i`, `aes_done_i`, `aes_error_i`, `aes_blocks_done_i` e `pll_locked_i`, que são informações que chegam de outros módulos para o SPI, para que o usuário possa consultá-las lendo os registradores de status, por exemplo: se o AES está ocupado (`busy`), se terminou (`done`), se houve erro de configuração (`error`), quantos blocos já foram processados (`blocks_done`) e se o PLL já está pronto (`pll_locked`).

Em resumo, a comunicação com o chip segue o protocolo SPI no _mode_ 0. Esse modo define quando cada bit deve ser lido: o `spi_sclk` fica em `0` quando está parado, o chip lê o bit que chega pelo `spi_mosi` na borda de subida do _clock_ e atualiza o bit que sai pelo `spi_miso` na borda de descida. Os bits são enviados começando pelo bit mais significativo, o mais à esquerda do número, como se lê um número da esquerda para a direita.

Cada mensagem, chamada de _frame_, tem sempre 40 bits, divididos em quatro campos: `RWb` (1 bit), que diz se o usuário quer escrever (`0`) ou ler (`1`), `ADDR[5:0]` (6 bits), que é o endereço do registrador usado, `RSV` (1 bit), um bit reservado que deve ser enviado sempre como `0`, e `DATA[31:0]` (32 bits), o valor a ser escrito, que é ignorado quando o frame é um pedido de leitura.

A escrita é feita em uma única transação, ou seja, um _frame_ com o endereço e o valor. A leitura é feita em duas transações, porque o chip precisa de um tempo para preparar a resposta, que seria: na primeira (`RWb = 1`), o usuário informa o endereço do registrador que quer ler, e o chip guarda uma cópia do valor dele. Na segunda transação, o usuário envia um frame com o endereço `0x3F`, chamado `NOP` (do inglês _no operation_, "nenhuma operação"), que não escreve nem lê nada e serve apenas para o usuário continuar gerando _clock_ enquanto o chip devolve, bit a bit, o valor guardado pelo `spi_miso`.

### 4.1. Decisões de CDC

O módulo trabalha com dois sinais de _clock_: o `spi_sclk` (até 25 MHz), do usuário, e o `clk` (2 GHz), que roda os registradores. Misturar dados entre dois relógios pode fazer o circuito ler um valor errado ou instável, e por isso o módulo usa uma técnica de sincronização por _toggle_, como já explicado em _report_ de semanas anteriores.

Os 40 bits do _frame_ chegam em `spi_sclk` e, quando o 40º bit é recebido, o frame completo é guardado em um registrador (`frame_hold_q`) e um sinal sincronizado chamado `frame_tog_q` inverte (de `0` para `1`, ou de `1` para `0`). No lado do `clk`, esse sinal passa por três flip-flops em sequência. Os dois primeiros flip-flops (`tog_s1_q` e `tog_s2_q`) fazem valor se estabilizar, e o terceiro (`tog_s3_q`) guarda o valor anterior. Quando `tog_s2_q` e `tog_s3_q` ficam diferentes, o módulo sabe que chegou um _frame_ novo, e gera o sinal `frame_valid`, que dura 1 ciclo de `clk`. Então, o _frame_ é lido e executado.

### 4.2. Registradores

Presente no código por sinais `localparam`, seguindo o mapa de registradores do documento de especificação _Block Guide_.

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

Os registradores de somente leitura (R) (`AES_STATUS`, `VERSION` e `SYSTEM_STATUS`) não mudam quando o usuário tenta escrevê-los, os bits reservados (sem função) leem sempre `0`, o bit `START` do `AES_CONTROL` é um _write-one-pulse_, ou seja, escrever `1` gera um pulso de 1 ciclo e o bit volta a `0`, então ele sempre lê `0`. Além disso, um endereço não mapeado devolve `0` na leitura e é ignorado na escrita, e no _reset_ do sistema, todos os registradores voltam a `0`, exceto o registrador `VERSION`, que é uma constante (`0x0001_0000`).

## 5. _Testbench_ (`minisoc_spi_pll_tb`)

## 6. Execução e resultados

O comando `make` executa o _lint_, compilação e simulação dos quatro _testbenches_ do projeto. O _log_ completo está em `docs/reports/semana-05/semana-05-make.log`.
