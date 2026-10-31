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

## 3. Geração por Python e implementação RTL da S-box (arquivos `gen_sbox.py` e `minisoc_aes_sbox.sv`)

A S-box do AES é um bloco de substituição não-linear que mapeia um valor de entrada de 8 bits para um novo valor de 8 bits. Ela é a única etapa não-linear do algoritmo AES, por isso então possui a propriedade de confusão necessária para a criptografia.

Para evitar o preenchimento manual e suscetível a erros dessa tabela, o desenvolvimento iniciou-se pela automação do processo através do _script_ Python `scripts/gen_sbox.py`. Ele calcula os valores de substituição segundo as duas etapas definidas pela FIPS-197:
1. Inverso multiplicativo no corpo finito **GF(2⁸)** com o polinômio irredutível **m(x) = x⁸ + x⁴ + x³ + x + 1 (`0x11B`)**, mapeando `0x00` para `0x00`.
2. Transformação afim combinando rotações de bits e operação de XOR com a constante `0x63`.

```python
def sbox_value(x: int) -> int:
    """b' = b ^ rotl(b,1) ^ rotl(b,2) ^ rotl(b,3) ^ rotl(b,4) ^ 0x63, com b = inv(x)."""
    b = gf_inv(x)
    return b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 0x63
```
## 4. Módulos SubBytes e ShiftRows

Após a passagem pela S-box, o _datapath_ do AES opera em cima de um bloco de dados de **128 bits**. Os módulos `SubBytes` e `ShiftRows` implementam as duas primeiras etapas de transformação de cada rodada do algoritmo, explicadas a seguir.

### 4.1. Módulo SubBytes (`minisoc_aes_sub_bytes.sv`)

O módulo `SubBytes` tem a função de aplicar a substituição não-linear de bytes em todo o estado de 128 bits. Como cada bloco AES possui 16 bytes, o circuito fatia o barramento de entrada em 16 partes iguais e instancia 16 cópias do módulo `minisoc_aes_sbox`.

A implementação utiliza um _loop_ `generate` em SystemVerilog para mapear os bytes, respeitando a convenção em que o byte **0** fica nos bits mais significativos (`[127:120]`) e o byte **15** nos bits menos significativos (`[7:0]`):

```systemverilog
module minisoc_aes_sub_bytes (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  genvar n;
  generate
    for (n = 0; n < 16; n++) begin : g_sbox
      minisoc_aes_sbox u_sbox (
        .data_i (state_i[127 - 8*n -: 8]),
        .data_o (state_o[127 - 8*n -: 8])
      );
    end
  endgenerate

endmodule
```

### 4.2. Módulo ShiftRows (`minisoc_aes_shift_rows.sv`)

O módulo **ShiftRows** realiza uma operação de reordenação estrutural (deslocamento cíclico à esquerda) sobre as linhas da matriz de estado de 128 bits, como explicado no relatório da semana 01.
Este bloco, também combinacional, atua como um roteamento de fios, implementado por meio de um duplo _loop_ `generate` para linhas (`r`) e colunas (`c`):

```systemverilog
module minisoc_aes_shift_rows (
  input  logic [127:0] state_i,
  output logic [127:0] state_o
);

  genvar r, c;
  generate
    for (c = 0; c < 4; c++) begin : g_col
      for (r = 0; r < 4; r++) begin : g_row
        assign state_o[127 - 8*(r + 4*c) -: 8] =
               state_i[127 - 8*(r + 4*((c + r) % 4)) -: 8];
      end
    end
  endgenerate

endmodule
```

## 5. _Testbench_ (`minisoc_aes_sbox_sub_shift_tb.sv`)

O _testbench_ automatiza os estímulos e compara as saídas do hardware simulado (*DUT*) com modelos de referência e vetores do padrão FIPS-197. Ele valida os três componentes desenvolvidos na semana por meio dos seguintes pontos:

- Testa as combinações possíveis de 8 bits (`0x00` a `0xFF`) no módulo `minisoc_aes_sbox`, comparando o resultado com um modelo matemático de referência no próprio _testbench_ (`sbox_ref`), e valida os pontos de ancoragem da norma FIPS-197 (`sbox(8'h00) = 8'h63` e `sbox(8'h53) = 8'hed`);
- Aplica os vetores de estado de entrada da FIPS-197 e verifica se a saída do módulo `minisoc_aes_sub_bytes` corresponde aos valores esperados de substituição ao longo de múltiplas rodadas;
- Encadeia a saída do estágio anterior para testar o módulo `minisoc_aes_shift_rows`, para conferir a reordenação das linhas do estado em relação aos vetores de referência.
O código utiliza funções para simular o comportamento matemático do corpo finito (**GF(2⁸)**) e tarefas (`check8` e `check128`) para contagem de erros e exibição de _logs_ desses erros:
```systemverilog
module minisoc_aes_sbox_sub_shift_tb;

  // Instanciações dos DUTs:
  logic [7:0] sbox_in, sbox_out;
  logic [127:0] sb_in, sb_out;
  logic [127:0] sr_in, sr_out;

  minisoc_aes_sbox u_sbox (.data_i(sbox_in), .data_o(sbox_out));
  minisoc_aes_sub_bytes u_sub (.state_i(sb_in), .state_o(sb_out));
  minisoc_aes_shift_rows u_shift (.state_i(sr_in), .state_o(sr_out));

  // Contadores de status:
  int errors = 0;
  int checks = 0;

  initial begin
    // Validação da S-Box (256 entradas + pontos FIPS-197):
    for (int i = 0; i < 256; i++) begin
      sbox_in = i[7:0];
      #1;
      if (sbox_out !== sbox_ref(i[7:0])) errors++;
    end

    // Validação do SubBytes com vetores da FIPS-197:
    for (int r = 0; r < 10; r++) begin
      sb_in = vec_start[r];
      #1;
      if (sb_out !== vec_sub[r]) errors++;
    end

    // Validação do ShiftRows:
    for (int r = 0; r < 10; r++) begin
      sr_in = vec_sub[r];
      #1;
      if (sr_out !== vec_shift[r]) errors++;
    end

    // Encerramento e verificação de sucesso:
    if (errors == 0) begin
      $display("PASS: Todas as verificacoes concluídas com 0 erros.");
      $finish;
    end else begin
      $fatal(1, "Testbench falhou com %0d erro(s).", errors);
    end
  end

endmodule
```

## 6. Execução e critério de aceite

O fluxo completo de compilação, _lint_ e simulação é acionado através do comando `make` integrando o arquivo de listagem de compilação (`scripts/arquivos.f`). O critério de aceite foi atingido, como é possível observar no arquivo de _log_ em `docs/reports/semana-02/semana-02-make.log`.
As verificações foram:
| Verificação | Quantidade | Erros |
|---|---|---|
| S-box, 256 entradas vs. referência do _testbench_ | 256 | 0 |
| S-box, valores da FIPS-197 (`00→63`, `53→ed`) | 2 | 0 |
| **SubBytes**, rodadas 1 a 10 | 10 | 0 |
| **ShiftRows**, rodadas 1 a 10 | 10 | 0 |
| **Total** | **278** | **0** |

Resultado: `PASS: 278 verificacoes, 0 erros`. _Lint_ com 6 avisos `Lint-[NS] Null statement`, todos no _testbench_.
