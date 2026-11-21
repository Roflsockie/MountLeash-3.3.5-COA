# MountLeash (Ascension / CoA fork) — Changelog

## 2026-11-21 hotfix

### Fixed

- **Frozen options tab.** *Enabled Mounts* used to build one AceConfig control per mount in a single pass; large mount collections hung the game. Mounts are now split into pages of 25 (`childGroups = "tab"`).
- **Weighted mount selection.** Added a `Weighted Mounts` toggle on the General tab and a `Weight` selector for every mount on the Enabled Mounts tab. Weights match PetLeash: `0, 1/64, 1/8, 1, 8, 64` (`Never`, `-2`, `-1`, `Normal`, `+1`, `+2`). `Never` is skipped; if all weights are zero, selection falls back to uniform random. Weights also apply to location/specialization override lists.
- **Ascension-only APIs.** `SpecializationUtil.GetActiveSpecialization()` and `C_Manastorm.IsInManastorm()` are guarded, so a client that renamed or removed them no longer errors.
- **Keybindings.** `Bindings.xml` listed in the TOC; `/mountleash` and `/pl` registered. `/pl config` opens settings, `/pl summon` summons.
- **Enable All / Disable All** now iterate the real companion list rather than config-table keys, which changed when pagination was introduced.
- **TOC attribution** added: original author, port author, upstream link and hotfix date.

### Verified

- `verify-addon.mjs` with the 3.3.5 API index and client API extra: exit 0.
- Lua syntax parsed for all 5 `.lua` files: no errors.
- In-game on a Conquest of Azeroth / Ascension client: Enabled Mounts opens without a freeze; `Enable All` → `Weighted Mounts` → one mount at `+2`, all others `Never` → repeated `/pl summon` picked that mount; no Lua errors.

### Still needs checking

- Large mount collections (the original reporter had many more than the 6 used in testing).
- Location rules with weights: city/resting, battleground/arena, dungeon, raid, Manastorm, custom zones/subzones and `Inherits From`.
- Specialization sets and the `ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED` event on other/newer clients.
- Dismount options and Ground / Flyable / Either behaviour in flyable areas.
- Profiles and persistence of `mount_weight` in `MountLeashDB`.
- LibDataBroker launcher (requires the client to provide `LibDataBroker-1.1`).
