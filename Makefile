SHELL := /bin/bash

# Carregar ambiente da Synopsys:
SNPS_ENV = source /Tools/synopsys-scripts/snps.sh

# Ferramentas:
VCS = vcs
SIM_DIR  = sim
FILELIST = scripts/arquivos.f
SIM_EXEC = $(SIM_DIR)/simv

# Modulo de topo da simulacao (testbench). Trocar aqui quando o testbench principal do projeto mudar.
TOP ?= minisoc_aes_sbox_sub_shift_tb
TOP_FLAG = $(if $(TOP),-top $(TOP),)

# Flags de compilacao:
VCS_FLAGS = -full64 -sverilog -kdb -debug_access+all $(TOP_FLAG) -f $(FILELIST) -l $(SIM_DIR)/compile.log

.PHONY: all lint compile sim clean

all: lint sim
	@echo "[make] OK: lint, compilacao e simulacao concluidos com PASS."

# Target para checagem de sintaxe e linting:
lint:
	@mkdir -p $(SIM_DIR)
	@$(SNPS_ENV) && $(VCS) -full64 -sverilog +lint=all $(TOP_FLAG) -f $(FILELIST) \
		-Mdir=$(SIM_DIR)/csrc_lint -o $(SIM_DIR)/simv_lint -l $(SIM_DIR)/lint.log
	@echo "[lint] linhas de Lint/Warning em $(SIM_DIR)/lint.log: $$(grep -cE '^(Lint|Warning)-\[' $(SIM_DIR)/lint.log || true)"

# Target para compilacao:
compile:
	@mkdir -p $(SIM_DIR)
	@$(SNPS_ENV) && $(VCS) $(VCS_FLAGS) -o $(SIM_EXEC)

# Target para simulacao:
sim: compile
	@$(SNPS_ENV) && ./$(SIM_EXEC) -l $(SIM_DIR)/sim.log; \
	if grep -q "^PASS" $(SIM_DIR)/sim.log; then \
		echo "[sim] PASS"; \
	else \
		echo "[sim] FALHOU: linha PASS nao encontrada em $(SIM_DIR)/sim.log"; exit 1; \
	fi

# Limpeza de artefatos do VCS, DVE e Verdi:
clean:
	rm -rf $(SIM_DIR) csrc simv simv.daidir ucli.key DVEfiles verdiLog novas* *.fsdb *.vpd *.vcd
