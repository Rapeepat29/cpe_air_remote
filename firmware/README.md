# ESP32 firmware

This folder contains two separate ESP32 firmwares. The A/C board controls one
air conditioner. The occupancy board monitors one room with an HLK-LD2410.
Both use BLE for first setup/reconfiguration and Wi-Fi/MQTT afterward.

There are two A/C boards. They share the same BLE, MQTT, PZEM, LED, OTA and
offline-history behaviour, so the app and Backend treat them alike:

| Sketch | Talks to the A/C by | Brand in the app |
|---|---|---|
| `rmutt_esp32_air` (2.5.0) | IR, like a handheld remote | Chosen by the user (IRac protocol) |
| `rmutt_esp32_air_wired` (2.5.1-slm8) | The Daikin wall-panel cable (SLM8), replacing the wall remote | Fixed by the board: **Daikin · Wired** (`DAIKIN_WIRED`) |

Both boards now drive a 1.3" SH1106 I2C OLED (SDA GPIO21, SCL GPIO22) and need
the **U8g2** library. The wired board also needs **DHT sensor library**
(Adafruit) for its DHT11 room sensor and does not use IRremoteESP8266. See
`rmutt_esp32_air/README_OLED_TH.md` and
`rmutt_esp32_air_wired/README_WIRED_TH.md` for wiring and build notes. Keep the
`build_opt.h` files: without them the IR sketch no longer fits in flash.

## Arduino libraries

- ArduinoJson 6.x
- PubSubClient
- IRremoteESP8266 2.9.0
- PZEM004Tv30 (Jakub Mandula)
- ld2410 by Nick Reynolds 0.2.2 or later (occupancy board only)
- ESP32 board package (Wi-Fi, BLE, Preferences are included)

The app offers IRac protocols for Daikin, Mitsubishi, Panasonic, Gree, Midea,
LG, Samsung, Toshiba, Hitachi, Fujitsu, Kelvinator, Sharp, Electra, and Haier.
It also includes the custom `SAIJO_DENKI` driver captured from the user's
remote. The driver files are beside the `.ino`, so no separate Saijo library
installation is required. Select the protocol that matches the physical
remote. The common interface silently omits features that a selected protocol
cannot represent.

The captured Saijo Denki data currently supports Power, Cool/Dry/Fan,
18–29 °C, Fan Auto/levels 1–3/Turbo, and Swing Auto/positions 1–5. The additional
capture labels the fan frames from strongest down to Auto and the swing frames
from bottom to top followed by continuous swing. Other unrelated extra
functions remain disabled until complete valid captures exist.

## Pins

| GPIO | `rmutt_esp32_air` (IR) | `rmutt_esp32_air_wired` (Daikin cable) |
|---|---|---|
| `GPIO17` | IR LED driver input | — (not used) |
| `GPIO21` | OLED SDA (1.3" SH1106 I2C) | OLED SDA (1.3" SH1106 I2C) |
| `GPIO22` | OLED SCL / SCK | OLED SCL / SCK |
| `GPIO16` | PZEM UART RX (connect to PZEM TX) | PZEM UART RX (connect to PZEM TX) |
| `GPIO18` | PZEM UART TX (connect to PZEM RX) | PZEM UART TX (connect to PZEM RX) |
| `GPIO25` | green status LED | green status LED |
| `GPIO26` | red status LED | red status LED |
| `GPIO27` | yellow Wi-Fi LED | yellow Wi-Fi LED |
| `GPIO0` | BOOT/setup button | BOOT/setup button |
| `GPIO33` | — | A/C bus TX through a 1N4148 (stripe → GPIO33, other leg → command wire) |
| `GPIO35` | — | A/C bus RX, status wire through a 100k/200k divider |
| `GPIO34` | — | Bus echo, command wire through a 100k/200k divider (optional) |
| `GPIO4` | — | DHT11 DATA (KY-015) |

