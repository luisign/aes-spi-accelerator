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

A memória é uma matriz de 1024 palavras de 32 bits, *single-port* síncrona e sem *reset* (o conteúdo não é apagado pelo *reset*). A escrita grava na borda de subida do *clock* da RAM e a leitura entrega o dado 1 ciclo depois, e a saída mantém o último valor lido durante uma escrita.

Além disso, a posse de memória é realizada pelo sinal `MEM_SEL_AES`. `MEM_SEL_AES = 0` dá a memória à interface `MEMORY_DATA` (`mem_clk`, `mem_i_*`) e `1` ao AES (`sys_clk`, endereço, dado e escrita do AES).

Para alternar o sinal de *clock* da memória entre dois domínios assíncronos, utiliza-se um multiplexador de *clock* sem falhas. Nesse circuito, cada domínio de *clock* possui seu próprio ramo de *clock* controlado (uma espécie de *clock gating*), composto por uma porta lógica de habilitação precedida por um *latch* transparente (tipo D) ativo em nível lógico `0`. Esse *latch* faz com que o *clock* de cada ramo só seja ligado ou desligado quando estiver em nível lógico `0`, para evitar o corte de pulsos pela metade. Por fim, as saídas dos dois ramos são combinadas por meio de uma operação lógica **OR**, para a memória ter um sinal de *clock* limpo vindo do domínio ativo no momento.

Os dois *clocks* devem estar rodando durante a troca de posse, `MEM_SEL_AES` deve ficar estável por cerca de 10 ciclos do *clock* mais lento entre trocas, e a troca só ocorre com o AES ocioso.

## 4. _Engine_ AES (`minisoc_aes_top`)

O módulo instancia o `minisoc_aes_dp` (o *datapath* de núcleo iterativo de uma rodada por ciclo) e segue a FSM do documento de microarquitetura: `IDLE` → `CHECK` → `KEY_LOAD` → `KEY_WAIT` → (por bloco: `RD` → `CORE_START` → `CORE_WAIT` → `POST` → `WR`) → `FIN` (ou `ERR` se a configuração for inválida).

`KEY`, `IV`, `COUNTER`, `MODE`, `DECRYPT` e `NUM_BLOCKS` são capturados no ciclo em que o `START` é aceito, e mudar os registradores depois não afeta a operação. O `START` com `BUSY = 1` é ignorado.

O acesso à memória pela *engine* AES ocorre da seguinte forma: para cada bloco, lê 4 palavras (5 ciclos, pela latência de 1 ciclo), processa no núcleo e escreve as 4 palavras no mesmo endereço de memória. O bloco lido fica em um registrador até o `POST`, para evitar perder o texto cifrado do **CBC**.

Por falar no modo **CBC**, os modos implementados na *engine* AES são **ECB** (`MODE = 000`), **CBC** (`001`) e **CTR** (`101`), cifrando e decifrando.

## 5. Modelo de referência (`scripts/gen_vectors.py`)

O _script_ implementa em Python o AES-128 da FIPS-197 e os modos **ECB**, **CBC** e **CTR**, e gera os vetores esperados para 1, 2 e 256 blocos em cada modo e sentido (18 casos), mais 4 casos de configuração inválida. O modelo realiza sua autochecagem a cada execução com os vetores da FIPS-197, da NIST SP 800-38A (**ECB** e **CBC** com AES-128 e o primeiro bloco do CTR).

Se disponível, ele também utiliza a biblioteca `pycryptodome`. A geração é determinística. No **CTR** de 256 blocos o contador começa em `0x00000000FFFFFF80` para exercitar a passagem de `COUNTER_LO` para `COUNTER_HI`.

## 6. _Testbench_ de bloco (`minisoc_aes_top_tb`)

O novo _testbench_ liga o `minisoc_aes_top` ao `minisoc_memory`, com `mem_clk` e `sys_clk` assíncronos (com períodos de 10 e 14), e lê os vetores de `tb/vectors/` com `$readmemh`. Cada caso grava a região de entrada pela interface `MEMORY_DATA`, entrega a memória ao AES, dá o `START`, devolve a memória e lê os 1024 endereços dela. Ele gera o _clock_/_reset_ e um _watchdog_, e termina com `PASS` ou `FAIL`.

## 7. Execução e resultados

O comando `make` executa _lint_, compilação e simulação dos cinco _testbenches_ do projeto. O _log_ completo está em `docs/reports/semana-06/semana-06-make.log`.

| _Testbench_ | Simulação | _Lint_ |
|---|---|---|
| `minisoc_aes_transforms_tb` | `PASS: 1795 verificacoes, 0 erros` | `0` |
| `minisoc_aes_key_exp_tb` | `PASS: 325 verificacoes, 0 erros` | `0` |
| `minisoc_aes_dp_tb` | `PASS: 563 verificacoes, 0 erros` | `0` |
| `minisoc_spi_pll_tb` | `PASS: 393 verificacoes, 0 erros` | `0` |
| `minisoc_aes_top_tb` | `PASS: 33041 verificacoes, 0 erros` | `0` |
 
O _lint_ não deu nenhum erro e nenhum aviso no projeto, inclusive nos dois módulos novos. A ferramenta não apontou os _latches_ de _clock gating_ da memória, que são intencionais.
 
**Avisos de execução:** nos _testbenches_ que instanciam o núcleo (`key_exp_tb`, `dp_tb` e `aes_top_tb`) aparecem avisos `RT-NCMUCS` no instante `0`, por causa das entradas das S-boxes ainda em `X` antes do _reset_ agir (4 no `key_exp_tb`, 20 no `dp_tb` e 20 no `aes_top_tb`). Estes avisos desaparecem em seguida e não afetam o resultado.

**Critério de aceite:**
 
| Critério | Situação |
|---|---|
| **ECB**, **CBC** e **CTR** conferem com o modelo de referência nos dois sentidos | Atendido |
| `ERROR` sinalizado nas configurações inválidas | Atendido |
| _Lint_ sem erros | Atendido (0 avisos) |

## 8. Limitações

A principal limitação é a implementação dos modos **PCBC**, **CFB** e **OFB**, que não foram implementados. Estão previstos para a semana 10. Nesta versão eles geram `ERROR` em vez de processar de forma incorreta. Isso desvia da especificação do _Block Guide_, que lista esses modos como válidos.
