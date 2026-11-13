# [PT-BR] Relatório da semana 04 - trilha de Design RTL

## 1. Objetivo da semana

Implementar a expansão de chave AES-128 (`minisoc_aes_key_exp`) e o *datapath* que cifra e decifra um bloco de 128 bits (`minisoc_aes_dp`), com os *testbenches* que conferem os vetores da norma FIPS-197 nos dois sentidos. O *datapath* reutiliza as transformações de rodada das semanas 2 e 3 e segue a microarquitetura iterativa decidida na semana anterior, com uma rodada por ciclo.

## 2. Modificações e criações de arquivos no repositório

| Arquivo | Função |
| --- | --- |
| `rtl/minisoc_aes/minisoc_aes_key_exp.sv` | Expansão de chave pré-computada (11 chaves de rodada) |
| `rtl/minisoc_aes/minisoc_aes_dp.sv` | *Datapath* do AES-128 para realizar a cifragem e decifragem de um bloco. |
| `tb/minisoc_aes_key_exp_tb.sv` | *Testbench* do `minisoc_aes_key_exp.sb`. |
| `tb/minisoc_aes_dp_tb.sv` | *Testbench* do `minisoc_aes_dp.sv`. |
| `Makefile` e `scripts/arquivos.f` | O `make` roda os três *testbenches* do projeto de uma vez. |

## 3. Expansão de chave (`minisoc_aes_key_exp`)

A abordagem escolhida foi a pré-computada: as 11 chaves de rodada são calculadas uma única vez por sessão de configuração e guardadas em registradores. No código do `minisoc_aes_key_exp.sv`, o banco de registradores que guarda as chaves (`rk_q`) é estruturado como um vetor de 11 posições, onde cada posição armazena um valor de 128 bits:

- **Cálculo:** para expandir a chave, a cada ciclo, uma chave de rodada é gerada a partir da anterior (com as funções matemáticas **RotWord**, **SubWord** com 4 S-boxes reaproveitadas, constante **Rcon** e cadeia de XORs. Todas essas operações podem ser visualizadas no código do `minisoc_aes_key_exp.sv`). A expansão leva 10 ciclos de *clock*.
- **Interface:** `key_load_i` captura a chave na entrada `key_i` e inicia a expansão, `key_ready_o` indica que as chaves estão prontas, e o *datapath* lê uma chave por ciclo por `rk_sel_i` e `rk_o`. Sem chave pronta, `rk_o` vale 0.

A escolha da abordagem pré-computada foi por simplicidade na decifragem e na verificação nos *testbenches*, em troca da área, que tende a ser bem maior. Na outra abordagem, conhecida como *on-the-fly*, precisa-se expandir a chave a cada bloco (ou calcular e refazer a expansão de forma reversa para realizar a decifragem), repetindo toda a complexidade de cálculo a cada operação. Mas, na abordagem *on-the-fly* a área tende a ser bem menor.

## 4. *Datapath* AES-128 (`minisoc_aes_dp`)

O módulo do *datapath* instancia o módulo do `key_exp` e as transformações, e usa um registrador de estado de 128 bits com um contador de rodadas.

- **Interface do módulo `minisoc_aes_dp`:** `key_i`, `key_load_i`, `key_ready_o`, `data_i`, `decrypt_i`, `start_i`, `busy_o`, `done_o` e `data_o`.
    - **`key_i`**: barramento de entrada da chave-mestre (128 bits), que é entregue ao módulo para iniciar o processo de expansão de chaves.
    - **`key_load_i`**: sinal de comando que avisa o hardware para capturar a chave-mestre presente em `key_i` e reiniciar o cálculo das chaves de rodada.
    - **`key_ready_o`**: *flag* de *status* que indica quando o circuito terminou de calcular todas as 11 chaves de rodada e elas estão prontas para serem utilizadas.
    - **`data_i`**: barramento de entrada do bloco de dados (128 bits).
    - **`decrypt_i`**: define se o *datapath* vai operar cifrando (geralmente `0`) ou decifrando (`1`).
    - **`start_i`**: sinal de comando que inicia o processamento do bloco de dados atual (só é aceito se o *datapath* não estiver ocupado e as chaves estiverem prontas).
    - **`busy_o`**: *flag* de *status* (uma saída) que fica ativa (`1`) durante os ciclos de *clock* em que o *datapath* está processando o bloco de 128 bits (as 11 bordas de *clock*).
    - **`done_o`**: *flag* (que fica ativa por um ciclo de *clock*) para sinalizar que o processamento do bloco terminou e o resultado já pode ser lido.
    - **`data_o`**: barramento de saída do bloco de dados processado (128 bits), contendo o resultado final da cifragem ou da decifragem.
- **Latência:** são as 11 bordas de *clock* por bloco (1 de carga com a operação **AddRoundKey** inicial e 10 de rodadas). Em seguida, `done_o` sobe por um ciclo de *clock* e `data_o` guarda o resultado.
- **Cifragem:** rodadas 1 a 9 com **SubBytes**, **ShiftRows**, **MixColumns** e **AddRoundKey**, e a rodada 10 não tem **MixColumns**.
- **Decifragem:** usa as chaves em ordem inversa (no código, `rk[10-r]`), com **InvShiftRows**, **InvSubBytes**, **AddRoundKey** e **InvMixColumns**, e a última rodada não tem **InvMixColumns**.

