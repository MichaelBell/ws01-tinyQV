# TinyQV for Wafer Space run 1

This is a version of TinyQV ported for the Wafer Space template, incorporating a number of peripherals from the Tiny Tapeout Risc-V competition.

TinyQV is an RV32EC SoC.  It executes instructions directly from a QSPI flash (e.g. WS25Q128JVSIQ), and uses one or two QSPI APS6404 PSRAMs for RAM.

It includes:

* UART, [SPI](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/30_spi.md) and [PWM](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/21_matt_pwm.md) peripherals
* Tiny Tapeout [Gamepad Pmod](https://tinytapeout.com/specs/pinouts/#game-controllers) support
* [AY8913](https://github.com/TinyTapeout/ttsky25a-tinyQVb/blob/main/docs/user_peripherals/20_AY8913.md) and [PWL synth](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/33_pwl_synth.md) audio synthesizers
* [PRISM](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/08_prism.md) and [Pulse TX](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/11_pulse_transmitter.md) programmable IO blocks
* 256x120 [graphics](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/09_vga_gfx.md) (640x480 VGA signal using the Tiny Tapeout [VGA Pmod](https://tinytapeout.com/specs/pinouts/#vga-output))
* General [VGA mode tester](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/28_vga_tester.md) for the VGA Pmod
* A few other competition winning peripherals:
    * [AffineX](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/39_affinex.md)
    * [CORDIC](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/12_cordic.md)
    * [Universal decoder](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/23_ubcd.md)
    * [DWARF accelerator](https://github.com/TinyTapeout/ttsky25a-tinyQV/blob/main/docs/user_peripherals/34_dwarf_line_table_accelerator.md)

The design is intended to run at 3v3 at 24MHz, although this timing is only met at the nominal corner.  It should also work at up to around 40MHz at 5v, but it may not be possible to interface with appropriate flash and RAM chips at that voltage.

## Pinout

The default pinout from the project template is used for all project sizes.

| Pin      | Function |
| -------  | -------- |
| CLK      | Clock (nominally 24MHz) |
| RST_N    | Reset (active low) |
| Input[0] | UART RX |
| Input[1] | Flash programming mode (active low, pulled up) |
| Bidir[7:0] | Equivalent of Tiny Tapeout in[7:0] |
| Bidir[8] | QSPI Flash CS |
| Bidir[9] | QSPI D0 / MOSI |
| Bidir[10] | QSPI D1 / MISO |
| Bidir[11] | QSPI SCK |
| Bidir[12] | QSPI D2 |
| Bidir[13] | QSPI D3 |
| Bidir[14] | QSPI RAM A CS |
| Bidir[15] | QSPI RAM B CS / Audio |
| Bidir[23:16] | Equivalent of Tiny Tapeout out[7:0] |
| Bidir[24] | Audio output |
| Bidir[25] | UART TX |
| Bidir[26] | UART RTS |
| Bidir[27] | Debug UART TX |
| Bidir[28] | Debug signal |
| Bidir[29] | Flash programming MISO |
| Bidir[30] | Flash programming CS |
| Bidir[31] | Flash programming MOSI |
| Bidir[32] | Flash programming SCK |

## Address map

| Address range | Device |
| ------------- | ------ |
| 0x0000000 - 0x0FFFFFF | Flash |
| 0x1000000 - 0x17FFFFF | RAM A |
| 0x1800000 - 0x1FFFFFF | RAM B |
| 0x8000000 - 0x8000033 | DEBUG  |
| 0x8000040 - 0x800007F | GPIO |
| 0x8000080 - 0x80000BF | UART  |
| 0x80000C0 - 0x80002FF | User peripherals 3-11 |
| 0x8000400 - 0x800047F | Simple user peripherals 0-7 |
| 0xFFFFC00 - 0xFFFFDFF | Scratch RAM |
| 0xFFFFF00 - 0xFFFFF07 | TIME |

### DEBUG

| Register | Address | Description |
| -------- | ------- | ----------- |
| ID       | 0x8000008 (R) | Instance of TinyQV: "WS01" |
| SEL      | 0x800000C (R/W) | Bit 6 enables peripheral output on out6, otherwise out6 is used for debug UART TX (defaults to peripheral output). |
| DEBUG_UART_DATA | 0x8000018 (W) | Transmits the byte on the debug UART |
| STATUS   | 0x800001C (R) | Bit 0 indicates whether the debug UART TX is busy, bytes should not be written to the data register while this bit is set. |

### TIME

| Register | Address | Description |
| -------- | ------- | ----------- |
| MTIME_DIVIDER | 0x800002C | MTIME counts at clock / (MTIME_DIVIDER + 1).  Bits 0 and 1 are fixed at 1, so multiples of 4MHz are supported. |
| MTIME    | 0xFFFFF00 (RW) | Get/set the 1MHz time count |
| MTIMECMP | 0xFFFFF04 (RW) | Get/set the time to trigger the timer interrupt |

This is a simple timer which follows the spirit of the Risc-V timer but using a 32-bit counter instead of 64 to save area.
In this version the MTIME register is updated at 1/64th of the clock frequency (nominally 1MHz), and MTIMECMP is used to trigger an interrupt.
If MTIME is after MTIMECMP (by less than 2^30 microseconds to deal with wrap), the timer interrupt is asserted.

### GPIO

| Register | Address | Description |
| -------- | ------- | ----------- |
| OUT | 0x8000040 (RW) | Control for out0-7 if the GPIO peripheral is selected |
| IN  | 0x8000044 (R) | Reads the current state of in0-7 |
| AUDIO_FUNC_SEL | 0x8000050 (RW) | Audio function select for audio pin |
| FUNC_SEL | 0x8000060 - 0x800007F (RW) | Function select for out0-7 |

| Function Select | Peripheral |
| --------------- | ---------- |
| 0               | Disabled   |
| 1               | GPIO       |
| 2               | UART       |
| 3 - 11          | User peripheral 3-11 |
| 16 - 23         | User byte peripheral 0-7 |

| Audio function select | Peripheral |
| --------------------- | ---------- |
| 0                     | PWL Synth out 7 |
| 1                     | Pulse Transmitter out 7 |
| 2                     | AY8913 out 0 |
| 3                     | Matt PWM out 7 |

If audio function select bit 2 is high audio is also presented on `uio[7]` (instead of RAM B CS).

### UART

| Register | Address | Description |
| -------- | ------- | ----------- |
| TX_DATA | 0x8000080 (W) | Transmits the byte on the UART |
| RX_DATA | 0x8000080 (R) | Reads any received byte |
| TX_BUSY | 0x8000084 (R) | Bit 0 indicates whether the UART TX is busy, bytes should not be written to the data register while this bit is set. Bit 1 indicates whether a received byte is available to be read. |
| DIVIDER | 0x8000088 (R/W) | 13 bit clock divider to set the UART baud rate |
| RX_SELECT | 0x800008C (R/W) | Selects UART RX pin |

| UART RX Select | Pin |
| -------------- | --- |
| 0 | `ui_in[7]` (default) |
| 1 | `ui_in[3]` |
| 2-3 | `uart_rx` (dedicated pin) |

# Project template readme

## Prerequisites

We use a custom fork of the [gf180mcuD PDK variant](https://github.com/wafer-space/gf180mcu) until all changes have been upstreamed.

To clone the latest PDK version, simply run `make clone-pdk`.

In the next step, install LibreLane by following the Nix-based installation instructions: https://librelane.readthedocs.io/en/latest/installation/nix_installation/index.html

## Implement the Design

This repository contains a Nix flake that provides a shell with the [`leo/gf180mcu`](https://github.com/librelane/librelane/tree/leo/gf180mcu) branch of LibreLane.

Simply run `nix-shell` in the root of this repository.

> [!NOTE]
> Since we are working on a branch of LibreLane, OpenROAD needs to be compiled locally. This will be done automatically by Nix, and the binary will be cached locally. 

With this shell enabled, run the implementation:

```
make librelane
```

## View the Design

After completion, you can view the design using the OpenROAD GUI:

```
make librelane-openroad
```

Or using KLayout:

```
make librelane-klayout
```

## Copying the Design to the Final Folder

To copy your latest run to the `final/` folder in the root directory of the repository, run the following command:

```
make copy-final
```

This will only work if the last run was completed without errors.

## Verification and Simulation

We use [cocotb](https://www.cocotb.org/), a Python-based testbench environment, for the verification of the chip.
The underlying simulator is Icarus Verilog (https://github.com/steveicarus/iverilog).

The testbench is located in `cocotb/chip_top_tb.py`. To run the RTL simulation, run the following command:

```
make sim
```

To run the GL (gate-level) simulation, run the following command:

```
make sim-gl
```

> [!NOTE]
> You need to have the latest implementation of your design in the `final/` folder. After implementing the design, execute 'make copy-final' to copy all necessary files.

In both cases, a waveform file will be generated under `cocotb/sim_build/chip_top.fst`.
You can view it using a waveform viewer, for example, [GTKWave](https://gtkwave.github.io/gtkwave/).

```
make sim-view
```

You can now update the testbench according to your design.

## Implementing Your Own Design

The source files for this template can be found in the `src/` directory. `chip_top.sv` defines the top-level ports and instantiates `chip_core`, chip ID (QR code) and the wafer.space logo. To allow for the default bonding setup, do not change the number of pads in order to keep the original bondpad positions. To be compatible with the default breakout PCB, do not change any of the power or ground pads. However, you can change the type of the signal pads, e.g. to bidirectional, input-only or e.g. analog pads. The template provides the `NUM_INPUT` and `NUM_BIDIR` parameters for this purpose.

The actual pad positions are defined in the LibreLane configuration file under `librelane/config.yaml`. The variables `PAD_SOUTH`/`PAD_EAST`/`PAD_NORTH`/`PAD_WEST` determine the respective pad placement. The LibreLane configuration also allows you to customize the flow (enable or disable steps), specify the source files, set various variables for the steps, and instantiate macros. For more information about the configuration, please refer to the LibreLane documentation: https://librelane.readthedocs.io/en/latest/

To implement your own design, simply edit `chip_core.sv`. The `chip_core` module receives the clock and reset, as well as the signals from the pads defined in `chip_top`. As an example, a 42-bit wide counter is implemented.

> [!NOTE]
> For more comprehensive SystemVerilog support, enable the `USE_SLANG` variable in the LibreLane configuration.

## Choosing a Different Slot Size

The template supports the following slot sizes: `1x1`, `0p5x1`, `1x0p5`, `0p5x0p5`.
By default, the design is implemented using the `1x1` slot definition.

To select a different slot size, simply set the `SLOT` environment variable.
This can be done when invoking a make target:

```
SLOT=0p5x0p5 make librelane
```

Alternatively, you can export the slot size:

```
export SLOT=0p5x0p5
```

You can change the slot that is selected by default in the Makefile by editing the value of `DEFAULT_SLOT`.

## Building a Standalone Padring for Analog Design

To build just the padring without any standard cell rows, digital routing or filler cells, run the following command:

```
make librelane-padring
```

It is also possible to build the padring for other slot sizes:

```
SLOT=0p5x0p5 make librelane-padring
```

## Precheck

To check whether your design is suitable for manufacturing, run the [gf180mcu-precheck](https://github.com/wafer-space/gf180mcu-precheck) with your layout.
