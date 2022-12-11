# Serpent-VHDL

## Module description
The module consists of two files: `serpent.vhd` and `serpent_pkg.hd`. The `serpent.vhd` holds the entity `serpent` with the following interfacing:

|Name         |I/O      |Type               |Description                                                    |
|---          |---      |---                |---                                                            |
|`clk`        |`INPUT`  |`std_logic`        |Generic clock                                                  |
|`rst`        |`INPUT`  |`std_logic`        |Generic reset (active `HIGH`)                                  |
|`start`      |`INPUT`  |`std_logic`        |Start encryption (`plaintext` and `userkey` should be valid)   |
|`busy`       |`OUTPUT` |`std_logic`        |Encryption is busy and won't accept new input                  |
|`valid`      |`OUTPUT` |`std_logic`        |Encrypted `ciphertext` is valid for 1 clockcycle               |
|`plaintext`  |`INPUT`  |`std_logic_vector` |Encryption input                                               |
|`userkey`    |`INPUT`  |`std_logic_vector` |Encryption key                                                 |
|`ciphertext` |`OUTPUT` |`std_logic_vector` |Encryption output                                              |

Dependent on the platform, the clock can be configured. The design is kept in mind to maximise the clock frequency by splitting the states up. Currently, no analysis has been done on this.

An entity can provide plaintext and userkeys for encryption. With a start signal, the entity signals when it is has accepted the input and is busy with encrypting. A valid signal shows when the output of the encryption is ready. **NOTE: THIS OUTPUT IS VALID FOR ONE CLOCK CYCLE WITHOUT HANDSHAKE**. All states and outputs are reset after encryption. It is possible to keep the output valid by removing line 126 of `serpent.vhd`.

## Environment dependencies
This module was developed with [cocotb](https://www.cocotb.org/) and [GHDL](http://ghdl.free.fr/). cocotb is run with a Makefile. GTKWave can be used for visually check the simulation waveforms. The following tools are required for running the test environment:

```
sudo apt install python3 ghdl gtkwave
pip install cocotb pytest
```

## Commands
The Makefile allows for the following commands:
```
make
```
`make` will run cocotb and simulate the test python file. This should result in a `PASS` initially.
```
make compile
```
`make compile` will only compile the VHDL sources. This is handy when just testing the syntax.
```
make show
```
`make show` will show the simulation waveforms in GTKWave.
```
make clean-all
```
`make clean-all` will cleanup all de automatically generated files.


## License
License can be found at [here](LICENSE.md).