## 5. Fluxo completo resumido com `minisoc_aes_dp` e `minisoc_aes_key_exp`

Em suma, o “embaralhamento” do dado na criptografia (`data_i`) acontece junto com todos os módulos do `minisoc_aes`, e principalmente em uma camada mais alta com `minisoc_aes_dp` e `minisoc_aes_key_exp` feitos nesta semana.

Assim que a *flag* `key_ready_o` do módulo do *datapath* fica ativa indicando que as chaves estão prontas, a FSM envia o sinal `start_i`. Na rodada inicial (ciclo 0), o *datapath* captura o dado de entrada (`data_i`) em um registrador de estado de 128 bits e realiza uma combinação com XOR (operação `AddRoundKey`) usando a primeira chave mestre (`rk_q[0]`). Nos 9 ciclos de clock seguintes (rodadas 1 a 9), o dado de 128 bits armazenado passa pelas quatro operações: substituição não linear de todos os bytes (`SubBytes`), permuta das linhas da matriz (`ShiftRows`), mistura algébrica das colunas (`MixColumns`) e um novo XOR com a chave da rodada atual (`AddRoundKey`, selecionada via `rk_sel_i`).

Na última rodada (rodada 10), o circuito executa o mesmo fluxo, mas ignora a etapa de `MixColumns`, aplicando apenas `SubBytes`, `ShiftRows` e o `AddRoundKey` final com a 11ª chave (`rk_q[10]`). Ao completar 11 bordas de *clock* (1 ciclo de carga inicial + 10 ciclos de rodadas), a *flag* `done_o` sobe por um ciclo, e o dado cifrado é disponibilizado na saída `data_o`. Só que esse dado é irreconhecível matematicamente, somente podendo ser decifrado com a chave-mestre do sistema (`key_i`).

## 6. *Testbenches*

Ambos os *testbenches* têm sinais de *clock* (ambos com frequência de 100 MHz), *reset* e *watchdog* contra travamento, e terminam com `PASS` ou `FAIL` (com `$fatal` em caso de falha).

- **`minisoc_aes_key_exp_tb`:** valida a operação da expansão de chaves `key_exp`. O ambiente do *testbench* confere o estado inicial pós-*reset*, depois calcula a expansão de 12 chaves (duas da FIPS-197 e 10 pseudoaleatórias, pré-computadas externamente) para verificar as 11 chaves de rodada e a latência de `key_ready_o`. Também testa a captura da chave no pulso de `key_load_i`, tentativas de recarga durante uma expansão, novos carregamentos com o circuito já pronto e a resposta a *resets* intermitentes. Tudo pode ser conferido no código em `tb/minisoc_aes_key_exp_tb.sv`.
- **`minisoc_aes_dp_tb`:** valida a cifragem e a decifragem no *datapath* ao longo de 12 vetores de teste, fazendo a combinação de casos da norma FIPS-197 com 10 cenários pseudoaleatórios para verificar as latências de expansão (`KEY_LAT`) e de bloco (`BLOCK_LAT`). Além disso, confirma a latência total de 11 ciclos por bloco, a sincronia dos sinais de *status* (`busy_o` e `done_o`), o travamento correto das entradas (`data_i` e `decrypt_i`) na subida do `start_i`, o descarte de comandos inválidos (como enviar `start_i` sem chave pronta ou durante o estado de `busy_o`), a execução em fluxo contínuo e a recuperação após *resets* durante a operação. E também a execução de falhas intencionais no RTL para verificar o `FAIL`. Tudo pode ser conferido no código em `tb/minisoc_aes_dp_tb.sv`.

## 6. Execução e resultados

O comando `make` executou o *lint*, compilação e simulação dos três *testbenches* do projeto. O *log* completo está neste repositório, em `docs/reports/semana-04/semana-04-make.log`.

| *Testbench* | Resultado |
| --- | --- |
| `minisoc_aes_transforms_tb` | `PASS: 1795 verificacoes, 0 erros` |
| `minisoc_aes_key_exp_tb` | `PASS: 325 verificacoes, 0 erros` |
| `minisoc_aes_dp_tb` | `PASS: 563 verificacoes, 0 erros` |

**Lint:** nenhum erro e nenhum aviso nos arquivos de RTL (`minisoc_aes_key_exp` e `minisoc_aes_dp`). Os 34 avisos `Lint-[NS] Null statement` que aparecem vêm dos *testbenches* novos (10 no `minisoc_aes_key_exp_tb` e 24 no `minisoc_aes_dp_tb`), causados pelas esperas `@(negedge clk);`. Estes são avisos que não possuem efeito na simulação. Na simulação do `minisoc_aes_key_exp` e do `minisoc_aes_dp` aparecem também avisos de execução `RT-NCMUCS`, que desaparecem em seguida e também não afetam o resultado.
