SHELL := /bin/bash

# Carregar ambiente da Synopsys:
SNPS_ENV = source /Tools/synopsys-scripts/snps.sh

# Ferramentas:
VCS = vcs
SIM_DIR = sim
FILELIST = scripts/arquivos.f

# Testbenches (modulos de topo) executados pelo pelo comando make. Cada um tem a sua pasta em sim/ com os seus logs. Para rodar so alguns:
# make TOPS=minisoc_aes_dp_tb
# make sim_minisoc_aes_key_exp_tb (um unico testbench: lint_<tb>, compile_<tb>, sim_<tb>)

TOPS ?= minisoc_aes_transforms_tb minisoc_aes_key_exp_tb minisoc_aes_dp_tb

# Flags de compilacao:
VCS_FLAGS = -full64 -sverilog -kdb -debug_access+all -f $(FILELIST)

.PHONY: all lint compile sim clean
.PHONY: $(addprefix lint_,$(TOPS)) $(addprefix compile_,$(TOPS)) $(addprefix sim_,$(TOPS))

# O comando make sozinho roda lint e simulacao de TODOS os testbenches.
# Para na primeira falha (o make retorna erro).
all: lint sim
	@echo "[make] OK: lint, compilacao e simulacao concluidos com PASS em: $(TOPS)"

lint: $(addprefix lint_,$(TOPS))
compile: $(addprefix compile_,$(TOPS))
sim: $(addprefix sim_,$(TOPS))

# Checagem de sintaxe e linting de um testbench:
$(addprefix lint_,$(TOPS)): lint_%:
	@mkdir -p $(SIM_DIR)/$*
	@$(SNPS_ENV) && $(VCS) -full64 -sverilog +lint=all -top $* -f $(FILELIST) \
		-Mdir=$(SIM_DIR)/$*/csrc_lint -o $(SIM_DIR)/$*/simv_lint -l $(SIM_DIR)/$*/lint.log
	@echo "[lint] $*: linhas de Lint/Warning em $(SIM_DIR)/$*/lint.log: $$(grep -cE '^(Lint|Warning)-\[' $(SIM_DIR)/$*/lint.log || true)"

# Compilacao de um testbench:
$(addprefix compile_,$(TOPS)): compile_%:
	@mkdir -p $(SIM_DIR)/$*
	@$(SNPS_ENV) && $(VCS) $(VCS_FLAGS) -top $* -Mdir=$(SIM_DIR)/$*/csrc \
		-o $(SIM_DIR)/$*/simv -l $(SIM_DIR)/$*/compile.log

# Simulacao de um testbench. Falha (make retorna erro) se a linha "PASS" nao aparecer no log.
$(addprefix sim_,$(TOPS)): sim_%: compile_%
	@$(SNPS_ENV) && ./$(SIM_DIR)/$*/simv -l $(SIM_DIR)/$*/sim.log; \
	if grep -q "^PASS" $(SIM_DIR)/$*/sim.log; then \
		echo "[sim] $*: $$(grep '^PASS' $(SIM_DIR)/$*/sim.log)"; \
	else \
		echo "[sim] $*: FALHOU: linha PASS nao encontrada em $(SIM_DIR)/$*/sim.log"; exit 1; \
	fi

# Limpeza de artefatos do VCS, DVE e Verdi:
clean:
	rm -rf $(SIM_DIR) csrc simv simv.daidir ucli.key DVEfiles verdiLog novas* *.fsdb *.vpd *.vcd
