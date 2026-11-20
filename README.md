
# Alpha Denshi M68000 FPGA Implementation (Alpha68kMD)

FPGA compatible core of Alpha Denshi M68000 (ALPHA68K96V based) arcade hardware for [**MiSTerFPGA**](https://github.com/MiSTer-devel/Main_MiSTer/wiki) written by **Erin Olafson**.

**Alpha68kMD** is a modernised build of this core: current MiSTer framework, upstream copies of every CPU and sound module, all logic on the system clock with clock enables, save states, high score saving, per-controller Start/Coin, MAME DIP switch definitions and vertical games starting in vertical orientation. The emulation (CPU, interrupt, video and sound timing measured on the PCBs) is unchanged, except that the MCU interrupt, the MCU access wait and the YM2413 clock now follow the PCB measurements, and the 68000's VPA is decoded as on the PCB schematic (see [**SP85 / ALPHA-8511 / ALPHA-8411 Handling**](#sp85--alpha-8511--alpha-8411-handling)). RBF `Arcade-Alpha68kMD_YYYYMMDD.rbf`, MRAs `<Game> [MD].mra`.

FPGA implementation has been verified against schematics for Sky Adventure. PCB measurements taken from Gang Wars (ALPHA-68K96V) and Sky Soldiers (ALPHA-96KII).

Sky Adventure (bootleg) PCB purchased by **Erin Olafson** / [**atrac17**](https://github.com/atrac17). Gang Wars, Sky Soldiers, and The Next Space (authentic) PCBs purchased by [**atrac17**](https://github.com/atrac17).

The intent is for this core to be a 1:1 playable implementation of Alpha Denshi M68000 arcade hardware. Currently in **beta state**, this core is in active development with assistance from [**atrac17**](https://github.com/atrac17).

<br>
<p align="center">
<img width="" height="" src="https://user-images.githubusercontent.com/32810066/202100352-646d11d1-f6ac-4bfe-bcc6-0849ffb25cfe.png">
</p>

## Supported Games

| Title | PCB<br>Number | Status  | Released | ROM Set |
|-------|---------------|---------|----------|---------|
| [**Gang Wars**](https://en.wikipedia.org/wiki/Gang_Wars_(video_game))                | ALPHA-68K96V (GW)  | **Implemented**                | **Yes** | MAME 0.288 |
| [**Super Champion Baseball**](https://snk.fandom.com/wiki/Super_Champion_Baseball)   | ALPHA-68K96V (GW)  | **Implemented**                | **Yes** | MAME 0.288 (pitch speed from an estimated MCU timer, see SP85 handling) |
| [**Sky Adventure**](https://snk.fandom.com/wiki/Sky_Adventure)                       | ALPHA-68K96V (GW)  | **Implemented**                | **Yes** | MAME 0.288 |
| [**バトル フィールド**](https://en.wikipedia.org/wiki/Time_Soldiers)<br>Time Soldiers      | ALPHA-68K96II (SS) | **Implemented**                | **Yes** | MAME 0.288 |
| [**Sky Soldiers**](https://en.wikipedia.org/wiki/Sky_Soldiers)                       | ALPHA-68K96II (SS) | **Implemented**                | **Yes** | MAME 0.288 |
| [**Gold Medalist**](https://snk.fandom.com/wiki/Gold_Medalist)                       | ALPHA-68K96II (SS) | **Implemented**                | **Yes** | MAME 0.288 (**goldmedl** only; checked against MAME, no PCB) |
| [**Paddle Mania**](https://snk.fandom.com/wiki/Paddle_Mania)                         | ALPHA-68K96I       | W.I.P                          | No      | N/A |
| [**The Next Space**](https://snk.fandom.com/wiki/The_Next_Space)                     | A8004-1            | **Separate<br>Repository**     | No      | N/A |
| [**Super Stingray**](https://segaretro.org/Super_Stingray)                           | N/A                | W.I.P                          | No      | N/A |
| [**Kyros no Yakata**](http://www.hardcoregaming101.net/kyros-desolator/)             | N/A                | W.I.P                          | No      | N/A |
| [**Mahjong Block Jongbou**](https://snk.fandom.com/wiki/Jongbou)                     | ALPHA-68K96N       | W.I.P                          | No      | N/A |

## External Modules

Copied unmodified from the listed repository and commit (sources and commits are also listed in `files.qip`).

|Name| Purpose | Author | Source (commit) | License |
|----|---------|--------|-----------------|---------|
| [**fx68k**](https://github.com/ijor/fx68k)                      | [**Motorola 68000 CPU**](https://en.wikipedia.org/wiki/Motorola_68000)   | Jorge Cwik     | ijor/fx68k (`0602ee4`) | GPL-3.0 |
| [**t80**](https://opencores.org/projects/t80)                   | [**Zilog Z80 CPU**](https://en.wikipedia.org/wiki/Zilog_Z80)             | Daniel Wallner, MiSTer-devel | MiSTer-devel/NeoGeo_MiSTer `rtl/cpu/T80` (`90a8350`) | T80 license (BSD-style) |
| [**jt2413**](https://github.com/jotego/jtopl)                   | [**Yamaha OPL-L**](https://en.wikipedia.org/wiki/Yamaha_YM2413)          | Jose Tejada    | jotego/jtopl (`f96ff3e`) | GPL-3.0 |
| [**jt03**](https://github.com/jotego/jt12)                      | [**Yamaha OPN**](https://en.wikipedia.org/wiki/Yamaha_YM2203)            | Jose Tejada    | jotego/jt12 (`eaab7e1`) with jotego/jt49 (`7f6abfd`) | GPL-3.0 |
| [**MiSTer framework**](https://github.com/MiSTer-devel/Template_MiSTer) | `sys/` (video, audio, HPS I/O, scaler, screen rotation) | MiSTer-devel (Sorgelig et al.) | MiSTer-devel/Template_MiSTer (`d6324f2`) | GPL-2.0+ |
| [**yc_out**](https://github.com/MikeS11/MiSTerFPGA_YC_Encoder)  | [**Y/C Video Module**](https://en.wikipedia.org/wiki/S-Video)            | Mike Simone    | part of the framework `sys/` | GPL-2.0+ |
| [**Save states**](https://github.com/MiSTer-devel/Arcade-TaitoF2_MiSTer) | DDR save-state streamer, memory stream, DDR interface, slot UI (`rtl/savestate/`) | Martin Donlon | MiSTer-devel/Arcade-TaitoF2_MiSTer (`9438df9`) | GPL-2.0 |
| [**Pause**](https://github.com/JimmyStones/Pause_MiSTer)        | OSD pause and dimming (`rtl/pause.v`, as modified by va7deo) | Jim Gregory | JimmyStones/Pause_MiSTer | GPL-3.0 |
| SDRAM / ROM segments                                            | `rtl/mem/` SDRAM controller, segment, download buffer, dual-port RAM | Josh Bassett (nullobject) | as shipped by va7deo | MIT |

The save-state controller (`rtl/alpha68k_ss.sv`) and the high score module (`rtl/hiscore.sv`) are written for this core, after the save-state flow of Arcade-TaitoF2_MiSTer and the high score flow of MiSTer-devel's Arcade-RaizingMD_MiSTer / Arcade-IGSPGM_MiSTer. High score tables come from MAME's `hiscore.dat` (MAME 0.288 hiscore plugin).

# Known Issues / Tasks

- Dump M68705 (SP85N / ALPHA-8511 ) MCU from Sky Adventure (Bootleg) [Task]  
- Dump ROMs from Sky Adventure Bootleg and submit to mamedev [Task]  
- Dump ROMs from Gold Medalist and submit to mamedev [Task]  
- ~~Add P3/P4 inputs for Gold Medalist~~ [Task]  
- ~~Add rotary input for Time Soldiers~~ [Task]  
- ~~GFX decode and palette display for ALPHA-68K96II~~ [Task]  
- ~~Verify clocks on ALPHA-68K96II hardware; MAME is incorrect~~ [Task]  <br><br>
- ~~Options removed currently until stability is checked, may be tied to RESET line~~ [Issue]  
- ~~Super Champion Baseball (sbasebal) freezes due to MCU ROM code (no dump)~~ Alpha68kMD simulates the MCU's pitch timer (rate estimated, no dump) [Issue]  
- ~~Super Champion Baseball occasionally boots into its HARD DEBUGGER screen ("PALETTE RAM 0 BAD") and Gang Wars into its HARD CHECK screen (PALETTE BAD)~~ Fixed in Alpha68kMD: the 68000's VPA was decoded for the palette RAM, unlike the PCB [Issue]  
- ~~Awaiting Gold Medalist PCB to verify and release~~ Alpha68kMD releases goldmedl checked against MAME 0.288 only, with no PCB measurements; still awaiting a PCB to verify; submit new ROM dump for bad ROMs [Issue]  
- Gold Medalist set 2 and bootleg (goldmedla, goldmedlb) are not included: they run on the ALPHA-68K96III board (10 MHz 68000, program ROM at $40000, different tile ROM), which the core does not implement [Issue]  
- Super Champion Baseball's pitch timer rate (527.3 Hz) is an estimate, fitted so the slowest pitch reaches the game's 79 km/h floor and the fastest reads 141 km/h (rosters: 138-142 km/h); pitch speeds may differ from the PCB until the MCU is dumped or the timer is measured [Issue]  
- On the PCB, Gang Wars' MCU answers $21 to every no-coin query and the game then reads DIP switch 1 through the MCU (a second ~100 us access); the core answers $00 and supplies the DIP byte itself, as MAME does: same DIP value, ~200 fewer CPU cycles per interrupt (timing only) [Issue]  
- The ALPHA-68K96V schematic gives the interrupt acknowledge VPA but no DTACK; the core also asserts DTACK, which can leave the 68000's VMA armed and end a later bus cycle early (seen in simulation only at the earlier releases' ~549 Hz interrupt rate, not at the measured rates) [Issue]  
- On the ALPHA-68K96V schematic the IPL0 / IPL1 latches are cleared by the game's reads of $D8000 / $E0000, not by the interrupt acknowledge; the core clears both on any acknowledge (timing only) [Issue]  
- The ALPHA-68K96V 68000 runs at 10.588 MHz on average in the core (fractional divider, 5/17 of 72 MHz, halved) instead of the 20 MHz crystal / 2 = 10 MHz; SDRAM ROM wait states (~4 % in simulation) bring it to ~10.16 MHz of useful clocks. No V-board clock capture yet [Issue]  

# PCB Check List

<br>

FPGA implementation has been verified against [**schematics**](https://github.com/va7deo/alpha68k/blob/main/doc/ALPHA-68K96V/ALPHA68K-96V_Schematics.pdf) for Sky Adventure. The schematics are improperly labeled Prehistoric Isle (hand written), this was discovered during development of the [**Prehistoric Isle FPGA implementation**](https://github.com/va7deo/PrehistoricIsle). PCB measurements taken from Gang Wars (ALPHA-68K96V) and Sky Adventure (ALPHA-68K96II).

### Clock Information

H-Sync      | V-Sync      | Source   | PCB<br>Number  |
------------|-------------|----------|----------------|
15.625kHz   | 59.185606Hz | [**DSLogic+**](FILLME) | ALPHA-68K96V (GW)  |
15.625kHz   | 59.185606Hz | [**DSLogic+**](FILLME) | ALPHA-68K96II (SS) |

### Crystal Oscillators

- MAME documentation for the Alpha96k.cpp states that ALPHA-68K96II hardware runs the M68000 at 8.00 MHZ. The actual frequency for the M68000 is 9.00 MHZ based on board readings from Sky Soldier.

Location                | PCB<br>Number      | Freq (MHz) | Use                                                                                          |
------------------------|--------------------|------------|----------------------------------------------------------------------------------------------|
X-1  (24 MHZ)           | ALPHA-68K96V (GW)  | 24.000     | Z80 CLK (6MHZ)<br><br>YM2203 (CLK 3 MHZ)<br><br>Sprite CLK (12 MHZ)<br><br>Pixel CLK (6 MHZ) |
X-2  (20 MHZ)           | ALPHA-68K96V (GW)  | 20.000     | M68000 CLK (10 MHZ)                                                                          |
X-3  (3.579545 MHz)     | ALPHA-68K96V (GW)  | 3.579545   | YM2413 CLK (3.579545 MHz)                                                                    |
X-1  (3.579545 MHz)     | ALPHA-68K96II (SS) | 24.000     | YM2413 CLK (3.579545 MHz)                                                                    |
X-2  (18 MHZ)           | ALPHA-68K96II (SS) | 18.000     | M68000 CLK (9 MHZ)                                                                           |
X-3  (24 MHZ)           | ALPHA-68K96II (SS) | 3.579545   | Z80 CLK (6MHZ)<br><br>YM2203 (CLK 3 MHZ)<br><br>Sprite CLK (12 MHZ)<br><br>Pixel CLK (6 MHZ) |

**Pixel clock:** 6.00 MHz

**Estimated geometry:**

    383 pixels/line
  
    263 pixels/line

### Main Components

Location | PCB<br>Number | Chip | Use |
---------|---------------|------|-----|
68000D   | ALPHA-68K96V (GW)  | [**Motorola 68000 CPU**](https://en.wikipedia.org/wiki/Motorola_68000)   | Main CPU      |
Z80B     | ALPHA-68K96V (GW)  | [**Zilog Z80 CPU**](https://en.wikipedia.org/wiki/Zilog_Z80)             | Sound CPU     |
YM2203   | ALPHA-68K96V (GW)  | [**Yamaha YM2203**](https://en.wikipedia.org/wiki/Yamaha_YM2203)         | OPN           |
YM2413   | ALPHA-68K96V (GW)  | [**Yamaha YM2413**](https://en.wikipedia.org/wiki/Yamaha_YM2413)         | OPL-L         |

Location | PCB<br>Number | Chip | Use |
---------|---------------|------|-----|
68000-10 | ALPHA-68K96II (SS) | [**Motorola 68000 CPU**](https://en.wikipedia.org/wiki/Motorola_68000)   | Main CPU      |
Z80B     | ALPHA-68K96II (SS) | [**Zilog Z80 CPU**](https://en.wikipedia.org/wiki/Zilog_Z80)             | Sound CPU     |
YM2203   | ALPHA-68K96II (SS) | [**Yamaha YM2203**](https://en.wikipedia.org/wiki/Yamaha_YM2203)         | OPN           |
YM2413   | ALPHA-68K96II (SS) | [**Yamaha YM2413**](https://en.wikipedia.org/wiki/Yamaha_YM2413)         | OPL-L         |

### Custom Components

Location | PCB<br>Number | Chip | Use |
---------|---------------|------|-----|
SP85<br><br>ALPHA-8511<br><br>ALPHA-8411 | ALPHA-68K96V (GW)<br><br>ALPHA-68K96II (SS)<br><br>ALPHA-68K96V (SA) | [**SP85N**](https://github.com/va7deo/alpha68k/blob/main/doc/ALPHA-68K96V/ALPHA68K-96V_Schematics.pdf)          | Coin Handling<br><br>Dipswitch Handling<br><br>Screen Inversion Handling |
SNKCLK                           | ALPHA-68K96V (GW)                                                            | [**SNK CLK**](https://github.com/va7deo/alpha68k/blob/main/doc/ALPHA-68K96V/ALPHA68K-96V_Schematics.pdf)        | Counter                                                                  |
INPUT 84                         | ALPHA-68K96II                                                                | [**ALPHA-INPUT 84**](https://github.com/va7deo/alpha68k/blob/main/doc/ALPHA-68K96V/ALPHA68K-96V_Schematics.pdf) | Rotary Handling                                                          |
INPUT 87                         | ALPHA-68K96V (GW)                                                            | [**ALPHA-INPUT 87**](https://github.com/va7deo/alpha68k/blob/main/doc/ALPHA-68K96V/ALPHA68K-96V_Schematics.pdf) | Input Handling                                                           |
ALPHA-8921                       | ALPHA-68K96V (GW)                                                            | [**ALPHA-8921**](https://github.com/va7deo/alpha68k/blob/main/doc/ALPHA-68K96V/ALPHA68K-96V_Schematics.pdf)     | GFX Muxing                                                               |

### SP85 / ALPHA-8511 / ALPHA-8411 Handling

The SP85N or ALPHA-8511/8411 utilized on Alpha Denshi M68000 hardware for I/O handling appears to be closely related to the Motorola M68705p5. Early Alpha Denshi M68000 hardware utilized the M68705 before SNK / Alpha Denshi moved to a custom component. It's possible this is a rebadged custom.<br><br>
There is a known dump for the ALPHA-8511 (possibly a M68705 from a bootleg) used on Super Stingray and a dump of the M68705 used on the Kyros no Yakata bootleg. The program code from the Kyros no Yakata bootleg may match the original ALPHA-8511 program code according to mame documentation.<br><br>
The Sky Adventure bootleg purchased also uses a M68705p5 which is dumpable and will be submitted to mame along with the ROMs. Disassembly of the program code will be done for analysis based on current MCU implementation.<br><br>
[**Readings have been pulled from the Gang Wars SP85N**](https://github.com/va7deo/alpha68k/blob/main/doc/ALPHA-68K96V/Gang%20Wars/SP85N_Readings/SP85N_Gang_Wars_Readings.png) revealed that the MCU pushes 15 interrupts per second, mame's driver for Alpha68k has this coded as 100 or 120 interrupts per second.<br><br>
Alpha68kMD generates the MCU interrupt at the rates in the PCB logic captures, as a fraction of the frame: 15.46 Hz (3.828 frames) on ALPHA-68K96V (Gang Wars SP85N capture) and 9.89 Hz (5.986 frames) on ALPHA-68K96II (Sky Soldiers ALPHA-8511 capture). Sky Adventure, Super Champion Baseball, Time Soldiers / Battle Field and Gold Medalist use their board's rate (no capture of their own). Earlier releases ran it at about 549 Hz (the counter was too narrow to reach the measured period). The MCU simulation keeps a coin press until the game's next coin query, so short coin taps are not missed. The YM2413 clock is 3.579545 MHz (X-3 crystal; earlier releases 3.600 MHz).<br><br>
On the PCB the MCU holds the 68000's DTACK while it services each access (the SP85's own DTACK pin; 92-120 us CUS windows in the captures). Alpha68kMD holds it for 94.7 us on ALPHA-68K96V (Gang Wars coin query) and 99.5 us on ALPHA-68K96II (mean of the Sky Soldiers windows). Without an MCU dump this is a fixed approximation; the real time per access depends on the MCU program.<br><br>
The PCB asserts VPA only for $500000-$7FFFFF and the interrupt acknowledge (74LS138 Y5-Y7, CPU schematic). Earlier releases also asserted it for the palette RAM at $400000, which could cut short the next opcode fetch: the cause of the occasional Gang Wars HARD CHECK / Super Champion Baseball HARD DEBUGGER boots and possibly of rare in-game glitches.<br><br>
Super Champion Baseball times each pitch with a counter the MCU keeps in shared RAM ($4023E) and divides by the flight time to show the pitch speed; without it the game divided by zero and froze (MAME patches the US program instead). Alpha68kMD runs that counter at 527.3 Hz, an estimate: the game's slowest pitch (44 frames) then reaches its own 79 km/h floor and the fastest (30 frames) reads 141 km/h, the rosters listing 138-142 km/h top speeds.<br><br>
On ALPHA-68K96II the game sets the flip screen through the MCU (write to MCU offset $2D), as MAME emulates; Alpha68kMD now uses that instead of the DIP bit, which had Sky Soldiers flipped at Flip Screen Off (it turned counter-clockwise to compensate). All vertical games now turn clockwise.

# Core Features

### Save States

- Four save-state slots in DDR memory. On controller 1, hold **L** and press **Down** to save, **Up** to restore, **Left / Right** to change the slot. The OSD also has Save / Restore entries (keyboard Alt-F1 / F1), the slot and an auto-increment option.
- Saved: 68000 registers, work, sprite, text and palette RAM, Z80 registers and RAM, banking and latches, MCU coin state and interrupt timer, rotary positions and the YM2203 / YM2413 registers. Video counters and line buffers rebuild within a frame. Without a save or restore running the core behaves exactly as before.

### High Score Saving

- High score tables (MAME `hiscore.dat` entries) are restored when the game has initialised its table and saved to `<game>.nvm` when the OSD is opened (Autosave Hiscores On) or with "Save Hiscores". Super Champion Baseball has no table and shows no option.

### Controls

- Each controller drives its own player: controller 1 = P1 joystick, buttons, Start and Coin; controller 2 = P2 joystick, buttons, Start and Coin. There is no P2 Start or P2 Coin on controller 1.
- Default gamepad mapping in every MRA: Button 1 → A, Button 2 → B, Button 3 → X, Start → Start, Coin → Select, Pause → R, Save states → L (hold). Time Soldiers / Battle Field: Rotate CW → X, Rotate CCW → Y.
- The OSD's Define Buttons order is the game's buttons first (Button 1-3, then Rotate CW / CCW), then Start, Coin, Pause and Save States.
- MiSTer stores a defined button map per game (`config/inputs/<setname>_input_*.map`), shared with the original Alpha68k core. A map saved with the original core or an earlier Alpha68kMD release has a different button order; delete it or define the buttons again.
- Button names come from the game documentation in `doc/` (Gang Wars and Sky Adventure manuals, Battle Field flyer) or the original MRAs. No game uses button combinations (none are listed in the manuals).

| Game | Button 1 | Button 2 | Button 3 |
|------|----------|----------|----------|
| Gang Wars | Kick | Punch | Jump |
| Sky Adventure | Fire | Weapon | Plane |
| Super Champion Baseball | Swing/Pitch/Field | Steal/Pick Off/Run | Time-Out |
| Sky Soldiers | Cannon System | Missile System | — |
| Time Soldiers / Battle Field | Shot | Weapon | — (Rotate CW / CCW) |
| Gold Medalist | Run/Spin/Power | Run/Spin/Hit Power | Jump/Jab/Throw Angle |

- Gold Medalist is a 4-player, buttons-only game: controllers 1-4 drive players 1-4, and each controller's Start joins that player (the game's start buttons #1-#4). Player 3's Start is read from a spare bit of the DIP switch port, where the game expects it (MAME does not map it). The board has two coin inputs, so Coin works on controllers 1 and 2 only.

### DIP Switches

- DIP switch names, options and defaults follow MAME 0.288, except Gang Wars' Timer Speed, which defaults to Normal. Gold Medalist's Cabinet setting uses two separate switches, so it is shown as Cabinet (Upright / Cocktail) and Upright Players (2 / 4); its 100M Dash Speed options are shortened to fit the OSD. A changed DIP switch takes effect at "Reset to apply" (or any reset); changing it no longer resets the core.

### Orientation

- Vertical games (Sky Adventure, Sky Soldiers, Time Soldiers, Battle Field) start in vertical orientation; the Orientation option is shown for them only. Flip Screen DIP switches are drawn by the core's raster and work on analog and HDMI.

### Rotary Joystick Support

- Rotary control is supported via gamepad or firmware written by [**atrac17**](https://github.com/atrac17) / [**DJ Hard Rich**](https://twitter.com/djhardrich) for [**LS-30 functionality using an RP2040**](FILLME). Latency verification done by [**misteraddons**](https://github.com/misteraddons), for more information click [**here**](https://rpubs.com/misteraddons/inputlatency).

<br>

Model | Device | Connection | USB Polling<br>Interval | Sample<br>Number | Frame<br>Probability | Average<br>Latency | Joystick ID |
------|--------|------------|-------------------------|------------------|----------------------|--------------------|-------------|
LS-30 Rotary Encoder | RP2040 | Wired USB | 1ms | 2241 | 95.52% | 0.747 ms | 2e8a:000a |

<br>

### Native Y/C Output

- Native Y/C ouput is possible with the [**analog I/O rev 6.1 pcb**](https://github.com/MiSTer-devel/Main_MiSTer/wiki/IO-Board). Using the following cables, [**HD-15 to BNC cable**](https://www.amazon.com/StarTech-com-Coax-RGBHV-Monitor-Cable/dp/B0033AF5Y0/) will transmit Y/C over the green and red lines. Choose an appropriate adapter to feed [**Y/C (S-Video)**](https://www.amazon.com/MEIRIYFA-Splitter-Extension-Monitors-Transmission/dp/B09N19XZJQ) to your display.

### H/V Adjustments

- There are two H/V toggles, H/V-sync positioning adjust and H/V-sync width adjust. Positioning will move the display for centering on CRT display. The sync width adjust can be used to for sync issues (rolling) without modifying the video timings.
- Alpha68kMD: the adjustments are signed (-8 to +7) and every setting keeps one sync pulse per line and per frame (earlier releases lost vertical sync at most settings other than 0 and +1, and negative values moved the wrong way).

### Scandoubler Options

- Additional toggle to enable the scandoubler without changing ini settings and new scanline option for 100% is available, this draws a black line every other frame. Below is an example.

<table><tr><th>Scandoubler Fx</th><th>Scanlines 25%</th><th>Scanlines 50%</th><th>Scanlines 75%</th><th>Scanlines 100%</th><tr><td><br> <p align="center"><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/202102926-b860c972-4622-44c5-9df4-f4ce418042ab.png"></td><td><br> <p align="center"><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/202103109-fa5229d7-5085-45c8-9833-494135c7fef3.png"></td><td><br> <p align="center"><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/202103205-b984b54a-1f82-41da-9616-6f1a923383b9.png"></td><td><br> <p align="center"><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/202103300-74daf79e-19bf-4c95-8ab7-b5bcfd51e426.png"></td><td><br> <p align="center"><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/202103345-1a85d766-8599-42b2-abe6-deab3df2aeaa.png"></td></tr></table>

### Gang Wars Options

- There is a toggle to swap inputs from Player 1 to Player 2 in Debug Settings. This will enable you to play as Jackie in Gang Wars instead of Mike while only having one controller connected. Additionally, you can play as the additional time soldier in バトル フィールド / Time Soldiers. This only swaps inputs for the joystick and rotary control, it does not effect keyboard inputs.

- There is a toggle to disable the laughter from enemies in Gang Wars located in Debug Settings. Enabling this will mute the laughter when an enemy knocks Mike or Jackie down.

# Controls

<br>

- Service menu is accessed by holding the F2 key on boot. The core may need to be reset by pressing F3 while holding F2 to access the service menu.

<br>

<table><tr><th>Game</th><th>Joystick</th><th>Service Menu</th><th>Control Type</th></tr><tr><td><p align="center">Gang Wars</p></td><td><p align="center">8-Way</p></td><td><p align="center"><br><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/202104150-876e36e4-ab13-45c1-8162-c83050c11842.png"></td><td><p align="center">Co-Op</td><tr><td><p align="center">Super Champion<br>Baseball</p></td><td><p align="center">8-Way</p></td><td><p align="center"><br><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/202104322-b92306bf-954d-4f6b-8c69-86fb53e7a1c6.png"></td><td><p align="center">Co-Op</td><tr><td><p align="center">Sky Adventure</p></td><td><p align="center">8-Way</p></td><td><p align="center"><br><img width="112" height="128" src="https://user-images.githubusercontent.com/32810066/202104449-97caea3f-b085-4d20-b7af-4285dd8b8a04.png"></td><td><p align="center">Co-Op</td> <tr><td><p align="center">Time Soldiers</p></td><td><p align="center">Rotary</p></td><td><p align="center"><br><img width="112" height="128" src="https://user-images.githubusercontent.com/32810066/209315299-1ebe1cab-1151-4d92-b7b2-e8f3b9933b8c.png"></td><td><p align="center">Co-Op</td> <tr><td><p align="center">Sky Soldiers</p></td><td><p align="center">8-Way</p></td><td><p align="center"><br><img width="112" height="128" src="https://user-images.githubusercontent.com/32810066/209315288-2be9c8a8-6929-4735-9176-eccee5d00c3a.png"></td><td><p align="center">Co-Op</td> <tr><td><p align="center">Gold Medalist</p></td><td><p align="center">N/A</p></td><td><p align="center"><br><img width="128" height="112" src="https://user-images.githubusercontent.com/32810066/209315311-ddb314a1-e253-4e79-aecd-af919156f88d.png"></td><td><p align="center">V.S.</td></table>

<br>
<br>

### Rotary Joystick Support

- Rotary control is supported via gamepad or firmware written by [**atrac17**](https://github.com/atrac17) / [**DJ Hard Rich**](https://twitter.com/djhardrich) for LS-30 functionality using an RP2040. There are toggles in the OSD under Debug Settings to select the rotary controller type per player. <br><br> When using a gamepad, enabling autofire and setting to 160ms for Rotate CW/CCW in the MiSTer framework allows for smooth rotation; adjust the rate to fit your preference. LS-30 firmware requires no mapping and is plug and play; it is player dependent and connected over USB to the DE10-Nano.

<br>

### Keyboard Handler

- Keyboard inputs mapped to mame defaults for the following functions. Player 3 and Player 4 input keys are not mapped, only Player 3 / Player 4 start buttons.

<br>

|Services|Coin/Start|
|--|--|
|<table> <tr><th>Functions</th><th>Keymap</th></tr><tr><td>Test</td><td>F2</td></tr><tr><td>Reset</td><td>F3</td></tr><tr><td>Service</td><td>9</td></tr><tr><td>Pause</td><td>P</td></tr> </table> | <table><tr><th>Functions</th><th>Keymap</th><tr><tr><td>P1 Start</td><td>1</td></tr><tr><td>P2 Start</td><td>2</td></tr><tr><td>P1 Coin</td><td>5</td></tr><tr><td>P2 Coin</td><td>6</td></tr> </table>|

|Player 1|Player 2|
|--|--|
|<table> <tr><th>Functions</th><th>Keymap</th></tr><tr><td>P1 Up</td><td>Up</td></tr><tr><td>P1 Down</td><td>Down</td></tr><tr><td>P1 Left</td><td>Left</td></tr><tr><td>P1 Right</td><td>Right</td></tr><tr><td>P1 Bttn 1</td><td>L-Ctrl</td></tr><tr><td>P1 Bttn 2</td><td>L-Alt</td></tr><tr><td>P1 Bttn 3</td><td>Space</td></tr> </table> | <table> <tr><th>Functions</th><th>Keymap</th></tr><tr><td>P2 Up</td><td>R</td></tr><tr><td>P2 Down</td><td>F</td></tr><tr><td>P2 Left</td><td>D</td></tr><tr><td>P2 Right</td><td>G</td></tr><tr><td>P2 Bttn 1</td><td>A</td></tr><tr><td>P2 Bttn 2</td><td>S</td></tr><tr><td>P2 Bttn 3</td><td>Q</td></tr> </table>|

|Player 3|Player 4|
|--|--|
|<table> <tr><th>Functions</th><th>Keymap</th></tr><tr><td>P3 Bttn 1</td><td>**N/A**</td></tr><tr><td>P3 Bttn 2</td><td>**N/A**</td></tr><tr><td>P3 Bttn 3</td><td>**N/A**</td></tr><tr><td>P3 Start</td><td>3</td></tr> </table> | <table> <tr><th>Functions</th><th>Keymap</th></tr><tr><td>P4 Bttn 1</td><td>**N/A**</td></tr><tr><td>P4 Bttn 2</td><td>**N/A**</td></tr><tr><td>P4 Bttn 3</td><td>**N/A**</td></tr><tr><td>P4 Start</td><td>4</td></tr> </table>|

<br>

- Custom keyboard inputs mapped for LS-30 RP2040 firmware functionality. The mapping is player dependent for the RP2040 firmware.

<br>

|LS-30 Player 1|LS-30 Player 2|
|--|--|
|<table> <tr><th>Functions</th><th>Keymap</th></tr><tr><td>P1 Rotary 1</td><td>Y</td></tr><tr><td>P1 Rotary 2</td><td>U</td></tr><tr><td>P1 Rotary 3</td><td>I</td></tr><tr><td>P1 Rotary 4</td><td>O</td></tr><tr><td>P1 Rotary 5</td><td>H</td></tr><tr><td>P1 Rotary 6</td><td>J</td></tr><tr><td>P1 Rotary 7</td><td>K</td></tr><tr><td>P1 Rotary 8</td><td>L</td></tr><tr><td>P1 Rotary 9</td><td>N</td></tr><tr><td>P1 Rotary 10</td><td>M</td></tr><tr><td>P1 Rotary 11</td><td>,</td></tr><tr><td>P1 Rotary 12</td><td>.</td></tr> </table> | <table> <tr><th>Functions</th><th>Keymap</th></tr><tr><td>P2 Rotary 1</td><td>Z</td></tr><tr><td>P2 Rotary 2</td><td>X</td></tr><tr><td>P2 Rotary 3</td><td>C</td></tr><tr><td>P2 Rotary 4</td><td>V</td></tr><tr><td>P2 Rotary 5</td><td>B</td></tr><tr><td>P2 Rotary 6</td><td>W</td></tr><tr><td>P2 Rotary 7</td><td>E</td></tr><tr><td>P2 Rotary 8</td><td>T</td></tr><tr><td>P2 Rotary 9</td><td>3</td></tr><tr><td>P2 Rotary 10</td><td>4</td></tr><tr><td>P2 Rotary 11</td><td>7</td></tr><tr><td>P2 Rotary 12</td><td>8</td></tr> </table>|

