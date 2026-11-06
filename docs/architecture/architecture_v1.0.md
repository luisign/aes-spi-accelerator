# [PT-BR] Microarquitetura do Mini-SoC AES (v1.0) - trilha de Design RTL

O presente documento apresenta o detalhamento da microarquitetura do sistema do acelerador AES com interface SPI (v1.0).

## 1. Microarquitetura do sistema (`minisoc_top`)
 
O `minisoc_top` integra quatro blocos, que são:  **SPI** (controle de dados por meio do protocolo SPI), o **PLL** (geração do sinal de _clock_), o **AES** (os módulos responsáveis pela criptografia em si) e a **memória compartilhada** (1024 x 32 bits). O usuário usa o **SPI** para configurar o sistema e a interface **MEMORY DATA** para ler e escrever a memória, como explicado pelo documento _Block Guide_ do MiniSoC AES.

### 1.1. Operação do sistema

1. O usuário grava os blocos de entrada na memória pela interface **MEMORY DATA**.
2. Pelo **SPI**, configura chave, modo e número de blocos, e habilita o _mock_ do **PLL**.
3. Quando o **PLL** indica `locked`, o `sys_clk` é liberado para o **AES**.
4. O usuário entrega a memória ao **AES** (`MEM_SEL_AES = 1`) e envia `START`.
5. O **AES** processa os blocos, sobrescrevendo-os na própria memória, e o _status_ indica `DONE`.
6. O usuário devolve a memória (`MEM_SEL_AES = 0`) e lê os resultados.

## 2. Microarquitetura do AES (`minisoc_aes`)

A microarquitetura escolhida para o AES é iterativa, com uma rodada por ciclo de _clock_. Um único bloco de rodada (**SubBytes, ShiftRows, MixColumns** e **AddRoundKey**) é reaproveitado 10 vezes, com um registrador de estado de 128 bits que guarda o resultado de cada rodada e o realimenta na entrada do mesmo bloco. Antes da primeira rodada há um ciclo de carga, em que o dado passa pelo **AddRoundKey**, então cada bloco leva 11 ciclos no núcleo (AES-128). Como a última rodada não tem **MixColumns**, o circuito a contorna.

Na decifragem, o mesmo esquema usa as transformações inversas (**InvShiftRows, InvSubBytes** e **InvMixColumns**) e as chaves de rodada em ordem inversa. As chaves são geradas pelo **minisoc_aes_key_exp**, uma por ciclo, e guardadas em registradores.
