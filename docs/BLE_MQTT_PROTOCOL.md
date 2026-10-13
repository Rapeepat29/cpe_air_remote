# RMUTT ESP32 Air Protocol v1

## Device identity

- Device ID: `ESP32-` plus the 12 uppercase hexadecimal digits from the ESP32
  eFuse MAC.
- BLE name: `RMUTT-AC-` plus the same 12 digits.
- One database device maps to one `(roomNumber, airNumber)` pair.

## BLE GATT

| Purpose | UUID | Properties |
|---|---|---|
| Service | `7b570001-a243-4e5b-8f13-179af81b2457` | Primary service |
| Config | `7b570002-a243-4e5b-8f13-179af81b2457` | Write |
| Status/ACK | `7b570003-a243-4e5b-8f13-179af81b2457` | Read, Notify |
| Identity | `7b570004-a243-4e5b-8f13-179af81b2457` | Read |
| Nearby Wi-Fi | `7b570005-a243-4e5b-8f13-179af81b2457` | Read |
| Saved settings (firmware 1.6+) | `7b570006-a243-4e5b-8f13-179af81b2457` | Read |

The identity characteristic returns:

```json
{
  "deviceId": "ESP32-AABBCCDDEEFF",
  "bleName": "RMUTT-AC-AABBCCDDEEFF",
  "firmwareVersion": "1.0.0",
  "configured": false,
  "controlType": "ir"
}
```

`controlType` (firmware 2.5.0+) tells the app how the board drives the A/C:
`"ir"` for `rmutt_esp32_air`, `"wired"` for `rmutt_esp32_air_wired`. Older
boards omit it and are treated as `"ir"`. A wired board also sends
`"brand": "Daikin"`; the app then locks the brand field to *Daikin · Wired*
and reserves the unit with protocol `DAIKIN_WIRED` instead of offering IR
protocols. The wired firmware stores `DAIKIN_WIRED` whatever protocol it is
sent.

Firmware 1.6 keeps this identity payload compact so that Windows WinRT can
verify a newly connected board without a long GATT read timing out. When the
board is already configured, the optional Saved settings characteristic
returns the room/unit, display name, IR protocol, SSID (never its password),
MQTT host/port/username, password-presence flags, and daily schedule. The app
also remains compatible with older firmware that included those values in the
Identity characteristic.

Reading the Nearby Wi-Fi characteristic makes the ESP32 scan at its installed
location. It returns up to eight unique networks, strongest first. Each compact
array contains `[SSID, RSSI dBm, isSecure]`:

```json
{
  "ok": true,
  "networks": [
    ["RMUTT-WiFi", -42, true],
    ["Guest", -68, false]
  ]
}
```

The scan never returns Wi-Fi passwords. The app only allows an SSID detected
by the selected ESP32, then asks the administrator for that Wi-Fi password.

Config JSON is UTF-8 and split into BLE packets. Every packet contains:

| Byte | Value |
|---|---|
| 0 | Protocol version (`1`) |
| 1 | Message type (`1` = config) |
| 2–3 | Zero-based sequence number, big-endian |
| 4–5 | Total packet count, big-endian |
| 6… | UTF-8 JSON bytes |

The app first reserves the database position and receives a one-time
provisioning token together with the Backend-managed MQTT connection settings.
It then writes Wi-Fi, MQTT, room, air number, IR protocol, and daily schedule
over BLE. MQTT settings come only from `backend/.env`; they are not entered in
the Flutter form. The ESP32 returns a JSON ACK via notification.
For reconfiguration, the same Device ID may refresh its saved settings only at
its existing room/air position. A different Device ID or occupied position
returns HTTP `409` before the BLE write begins.

`airProtocol` uses an uppercase IRremoteESP8266 decode type supported by
`IRac`, or the custom value `SAIJO_DENKI`. Examples include `DAIKIN`,
`MITSUBISHI_AC`, `PANASONIC_AC`, `GREE`, `MIDEA`,
`LG`, `SAMSUNG_AC`, `TOSHIBA_AC`, `HITACHI_AC`, `FUJITSU_AC`, `KELVINATOR`,
`SHARP_AC`, `ELECTRA_AC`, `HAIER_AC`, `HAIER_AC160`, `HAIER_AC176`, or
`HAIER_AC_YRW02`.

`SAIJO_DENKI` is routed to the bundled custom 72-bit sender instead of `IRac`.
Its currently verified command range is Power, Cool, 18–29 °C, Fan Auto/Low/
Medium/High, and vertical Swing Auto/Top/Middle/Bottom.

## MQTT command

Topic: `rmutt/ac/<deviceId>/command`