OLED power: VCC → 3V3, GND → GND. The display is optional; without it the
firmware prints `OLED: not found on GPIO21/22 (display disabled)` and runs
normally. For the wired board, also connect the A/C cable GND to ESP32 GND and
leave the cable's +5 V unconnected (see `rmutt_esp32_air_wired/README_WIRED_TH.md`).

Do not drive a high-power IR LED directly from GPIO17. Use a transistor driver
and a current-limiting resistor, with common ground between the ESP32 and the
driver supply.

The LED outputs are active-high and are intended for separate LEDs with a
220–330 ohm series resistor. The PZEM mains terminals and current transformer
must be installed inside a protected enclosure by a qualified electrician;
never work on them while energized.

- Green stays on whenever PZEM detects that the A/C is running.
- Red turns on in addition to green when measured operation is outside the
  allowed schedule.
- Yellow blinks during Wi-Fi connection and stays on after Wi-Fi connects.

## Setup flow

1. Open and upload `rmutt_esp32_air/rmutt_esp32_air.ino`. Keep
   `SaijoDenkiAC.h` and `SaijoDenkiAC.cpp` in the same sketch folder.
2. On first boot, the board advertises as `RMUTT-AC-XXXXXXXXXXXX`.
3. In the app, sign in as Admin, open a room, and tap
   **Add ESP32 Air Conditioner**.
4. Select the board, choose a detected Wi-Fi network, and enter its password.
   MQTT settings are supplied automatically by the Backend.
5. The ESP32 saves the settings in NVS, restarts, connects to MQTT, and
   publishes the one-time provisioning token.
6. The Backend validates the token and activates the device record.

To reconfigure a board, hold the BOOT button while resetting it, then open the
air conditioner's menu in the app and choose **Reconfigure via Bluetooth**.
The app keeps the same room/unit and rejects a different ESP32 or an occupied
database slot.

## Wi-Fi recovery retries in the background

A board that cannot reach its saved Wi-Fi opens BLE setup and stops normal
operation. From firmware 2.1.0 (air) and 1.1.0 (occupancy) it also keeps
retrying that same saved network every 30 seconds (`WIFI_RECOVERY_RETRY_MS`)
while BLE stays open, so a router reboot or a short outage no longer leaves the
board waiting for someone to walk over and press BOOT + RESET.

- Each background attempt waits at most 8 seconds (`WIFI_RECOVERY_ATTEMPT_MS`)
  instead of the usual 20, so the board is never stalled for long
- No attempt is made while a phone or PC is connected over BLE, and a session
  that starts mid-attempt is never cut off — the board keeps BLE open and tries
  again later
- Retrying only happens when BLE was opened *because of Wi-Fi*. A board opened
  by the BOOT button, or one that has never been configured, stays in setup
  mode and waits for the app
- When the network answers again the board leaves recovery on its own, stops
  advertising, reconnects MQTT and resumes reporting

Serial output during a full cycle:

```text
BLE recovery: Wi-Fi connection was lost
BLE recovery: retrying the saved Wi-Fi in the background
Wi-Fi connected: 192.168.1.72
Wi-Fi is back: leaving BLE recovery and resuming
```

## MQTT topics

For device `ESP32-AABBCCDDEEFF`:

- Command: `rmutt/ac/ESP32-AABBCCDDEEFF/command`
- State: `rmutt/ac/ESP32-AABBCCDDEEFF/state`
- Status/LWT: `rmutt/ac/ESP32-AABBCCDDEEFF/status`
- Class schedule result: `rmutt/ac/ESP32-AABBCCDDEEFF/schedule-status`
- Provisioning: `rmutt/ac/ESP32-AABBCCDDEEFF/provision`
- Provisioning ACK: `rmutt/ac/ESP32-AABBCCDDEEFF/provision-ack`

The Backend and every ESP32 must use the same broker and
`MQTT_TOPIC_PREFIX=rmutt/ac`.

