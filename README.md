# RISC-V Emulator

This project is a toy RISC-V emulator built in [Zig](https://ziglang.org/). It is designed as a learning tool to understand how real systems operate, focusing on implementing key features of a RISC-V architecture, including instruction execution, memory management, and privilege levels. The long-term goal is to evolve the emulator into a platform capable of running a basic operating system with processes and concurrency.

## Features

- Implements the RISC-V RV32I base integer instruction set. [Done]
- Supports privilege levels, including Supervisor mode. [In-Progress]
- ELF file loading and execution. [Done]
- Zicsr extension for CSR (Control and Status Register) instructions. [In-Progress]
- Memory Management Unit (MMU). [To-Do]

## Getting Started

### Prerequisites

- [Zig](https://ziglang.org/download/) (latest stable version).
- A C compiler (required by Zig for certain dependencies).
- A Unix-like environment (Linux, macOS, or WSL for Windows).

### Building the Emulator

1. **Clone the Repository**

   ```bash
   git clone github.com/scpmx/risclet
   cd risclet
   ```

2. **Build the Project**

   Use Zig's build system to compile the project:

   ```bash
   zig build
   ```

   This will produce an executable in the `zig-out/bin` directory.

3. **Run the Emulator**

   Execute the emulator with an ELF file:

   ```bash
   ./zig-out/bin/risclet
   ```

   Replace `<path-to-elf-file>` with the path to the RISC-V binary you want to execute.

### Testing the Emulator

The project includes a suite of tests to verify its functionality. Run the tests using:

```bash
zig build test
```

## Contributing

Contributions are welcome! If you'd like to contribute, please fork the repository and submit a pull request. Make sure to include tests for any new features or bug fixes.

### Guidelines

- Follow the [Zig coding style](https://github.com/ziglang/zig/wiki/Coding-Style).
- Ensure all tests pass before submitting a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Acknowledgments

- [RISC-V Foundation](https://riscv.org/) for the open standard.
- The Zig community for the amazing language and tools.

---

Happy hacking!

