<div align="center">

<img src="https://r2.fivemanage.com/GPYOH8Hq4GPyAY7czrgLe/pulsarbanner.png" alt="Pulsar Framework" width="100%" />

<br/>

# PULSAR-VEHICLES

### The core vehicle system — spawning, keys, VIN identification, personal plates, impound/storage, sirens, and pursuit modes

<br/>

![Lua](https://img.shields.io/badge/Lua_5.4-2C2D72?style=flat-square&logo=lua&logoColor=white)
![FiveM](https://img.shields.io/badge/FiveM-F40552?style=flat-square)

<br/>

<sub>Enjoy the framework? A coffee helps keep active development, hardening, and support going.</sub>

<a href="https://buymeacoffee.com/pulsarframework"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 50px !important;width: 180px !important;" /></a>

<br/>

[Overview](#overview) · [Dependencies](#dependencies)

</div>

---

## Overview

Registers `plsr.Vehicles`. Owns vehicle spawning, key ownership, VIN-based identification, personal plates, impound and long-term storage, and the siren/pursuit-mode data other resources (police vehicles, emergency boats) read from. `client/antifuck.lua` covers anti-desync/anti-dupe handling for spawned vehicles.

> [!WARNING]
> Widely depended on — dealerships, mechanic, taxi, and every job with a vehicle all build on top of this. Fires `Vehicles:Client:EnterVehicle`/`ExitVehicle`, which other resources hook directly.

---

## Dependencies

- `pulsar_core` — framework core
- `pulsar_polyzone` — zone detection for vehicle-adjacent interactions
- `pulsar_pwnzor` — anti-cheat check loaded alongside every resource

---

## License

This resource is free to use and modify under the [Pulsar Framework License](LICENSE.md). Redistribution is welcome as long as it stays free — selling this resource or any derivative of it requires written permission from the Pulsar Framework team.

---

<div align="center">

![Pulsar Framework](https://img.shields.io/badge/Pulsar-Framework-7c3aed?style=flat-square)
![Built for FiveM](https://img.shields.io/badge/Built_for-FiveM-F40552?style=flat-square)

</div>
