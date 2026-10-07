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
