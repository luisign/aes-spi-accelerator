# [PT-BR] Relatório da semana 01 - trilha de design RTL

## 1. Objetivo da semana

O presente relatório aborda de forma geral o que foi realizado na semana 01 da trilha de Design RTL do programa CI Expert. Ela teve como objetivo estudar os fundamentos do projeto (algoritmo AES (FIPS-197), protocolo SPI e arquitetura do sistema de topo) e preparar o ambiente de trabalho com repositório, teste de fluxo de compilação, _lint_ e simulação com as ferramentas da Synopsys com um arquivo _dummy_, e _backlog_ inicial no GitHub Project.

## 2. Estudo do algoritmo AES (FIPS-197)

### 2.1. Visão geral e padrão FIPS-197

O AES (_Advanced Encryption Standard_) é um tipo de criptografia simétrica (ou seja, utiliza uma chave secreta que criptografa e descriptografa dados) baseado em cifra de bloco. A criptografia AES é especificada em diversas normas, como ISO/IEC 18033-3, NIST SP 800-38 e IETF RFCs, mas o tipo de norma que será utilizada neste projeto é FIPS-197. Por meio da padronização FIPS-197, a criptografia AES aceita blocos fixos de 128 bits (16 bytes) e três tamanhos de chave (128, 192 e 256 bits).

### 2.2. Estrutura dos dados e preenchimento (_padding_)

A criptografia AES, como abordada anteriormente, processa os dados dentro de blocos fixos de 128 bits ou 16 bytes. Um caractere possui um byte. E cada bloco de 16 bytes é organizado dentro de uma matriz 4x4 de forma coluna por coluna (de cima para baixo, e da esquerda para a direita). A seguir, um exemplo com a mensagem de 16 bytes: `"CriptografiaAES!"`:

```text
Entrada (16 bytes): [C][r][i][p][t][o][g][r][a][f][i][a][A][E][S][!]

Matriz de Estado (4x4):
[ C ]  [ t ]  [ a ]  [ A ]   <- Linha 0 (bytes 0, 4, 8, 12)
[ r ]  [ o ]  [ f ]  [ E ]   <- Linha 1 (bytes 1, 5, 9, 13)
[ i ]  [ g ]  [ i ]  [ S ]   <- Linha 2 (bytes 2, 6, 10, 14)
[ p ]  [ r ]  [ a ]  [ ! ]   <- Linha 3 (bytes 3, 7, 11, 15)
```
#### 2.2.2. Regra de preenchimento PKCS#7 (PKCS#7 _padding_)

Se o texto ou dado original não for múltiplo de 16 bytes, o PKCS#7 _padding_ adiciona bytes para preencher o bloco de 16 bytes. O valor do byte adicionado é igual à quantidade de bytes faltantes. Ou seja, se faltarem 9 bytes, essa regra de preenchimento adiciona 9 bytes de valor hexadecimal `0x09`. Na descriptografia, é lido o último byte e removido o preenchimento descartando a quantidade indicada por esse valor.

### 2.3. As 4 etapas da criptografia AES

Após a criação da matriz 4x4, cada rodada do algoritmo AES aplica as seguintes transformações matemáticas sobre a matriz de dados, em sequência:

* **SubBytes (substituição de bytes):** substitui cada byte da matriz por outro usando uma tabela de troca pública chamada “S-Box”, da norma FIPS-197;
* **ShiftRows (deslocamento de linhas):** desloca as linhas da matriz para a esquerda de forma circular. Então, linha 0 desloca 0 posições para a esquerda, linha 1 desloca 1 posição para a esquerda, linha 2 desloca 2 posições para a esquerda e linha 3 desloca 3 posições para a esquerda;
* **MixColumns (mistura de colunas):** multiplica cada coluna da matriz de dados isoladamente por uma matriz fixa usando matemática de campos finitos ou Galois field (especificamente GF(2⁸)), onde cada byte da nova coluna depende dos 4 bytes da coluna antiga. Se mudar uma letra do texto original, o MixColumns faz com que os 4 bytes da coluna desta letra mudem também. Isso impede que alguém tente adivinhar o texto por partes.
* **AddRoundKey (aplicação da chave simétrica/subchaves):** combina a matriz resultante da última operação com uma subchave única de rodada usando a operação lógica XOR. A subchave é derivada da chave simétrica principal. A cada rodada, é utilizada uma subchave diferente.

### 2.4. Níveis de segurança e fluxo das rodadas

O número de repetições (rodadas) do ciclo depende do tamanho da chave escolhida. Como visto, a criptografia AES divide o dado em blocos de 128 bits (16 bytes), e as chaves podem ser de 3 variações: 128 bits (16 bytes), 192 bits (24 bytes) e 256 bits (32 bytes). Quanto maior o tamanho da chave, maior a quantidade de subchaves geradas e rodadas. Veja a tabela:

| Variação | Tamanho da chave | Subchaves geradas | Rodadas |
| :---: | :---: | :---: | :---: |
| AES-128 | 128 bits (16 bytes) | 11 subchaves | 10 rodadas |
| AES-192 | 192 bits (24 bytes) | 13 subchaves | 12 rodadas |
| AES-256 | 256 bits (32 bytes) | 15 subchaves | 14 rodadas |

## 3. Estudo do protocolo SPI