Firmware 2.0.0 samples the PZEM every two seconds. It marks the air
conditioner as running after three readings at or above 30 W, and stopped
after three readings at or below 10 W. The Backend evaluates the room's real
class timetable in Asia/Bangkok and returns the result on `schedule-status`.
If that result is unavailable for two minutes, the firmware falls back to the
daily automatic on/off window saved during BLE provisioning.

## ESP32 + HLK-LD2410 occupancy board

Use the separate sketch:

```text
rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino
```

One occupancy board maps to one room and does not replace the A/C controller.
Install `ld2410` by Nick Reynolds version 0.2.2 or later because the firmware
uses its Engineering-mode per-gate API.

### Low-voltage wiring

The LD2410C module exposes five pins. Only four of them are used:

| LD2410C pin | Connect to | Used by the firmware |
|---|---|---|
| `VCC` | ESP32 `5V/VIN` | yes (verify the label and required voltage on the exact module revision before powering it) |
| `GND` | ESP32 `GND` | yes |
| `TX` | ESP32 `GPIO32` (UART RX) | yes |
| `RX` | ESP32 `GPIO33` (UART TX) | yes |
| `OUT` | leave unconnected | no |

`OUT` is the module's own presence pin: it goes high when the LD2410C decides
someone is present, using its factory thresholds. This project does not use it,
because occupancy is decided from the per-gate static energy read over UART
(`any gate > 25`), which is the rule the app and the Backend both document.

Leaving `OUT` floating is safe. It is an output driven by the module, so an
unconnected pin simply goes nowhere — it does not upset the module, the UART
stream or the ESP32. Never wire `OUT` to `5V` or `GND`: shorting an output is
the one connection that can damage the module.

`GPIO0` remains the BOOT/setup button. Use a stable low-voltage USB supply and
disconnect power before changing the wiring. This occupancy circuit does not
connect to mains electricity.

### Occupancy rule

The firmware opens UART1 at 256000 baud and requests Engineering mode at every
boot. It inspects only stationary/static energy for gates 0 through 8:

```text
any gate > 25  -> occupied = true
all gates <= 25 -> occupied = false
```

The comparison is strictly greater than 25, so a value equal to 25 is vacant.
Moving energy, moving/static distance, detection range, and other LD2410
values are ignored. Only the final boolean and sensor availability are sent.

The board advertises as `RMUTT-OCC-XXXXXXXXXXXX` and has Device ID
`OCC32-XXXXXXXXXXXX`. In the app, an Admin opens the room and selects
**Add occupancy sensor**, chooses the board and its detected Wi-Fi, and enters
the Wi-Fi password. MQTT settings come from the Backend automatically.

Occupancy MQTT topics for `OCC32-AABBCCDDEEFF` are:

- Status/LWT: `rmutt/occupancy/OCC32-AABBCCDDEEFF/status`
- Provisioning: `rmutt/occupancy/OCC32-AABBCCDDEEFF/provision`
- Provisioning ACK: `rmutt/occupancy/OCC32-AABBCCDDEEFF/provision-ack`
- Online setup command: `rmutt/occupancy/OCC32-AABBCCDDEEFF/command`

The status is retained and is published whenever occupancy changes and at
least every 10 seconds. The app shows **Sensor unavailable** instead of
**Vacant** when the board is offline or the LD2410 is unavailable.

### Reading the serial log

Open the Serial Monitor at 115200 and press EN/RST. A healthy boot prints:

```text
entry 0x400805b4
RMUTT ESP32 LD2410 Occupancy Sensor
Firmware: 1.1.1
Device ID: OCC32-XXXXXXXXXXXX
LD2410 engineering mode ready
Wi-Fi connected: 192.168.1.109
Connecting MQTT: 192.168.1.153:1883 as rmutt_air
MQTT connected
Subscribed: rmutt/occupancy/OCC32-XXXXXXXXXXXX/command
```

