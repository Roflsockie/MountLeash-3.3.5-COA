# MountLeash — Ascension / Conquest of Azeroth fork

A Project Ascension-specific fork of **MountLeash v1.6.6** for WoW 3.3.5a (`Interface: 30300`). The original MountLeash was itself a remix of **PetLeash** by End. The original Ascension repository is no longer available, so this fork keeps the original MIT notice and adds the fixes described below.

## What it does

- Summons a random mount from the mounts you enabled (`/pl summon` or a keybinding).
- Filters mounts by mode: **Disable**, **Ground**, **Flyable**, **Either**.
- Uses different mount sets for locations (city/resting, battleground/arena, dungeon, raid, Manastorm) and custom zones/subzones, with inheritance from another set.
- Uses per-character sets for Ascension specializations (`customSpec`).
- Optional dismount on ground/in air, immediate re-summon while mounted, and a "could not summon" message.
- LibDataBroker launcher: left-click toggles summoning, right-click opens the mount menu, Ctrl+click opens settings.

## Hotfix (2026-11-21)

- **Enabled Mounts tab no longer freezes.** The old config table created one AceGUI control for every known mount at once. Mounts are now split into pages of 25.
- **Weighted mounts.** A `Weighted Mounts` toggle was added to the General tab and a `Weight` selector to every mount on the Enabled Mounts tab. Weights are `Never / -2 / -1 / Normal / +1 / +2` (`0, 1/16, 1/4, 1, 4, 16`) — the PetLeash ordering with a narrower spread so Low Priority is actually visible. Weights also apply to location and specialization override sets.
- **One-button macro.** The General tab shows the macro text in a copyable box and has an `Add Macro` button that creates (or updates) the `MountLeash` macro in the General macro tab:
  ```
  #showtooltip
  /run if IsMounted() then Dismount() else MountLeash:SummonMount() end
  ```
- **Safer Ascension APIs.** `SpecializationUtil.GetActiveSpecialization()` and `C_Manastorm.IsInManastorm()` are checked for existence before use.
- **Bindings.xml** is now listed in the TOC; slash commands `/mountleash` and `/pl` are registered (`/pl config` opens settings, `/pl summon` summons, `/pl` alone prints help).

## Install

Download/copy the `MountLeash` folder into `Interface\AddOns` of your 3.3.5a Ascension/Conquest of Azeroth client, then `/reload`.

Before the first summon, open **Interface → Addons → MountLeash → Enabled Mounts** and click **Enable All** (all mounts default to `Disable`). To test weights, enable `Weighted Mounts` on the General tab, set one mount to `+2` and the rest to `Never`, then use `/pl summon` repeatedly.

## Verification

- Static addon verifier: `node E:\AI\Tools\wow335\verify-addon.mjs MountLeash --api-extra E:\AI\Tools\wow335\api-extra-335.json` — exit 0.
- Lua syntax: all 5 `.lua` files parsed successfully.
- In-game: options tab opens without a freeze; `+2` vs `Never` weighting and `/pl summon` confirmed by the user. The 2026-11-22 macro button works with no errors; a 50-pull test with `+1 / Normal / -1` gave 39 / 8 / 3 picks (78% / 16% / 6%).

## Credits and license

- Original **PetLeash**: End (endx7) — <https://www.wowinterface.com/downloads/info12359-PetLeash.html>
- **MountLeash v1.6.6** and Ascension port: Xan-Asc / Xan. Original MIT notice is kept in [LICENSE](LICENSE).
- **Fork author:** Miss Click (GitHub: Roflsockie).
- **Bug fixes and improvements:** discovered and implemented with the help of an AI assistant (2026-11-21/22).

See [CHANGELOG.md](CHANGELOG.md) for the complete change list and remaining checks.
