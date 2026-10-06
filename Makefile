SHELL := /bin/bash

#Carregar ambiente novo da Synopsys:
SNPS_ENV = source /Tools/synopsys-scripts/snps.sh

#Ferramentas:
VCS = vcs
SIM_DIR = sim
FILELIST = scripts/arquivos.f
SIM_EXEC = $(SIM_DIR)/simv

#Flags de compilacao:
VCS_FLAGS = -full64 -sverilog -kdb -debug_access+all -f $(FILELIST) -l $(SIM_DIR)/compile.log

.PHONY: all lint compile sim clean

all: lint sim

#Target para checagem de sintaxe e linting:
lint:
	@mkdir -p $(SIM_DIR)
	@$(SNPS_ENV) && $(VCS) -full64 -sverilog +lint=all -f $(FILELIST) -l $(SIM_DIR)/lint.log

#Target para compilacao:
compile:
	@mkdir -p $(SIM_DIR)
	@$(SNPS_ENV) && $(VCS) $(VCS_FLAGS) -o $(SIM_EXEC)

#Target para simulacao:
sim: compile
	@$(SNPS_ENV) && ./$(SIM_EXEC) -l $(SIM_DIR)/sim.log

#Limpeza de artefatos do VCS, DVE e Verdi:
clean:
	rm -rf $(SIM_DIR) csrc simv simv.daidir ucli.key DVEfiles verdiLog novas* *.fsdb *.vpd *.vcd