`LD2410 not detected` means the radar did not answer on UART1 at 256000 baud.
Check that the module `TX` goes to `GPIO32` and `RX` to `GPIO33` (crossed, not
straight), that `VCC` really has 5 V and that both boards share `GND`. From
firmware 1.1.1 the sketch retries the radar every 10 seconds, so fixing the
wiring is enough — the board does not have to be rebooted, and the message is
printed once instead of on every retry.

`MQTT connection failed, state: N` uses the PubSubClient codes:

| state | meaning | usual cause |
|---|---|---|
| `-4` | connect timeout | broker IP reachable but not answering |
| `-2` | network connect failed | wrong IP, broker down, or a firewall blocking 1883 |
| `4` | bad credentials | the MQTT password changed after the board was provisioned |
| `5` | not authorised | the ACL does not allow that topic prefix |

The host and port printed on the `Connecting MQTT:` line come from the board's
own NVS, so that line shows exactly which broker address was saved during BLE
provisioning. If it does not match the PC's current LAN IP, run `run_all.ps1`
and provision the board over Bluetooth once more.

### The `[diag]` heartbeat

From firmware 1.1.2 the occupancy board prints a full status block every ten
seconds, so the values that usually cause trouble never have to be guessed:

```text
[diag] wifi=yes ip=192.168.1.109 rssi=-52 | mqtt=yes state=0 target=192.168.1.110:1883 | ble=off | room=16101 topic=rmutt/occupancy/OCC32-605F1971FE68
[diag] radar init=0 engineeringEnabled=0 isConnected=0 engineeringRetrieved=0 available=0 occupied=0
[diag] UART1 rx bytes in the last 10s: 0
[diag] nothing arrives on GPIO32. Check module TX -> GPIO32 ...
Status -> rmutt/occupancy/OCC32-605F1971FE68/status {"online":true,...,"radarAvailable":false,"occupied":false}
```

How to read it:

| line | what it proves |
|---|---|
| `wifi=` / `ip=` / `rssi=` | the board is on the LAN, and how strong the signal is (weaker than -75 dBm drops often) |
| `mqtt=` / `state=` / `target=` | whether the broker accepted it, and the broker address saved in NVS |
| `room=` / `topic=` | the room and topic saved during provisioning, so a mismatch with the Backend prefix is visible |
| `radar ...` | each condition of `radarAvailable` separately, instead of one merged flag |
| `UART1 rx bytes` | **0** means the radar sends nothing at all — wiring or power. A number above zero with no valid frames means the baud rate is wrong, and the hex preview that follows shows the raw bytes |
| `[gates]` | every static gate 0-8 with its energy, the maximum, and the resulting decision — use it to sanity-check the `> 25` rule in the real room |
| `Status ->` | the exact JSON published to MQTT, so it can be compared with what `npm run db:doctor` reports |

While the radar is not initialised the sketch reads the UART itself to count
those bytes; once the radar answers, the `ld2410` library takes the stream back
and the `[gates]` line replaces the byte counter.

### Why availability is time based, not instantaneous

`ld2410::engineeringRetrieved()` reports **one frame once** — it returns `true`
for a frame that has just been decoded and clears the flag as it does so. Using
it directly as the "sensor is available" condition made the state flap between
available and unavailable several times a minute, and every flap published a
retained MQTT status, so the app kept swapping between a real reading and
**Sensor unavailable**. Anything else that called the same function, including
the `[diag]` block, stole the flag from `updateOccupancy()` and made it worse.

From firmware 1.1.3 the sketch stores the time of the last decoded frame and
the detection result taken from it:

```cpp
if (freshFrame) { lastRadarDataAt = millis(); lastRadarDetected = ...; }
radarAvailable = radarInitialised && radarEngineeringEnabled &&
                 lastRadarDataAt != 0 &&
                 millis() - lastRadarDataAt < RADAR_DATA_TIMEOUT_MS;   // 3 s
```