```json
{
  "version": 1,
  "commandId": "UUID",
  "sentAt": "ISO-8601",
  "state": {
    "power": true,
    "temperature": 24,
    "mode": "cool",
    "fanSpeed": "auto",
    "verticalSwing": "auto",
    "horizontalSwing": false,
    "eco": false,
    "turbo": false,
    "sleep": false,
    "quiet": false,
    "displayLight": true,
    "clean": false,
    "timerOnMinutes": null,
    "timerOffMinutes": null
  }
}
```

The device publishes the applied IR state to `/state`, availability and PZEM
measurements to `/status`, and its one-time token to `/provision`.

### Unprovision (device removed from the app)

Sent by the backend to `<prefix>/<deviceId>/command` on both A/C and occupancy
boards (A/C 2.5.1, wired 2.5.2-slm8, occupancy 1.3.2 and later). Never retained.

```json
{ "version": 1, "commandId": "UUID", "sentAt": "ISO-8601",
  "action": "unprovision", "deviceId": "ESP32-AABBCCDDEEFF" }
```

The board ignores it unless `deviceId` is its own. Otherwise it publishes one
non-retained acknowledgement to `/status`, clears its own retained `/status`
(and `/state` on A/C boards), disconnects cleanly, erases its NVS settings
(plus the offline-history partition on A/C boards) and restarts into BLE setup:

```json
{ "deviceId": "ESP32-AABBCCDDEEFF", "online": false, "unprovisioned": true }
```

The backend waits up to 4 s for this acknowledgement before it clears the
retained topics and deletes the device's MQTT account.

Firmware 2.0 status example:

```json
{
  "online": true,
  "deviceId": "ESP32-AABBCCDDEEFF",
  "pzemAvailable": true,
  "acRunning": true,
  "outsideSchedule": false,
  "voltage": 229.8,
  "current": 2.145,
  "powerWatts": 465.2,
  "energyKwh": 12.345,
  "frequencyHz": 50.0,
  "powerFactor": 0.94
}
```

The wired board (`rmutt_esp32_air_wired`) adds these fields to `/status`:

```json
{
  "controlMode": "wired",
  "airBrand": "Daikin",
  "busOk": true,
  "compressorRunning": true,
  "unitRoomTemperature": 27,
  "roomTemperature": 27.4
}
```

When `controlMode` is `wired` and the database still holds an IR protocol for
that device (for example, reserved from an older app), the Backend changes it
to `DAIKIN_WIRED`. For `DAIKIN_WIRED` the Backend accepts only Cool/Dry/Fan,
fan Auto/Low/Medium/High, vertical swing Auto/Off, and Sleep (not in Dry); Eco,
Turbo, Quiet, Clean and horizontal swing are forced off. The REST API returns
`controlType: "wired" | "ir"` with every air conditioner.

The Backend checks `class_schedules` for the device's room using
`Asia/Bangkok` and publishes a retained response to
`rmutt/ac/<deviceId>/schedule-status`:

```json
{
  "version": 1,
  "classScheduleConfigured": true,
  "withinClassSchedule": false,
  "evaluatedAt": "2026-08-19T12:00:00.000Z",
  "timezone": "Asia/Bangkok"
}
```

The Backend validates the retained token, activates the database row, sends a retained
acknowledgement containing the same token on `/provision-ack`, and clears the
retained provisioning message. The ESP32 removes its token from NVS only after
receiving the matching acknowledgement.

## Room occupancy sensor (ESP32 + HLK-LD2410)

The occupancy sensor is a separate ESP32 assigned one-to-one with a room.

- Device ID: `OCC32-` plus 12 uppercase hexadecimal digits from the eFuse MAC
- BLE name: `RMUTT-OCC-` plus the same 12 digits
- Identity includes `"deviceType": "occupancy"`
- It uses the same GATT UUIDs and chunked JSON transport described above

The app reserves the room at `POST /api/occupancy-sensors/reservations`, then
writes the Backend-managed MQTT settings and one-time token over BLE. A room
can have at most one occupancy sensor.

The decision uses only Engineering-mode stationary energy at gates 0 through
8. If any gate is strictly greater than 25, `occupied` is true. When all gates
are at or below 25, it is false. No moving energy, target distance, or raw gate
array is published.

Topic layout for `OCC32-AABBCCDDEEFF`:

- Status/LWT: `rmutt/occupancy/OCC32-AABBCCDDEEFF/status`
- Provisioning: `rmutt/occupancy/OCC32-AABBCCDDEEFF/provision`
- Provisioning ACK: `rmutt/occupancy/OCC32-AABBCCDDEEFF/provision-ack`
- Online setup command: `rmutt/occupancy/OCC32-AABBCCDDEEFF/command`

Status example:

```json
{
  "online": true,
  "deviceId": "OCC32-AABBCCDDEEFF",
  "roomNumber": "16203",
  "radarAvailable": true,
  "occupied": true,
  "staticThreshold": 25
}
```

The Backend persists only availability and the final occupancy boolean. If
`online` or `radarAvailable` is false, clients must show an unavailable state
instead of interpreting the room as vacant.
