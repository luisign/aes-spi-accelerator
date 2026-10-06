# Low-Power AES Accelerator with SPI Interface

This repository contain the SystemVerilog RTL implementation of a low-power Advanced Encryption Standard (AES) hardware accelerator controlled via a Serial Peripheral Interface (SPI). The project will cover the complete digital IP design flow, including microarchitecture, synthesis, formal verification, and power intent specification using UPF.

This project is part of the Brazilian microelectronics training program CI Expert, carried out by the Federal University of Campina Grande (UFCG), with support from Synopsys and coordinated by Softex. The program is an initiative of the Brazilian Ministry of Science, Technology and Innovation (MCTI) and Chip Tech Brasil.

## Repository structure

```
.
├── docs/
│   ├── spec/            # Functional specification
│   ├── architecture/    # System and power architecture
│   └── reports/         # Weekly reports
├── rtl/                 # RTL source code
├── models/              # Simple PLL and memory models
├── tb/                  # Testbenches
├── formal/              # Formality scripts and reports
├── syn/                 # SDC, synthesis scripts and reports
├── upf/                 # UPF files and reports
├── scripts/             # Flow automation (including file lists)
└── Makefile             # Entry point for the flow
```

Folders that are still empty are kept with a `.gitkeep` file and will be populated as the project progresses.

## Requirements

- Synopsys VCS (compilation, lint and simulation);
- Synopsys environment script.

## Documentation

- Functional specification: [`docs/spec/`](docs/spec/);
- Architecture: [`docs/architecture/`](docs/architecture/);
- Weekly reports: [`docs/reports/`](docs/reports/).

## Project management

Track the project backlog, tasks, and roadmap on the [GitHub project board](https://github.com/users/luisign/projects/1).