The radar sends about ten frames per second, so three seconds of silence is a
real fault rather than a missed frame. The `> 25` rule itself is unchanged: it
is still evaluated on every frame that arrives. `[diag]` now prints `dataAge`
instead of the flag, and never calls the consuming function.

### Diagnostic sketches for a silent LD2410

When `[diag]` reports `UART1 rx bytes in the last 10s: 0`, the radar is sending
nothing at all. Zero bytes — as opposed to garbage bytes — rules out a plain
baud-rate mismatch, so the fault is upstream of the protocol: either the ESP32
pin cannot receive, or the wire is on the wrong module pad.

Two throwaway sketches narrow that down without guessing. Neither one erases
NVS, so the room number and the MQTT settings survive; flashing the main sketch
back restores normal operation.

| sketch | question it answers |
|---|---|
| `ld2410_probe/ld2410_probe.ino` | Are `GPIO32`/`GPIO33` electrically sound, and does the module answer on either of them at 256000, 115200 or 57600 baud, in either wiring direction? |
| `ld2410_pinscan/ld2410_pinscan.ino` | Which ESP32 pin — out of all 18 that can be scanned — is the module's TX wire actually reaching? |

Run `ld2410_probe` first. If it clears both pins and still finds no data, run
`ld2410_pinscan`.

#### `ld2410_pinscan`

Leave `VCC` and `GND` connected as usual, then move a single wire from the
module's suspected `TX` pad to one ESP32 pin at a time. **`GND` must be shared
between the two boards** or the scan detects nothing regardless of the pin.

Open the Serial Monitor at 115200. The sketch prints a full table once, then
re-scans every two seconds printing only the pins that are not free, so the
wire can be moved around while watching the output live.

Each pin is classified by reading it under an internal pull-up, then under an
internal pull-down, then counting how many times the level flips in 250 ms:

| verdict | meaning |
|---|---|
| `ว่าง` (free) | the pin follows whichever internal pull is enabled — nothing is attached, and the pin itself is healthy |
| `<<< UART` | 20–8000 flips per 250 ms — real data is arriving here |
| `ต่ออยู่ HIGH ค้าง` | something drives the pin high but never changes — a wire is attached to a pad that is not transmitting, so try another pad |
| `ต่ออยู่ LOW ค้าง` | the pin is tied to `GND`; do not use it |
| `แกว่งเร็ว` | more than 8000 flips per 250 ms — too fast to be LD2410 frames. A 32.768 kHz crystal produces roughly 16000, so a board with one fitted to `GPIO32`/`GPIO33` shows up here. Use a different pin |

The band matters: LD2410 sends about 30 bytes every 100 ms, which is a few
hundred flips per 250 ms, an order of magnitude below a watch crystal. That gap
is what separates real data from an oscillator.

When a `<<< UART` pin is found the sketch opens UART1 on it at 256000, 115200
and 57600 in turn, looks for an LD2410 frame header (`F4 F3 F2 F1` for data,
`FD FC FB FA` for command replies), and prints the exact constants to paste into
`rmutt_esp32_occupancy.ino`:

```text
constexpr uint8_t  RADAR_RX_PIN = 26;
constexpr uint32_t RADAR_BAUD   = 256000;
```

Pins excluded from the scan, and why:

| pins | reason |
|---|---|
| `6`–`11` | wired to the internal flash chip; touching them hangs the board |
| `1`, `3` | the USB serial link to the PC |
| `0` | the BOOT button |
| `34`–`39` | input-only with no internal pull resistors, so a floating pin reads as noise. They still work as a UART RX — they just cannot be auto-detected, and have to be tried by hand |

Do not leave a wire on `GPIO12` while pressing reset. If `GPIO12` is pulled
high at boot the ESP32 selects the wrong flash voltage and will not start.

If every pin is scanned and nothing registers, the wire is on the wrong module
pad. The LD2410C has five pads and the one silkscreened `TX` is not always the
one that transmits — move to another pad and scan again.
