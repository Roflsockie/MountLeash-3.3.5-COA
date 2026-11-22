# MountLeash (Ascension / CoA fork) — Changelog

Fixes and feature work in this fork were discovered and implemented with the help of an AI assistant at the direction of the fork author Miss Click (2026-11-21/22).

## 2026-11-22 (local, not pushed yet)

- **Macro helper on the General tab.** A copyable multi-line box now shows the one-button macro, and an `Add Macro` button creates or updates the `MountLeash` macro in the General macro tab. The button checks combat lockdown and free slots, and reports success/no-op through `self:Print`.
- **Weight spread reduced from W=8 to W=4.** With the PetLeash values, `+1 / Normal / -1` had probabilities ~87% / 11% / 1.4% — Low Priority was expected roughly once in 70 summons. With W=4 the same setup gives ~76% / 19% / 4.8%, so Low Priority shows up a few times in 50 pulls while High Priority still dominates.
- **Pick log for analysis.** A `Log mount picks` toggle stores the last 500 summons (time, mount name, spell ID, source, weight index) in `MountLeashDB.pick_log`; `Clear pick log` and `/pl log` help manage it.
- **In-game verification:** 50 macro presses with `+1 / Normal / -1` produced 39 / 8 / 3 picks (78% / 16% / 6%), matching the expected 76% / 19% / 5%. The macro button works with no Lua errors.
- Verified with `verify-addon.mjs` (exit 0) and luaparse (all 5 `.lua` files OK). Not pushed yet — awaiting the owner's go-ahead.

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
