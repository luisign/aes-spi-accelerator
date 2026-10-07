# [PT-BR] Relatório da semana 01 - Trilha de design RTL

## 1. Objetivo da semana

O presente relatório aborda de forma geral o que foi realizado na semana 01 da trilha de Design RTL do programa CI Expert. Ela teve como objetivo estudar os fundamentos do projeto (algoritmo AES (FIPS-197), protocolo SPI e arquitetura do sistema de topo) e preparar o ambiente de trabalho com repositório, teste de fluxo de compilação, _lint_ e simulação com as ferramentas da Synopsys com um arquivo _dummy_, e _backlog_ inicial no GitHub Project.

### 2.2. Estrutura dos dados e preenchimento (_padding_)

A criptografia AES, como abordada anteriormente, processa os dados dentro de blocos fixos de 128 bits ou 16 bytes. Um caractere possui um byte. E cada bloco de 16 bytes é organizado dentro de uma matriz 4x4 de forma coluna por coluna (de cima para baixo, e da esquerda para a direita). A seguir, um exemplo com a mensagem de 16 bytes: `"CriptografiaAES!"`:

```text
Entrada (16 bytes): [C][r][i][p][t][o][g][r][a][f][i][a][A][E][S][!]

Matriz de Estado (4x4):
[ C ]  [ t ]  [ a ]  [ A ]   <- Linha 0 (Bytes 0, 4, 8, 12)
[ r ]  [ o ]  [ f ]  [ E ]   <- Linha 1 (Bytes 1, 5, 9, 13)
[ i ]  [ g ]  [ i ]  [ S ]   <- Linha 2 (Bytes 2, 6, 10, 14)
[ p ]  [ r ]  [ a ]  [ ! ]   <- Linha 3 (Bytes 3, 7, 11, 15)
```
