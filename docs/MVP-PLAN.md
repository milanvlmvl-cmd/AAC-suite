# AAC-suite — MVP Plan (ArcheAge Classic assistant)

> Status: **plan only, no code.** Version 2, 2026-11-04.
> Scope: gold profit across all activities, time tracking, leadership tracking, and an hourly AI check-in.

### What changed since v1

- Built against the real `api.lua`: 206 `UI_EVENTS`, about 120 API functions, and the 5 events named in the `api.On` comment.
- Matched to the PlayerDB/RaidsDB pattern: the addon writes Lua-table `.dat` files, and the sync app sends them unmodified (PlayerDBSync).
- Platform is **Linux + Proton**, not Windows.
- Leadership is now a **hero-month target** (4,000 points → 90,000 g + ring). It cannot be spent and resets each period.
- Profit is **broadened to every activity**: packs, fishing, ganking, larceny/mob farming, crafting, gathering. The Excel crafting loop is replaced by a simpler "best labor sink" loop.
- Labor model facts are in: 40 per 5 min online and offline, 10,000 cap, Coin = copper.

---

## 0. Inputs and what they settled

| Input | What it settled |
|---|---|
| `api.lua` (attached) | The full list of available API calls. **The `api.On` comment documents five events: `UPDATE` (dt, every frame), `CHAT_MESSAGE`, `TEAM_MEMBERS_CHANGED`, `UI_RELOADED`, `UPDATE_PING_INFO`.** `UPDATE` is *not* in `UI_EVENTS`. The other **206 `UI_EVENTS` entries are unverified** until the event test (§13) sees them fire. |
| PlayerDBSync (github.com/Madpeterz/PlayerDBSync) | Addon output is `*.dat` files holding a **Lua table literal** (from `api.File:Write(path, tbl)`), with an `addon_version = "x.y.z"` field. The addon keeps the bookkeeping files `_count.dat` and `_files.dat` itself, because the API cannot list a directory. The app uploads changed files **unmodified**, deduplicated by SHA-256, in batches. **The channel works both ways while the game runs:** the app rewrites `RaidsDB/ignore.dat` every 15 min and answers `Demos/request.dat` (`{ status = true }` → `false`), and the addon reads those files. |
| `analyze.py`, `ledger.py` (aa-classic-profit skill) | The recursive buy-vs-craft coster and the s/l ranking are kept as a library. The Excel ledger loop is **retired** (§7). |
| Your notes | Linux/Proton path · leadership rules · currency units · labor regen and cap · daily reset · timers-page DST bug · in-game time cycle · broadened activity scope |

**Not reachable from this session:** the PlayerDB/RaidsDB example addons on your PC (no computer folder is shared). See §11, item 1.

---

## 1. Architecture

```
ArcheAge Classic (Proton)
  addon "aacs"  ── api.File:Write ──►  …/Documents/AAClassic/Addon/aacs/out/*.dat
                ◄─ api.File:Read  ───  …/Addon/aacs/in/inbox.dat   (written by the uploader)
                                             │
Go uploader (Linux, user systemd service + tray)
  scan every 10 s → hash → skip seen → validate → INSERT raw (bytes unmodified)
  writes inbox.dat · desktop notifications (D-Bus / notify-send)
                                             │
Postgres  raw.*  (immutable)  ──►  rules engine (Python worker)
                                     ├ parse Lua-table literals (no execution)
                                     ├ normalize → core.* (sessions, samples, segments)
                                     ├ labor model, leadership pace, activity stats
                                     ├ opportunity ranker (labor sinks + activities)
                                     ├ question generator, check-in scheduler
                                     └ recommendation evaluators
                                             │
Website (FastAPI + htmx, local)   dashboard · check-in chat · activities · leadership · catalog · budget
                                             │
LLM router ── local LLM (Ollama) · Claude API (Sonnet 5.5 / Haiku 5.5), hard $ cap
```

**Principles**

1. **Copy PlayerDBSync's transport rule.** The uploader sends file bytes unmodified and never interprets them. Parsing happens in the DB worker, so any parser fix can be replayed over all history.
2. **Raw is immutable and everything else can be rebuilt.** That is what makes "capture too much" safe.
3. **Local-first.** `docker compose` on the gaming PC runs Postgres, the worker and the web app. The uploader is a native Linux binary. Ollama runs locally.
4. **Read-only addon.** It never calls a function that acts in the game (§2.4).
5. **Deterministic numbers, LLM for words.** Every LLM suggestion goes through the recommendation ledger.
6. **Never execute `.dat` content.** The worker parses Lua table literals with a strict grammar-only parser (tables, strings, numbers, booleans, nil). It never runs them in a Lua VM.

---

## 2. Probe and capture addon spec

One addon folder, `aacs`, with a `mode` setting in `api.GetSettings("aacs")`: `probe` (event test) or `capture` (daily use).

### 2.1 Modules

| Module | Responsibility |
|---|---|
| `boot` | Reads settings and `_count.dat` (the last session counter), makes `sess_key`, records the API surface (introspection, §2.5), and wraps everything in `pcall`. |
| `subscribe` | Calls `pcall(api.On, name, handler(name))` for **every** `UI_EVENTS` value **plus** `CHAT_MESSAGE`, `TEAM_MEMBERS_CHANGED`, `UI_RELOADED` and `UPDATE_PING_INFO`. `UPDATE` is used **only** as the scheduler tick and is never logged. Records success, error or silent acceptance per event. |
| `handler` | Generic varargs handler: event name, `select('#', ...)`, serialized arguments (depth ≤ 4, string ≤ 512, ≤ 64 keys, cycle-safe), plus counters per event. |
| `enrich` | When certain events fire, runs follow-up getters (§2.3) so each record carries its context (gold after a sale, bag after an item event). |
| `poller` | Tiered getters driven by the `UPDATE` dt accumulator. It writes **only changes**, plus a full keyframe every 5 min. |
| `sampler` | Counts are always exact. Payloads are kept in full for the first 200 per event per session, then 1 in N, with N adapting to keep each event ≤ 2 records/s. |
| `writer` | Buffers records and rotates chunks (§3). One `api.File:Write` per chunk. Updates `_count.dat`. |
| `inbox` | Every 30 s, `api.File:Read("aacs/in/inbox.dat")`. When a new `msg_id` appears, it shows a small in-game window with "check-in due" or a one-line suggestion (`api.Interface:CreateWindow`/`CreateWidget`). This is optional; it depends on A27. |
| `selfmon` | Handler and poller time measured with `Time:GetUiMsec`, dropped records, disabled getters, buffer peak. Emits `K` records. |
| `marker` | An in-game button on the addon window ("mark: crafting / packs / fishing …") writes `T` records for the event test. No chat commands are needed. |

### 2.2 Event coverage (all 206 + 4, wide by design)

Every `UI_EVENTS` entry is subscribed. The table only groups them by **what they should tell us**. All of them are unverified until §13.

| Domain | Events (selection) |
|---|---|
| Gold and currencies | `PLAYER_MONEY`, `PLAYER_BANK_MONEY`, `MONEY_ACQUISITION_BY_LOOT`, `PLAYER_HONOR_POINT`, `PLAYER_LIVING_POINT`, `PLAYER_CONTRIBUTION_POINT`, **`PLAYER_LEADERSHIP_POINT`**, `PLAYER_AA_POINT`, `PLAYER_BANK_AA_POINT`, `PLAYER_BM_POINT`, `PLAYER_JURY_POINT`, `RESIDENT_SERVICE_POINT_CHANGED` |
| Labor | **`LABORPOWER_CHANGED`**, `PREMIUM_LABORPOWER_CHANGED` |
| Items | `ADDED_ITEM`, `REMOVED_ITEM`, `EXPIRED_ITEM`, `ITEM_ACQUISITION_BY_LOOT`, `BAG_UPDATE`, `BAG_EXPANDED`, `BANK_UPDATE`, `BANK_EXPANDED`, `COFFER_UPDATE`, `LOOT_BAG_CLOSE`, `LOOT_DICE`, `LOOT_PACK_ITEM_BROADCAST`, `ITEM_EQUIP_RESULT`, `UNIT_EQUIPMENT_CHANGED`, `UPDATE_DURABILITY_STATUS` |
| AH / mail / trade | **`AUCTION_BOUGHT_BY_SOMEONE`**, `AUCTION_BIDDEN`, `MAIL_INBOX_UPDATE`, `MAIL_INBOX_MONEY_TAKEN`, `MAIL_INBOX_ITEM_TAKEN`, `MAIL_INBOX_ATTACHMENT_TAKEN_ALL`, `MAIL_INBOX_TAX_PAID`, `MAIL_RETURNED`, `MAIL_SENT_SUCCESS`, `GOODS_MAIL_INBOX_UPDATE`, **`SELL_SPECIALTY`** (trade pack turn-in) |
| Crafting / proficiency | `CRAFT_FAILED`, `SPELLCAST_START/STOP/SUCCEEDED`, **`ACTABILITY_EXPERT_CHANGED`**, `ACTABILITY_EXPERT_GRADE_CHANGED`, `ACTABILITY_EXPERT_EXPANDED`, `ABILITY_EXP_CHANGED`, `GRADE_ENCHANT_RESULT`, `ITEM_SMELTING_RESULT`, `ITEM_SOCKETING_RESULT`, `ITEM_ENCHANT_MAGICAL_RESULT` |
| Gathering / farming / doodads | `INTERACTION_START`, `INTERACTION_END`, `INTERACTION_LIST`, `DOODAD_PHASE_MSG`, `CHAT_MSG_DOODAD`, `SIM_DOODAD_MSG`, `HOUSE_FARM_MSG`, `OPEN_COMMON_FARM_INFO`, `BUILD_AREA_MSG` |
| Combat / PvP / crime | `UNIT_COMBAT_STATE_CHANGED`, `TARGET_CHANGED`, `TARGET_TO_TARGET_CHANGED`, `TARGET_OVER`, `AGGRO_METER_UPDATED`, `AGGRO_METER_CLEARED`, `EXP_CHANGED`, `HPW_ZONE_STATE_CHANGE`, `SHOW_ACCUMULATE_HONOR_POINT_DURING_HPW`, `INSTANT_GAME_KILL`, **`CRIME_REPORTED`**, `BOT_SUSPECT_REPORTED`, `DIVE_START/END` |
| Group / leadership / hero | `TEAM_MEMBERS_CHANGED`, `TEAM_ROLE_CHANGED`, `TEAM_MEMBER_DISCONNECTED`, `TEAM_HEALTH_CHANGED`, `TEAM_MANA_CHANGED`, `LOOTING_RULE_*`, `SET_OVERHEAD_MARK`, **`START_HERO_ELECTION_PERIOD`**, **`UPDATE_HERO_ELECTION_CONDITION`**, **`END_HERO_ELECTION_PERIOD`**, **`HERO_SCORE_UPDATED`**, **`HERO_SEASON_UPDATED`** |
| Session / world | `ENTERED_WORLD`, `LEFT_LOADING`, `LEAVING_WORLD_STARTED`, `LEAVING_WORLD_CANCELED`, `UI_RELOADED`, `ENTERED_LOGIN`, `LEFT_LOGIN`, `FADE_INOUT_DONE`, `OPEN_WORLD_QUEUE`, `DOMINION`, `NATION_TAXRATE`, `TOWER_DEF_MSG` |
| Fishing / special bars | `DYNAMIC_ACTION_BAR_SHOW`, `DYNAMIC_ACTION_BAR_HIDE`, `DYNAMIC_ACTION_EXECUTE` (fishing likely uses the dynamic action bar; to be verified) |
| Activity proxies | `MOUSE_DOWN` (**count only**, no coordinates), `TOGGLE_WALK`, `TOGGLE_FOLLOW`, `GLIDER_MOVED_INTO_BAG`, `IME_STATUS_CHANGED` |
| Chat | `CHAT_MESSAGE` with `CHAT_MESSAGE_FILTERS`. Text is kept for `SYSTEM`, `NOTICE`, `ADDED_ITEM_SELF`, **`SELF_MONEY_CHANGED`**, `SELF_HONOR_POINT_CHANGED`, `SELF_LIVING_POINT_CHANGED`, `SELF_CONTRIBUTION_POINT_CHANGED`, **`SELF_LEADERSHIP_POINT_CHANGED`**, `TRADE_STORE_MSG`, `SELF_SKILL_INFO`, `SELF_STATUS_INFO`, `LOOT_METHOD_CHANGED`, `RAID_COMMAND`, the `COMBAT_*` filters, `HERO_SEASON_UPDATED` and `DOMINION_AND_SIEGE_INFO`. **For other players' chat channels, only the metadata is kept** (channel, sender hash, length). |
| Everything else | Subscribed and counted. Payloads are sampled. Kept as-is in case later features need them. |

### 2.3 Getter catalog (read-only, all wrapped in `pcall`)

Tiered rates. A getter that errors 3 times in a session is disabled for that session. A getter whose single call takes more than 2 ms moves down a tier.

| Tier | When | Calls |
|---|---|---|
| **fast** | every 5 s, change-only | `Bag:GetCurrency()` · `Unit:UnitWorldPosition("player")` · `Unit:GetCurrentZoneGroup()` · `Unit:UnitHealth/UnitMaxHealth/UnitMana/UnitMaxMana("player")` · `Unit:GetUnitId("target")` + `Unit:UnitInfo("target")` + `Unit:UnitDistance("target")` + `Unit:GetFactionName("target")` · `Unit:UnitIsForceAttack("player")` · `Time:GetGameTime()` · `Time:GetUiMsec()` |
| **medium** | every 30 s | `Unit:UnitBuffCount/UnitBuff("player", i)`, `UnitDeBuffCount/UnitDeBuff` · `Team:IsPartyTeam()`, `Team:IsPartyRaid()`, `Team:GetTeamPlayerIndex()`, `Team:GetTeamDistributorName()` · roster `team1..team50`: `UnitName`, `UnitTeamAuthority`, `UnitIsOffline`, `UnitClass`, `Team:GetRole(i)` · `Bag:CountItems()`, `Bag:Capacity()` · `Map:GetPlayerSextants()` · `Player:GetCrimeInfo()` · `Unit:GetHighAbilityRscInfo()` · `Player:GetGamePoints()` · `Time:GetLocalTime()` |
| **slow** | every 5 min, on login, and 3 s after a `BAG_UPDATE` burst | full bag scan `Bag:GetBagItemInfo(1, i)` for i = 1..Capacity · `Bank:GetCurrency()`, `Bank:CountItems()`, `Bank:Capacity()`, `Bank:GetLinkText(slot)` for every slot (link text parsed server-side) · `Equipment:GetEquippedItemTooltipInfo(slot)` for every `EQUIP_SLOT` (**`BACKPACK` = trade pack carried**) · `Unit:UnitGearScore/UnitClass/UnitModifierInfo("player")` · `Unit:GetFactionName("player")` · `Player:GetShowingAppellation()` · `X2Util.GetMyMoneyString()` (cross-checks the money unit) |
| **hourly** | on login and every 60 min | **Pack economics:** `Store:GetSellerShareRatio()`, `Store:GetSpecialtyRatio()`, `Store:GetProductionZoneGroups()`, then per zone `Store:GetSellableZoneGroups(z)` and `Store:GetSpecialtyRatioBetween(a, b)` · `Zone:GetZoneStateInfoByZoneId(z)` for known zones (peace/conflict/war, which matters for ganking) · `Interface:GetScreenWidth/Height/GetUIScale` · `Option:Get*` |
| **catalog** | Manual "catalog run" button, once per patch, throttled to ≤ 20 calls per frame | **Recipe DB from the game:** `Craft:GetCraftTypesByName(group, category, "")` across all categories, then `GetCraftBaseInfo`, `GetCraftMaterialInfo` and `GetCraftProductInfo` per craft ID · `Item:GetItemInfoByType(id)` for every item ID seen (cached) · `Skill:GetSkillTooltip`, `Ability:GetBuffTooltip` for every skill/buff ID seen · `Ability:GetAbilityFromView(i)` + `IsActiveAbility` · `Equipment:GetEquippedSkillsetLunagems("player")` |
| **on event** | after the trigger | `AUCTION_BOUGHT_BY_SOMEONE`, `SELL_SPECIALTY`, `MAIL_INBOX_MONEY_TAKEN`, `MONEY_ACQUISITION_BY_LOOT` → `Bag:GetCurrency()` right away · `ADDED_ITEM`/`REMOVED_ITEM` → bag rescan, debounced 3 s · `TARGET_CHANGED` → target block · `TEAM_MEMBERS_CHANGED` → roster · `UNIT_EQUIPMENT_CHANGED`/`ITEM_EQUIP_RESULT` → equipment scan (pack on/off) · `ENTERED_WORLD`/`LEFT_LOADING` → slow + hourly tiers |

### 2.4 Hard deny-list (these functions act in the game, so never called)

`Team:InviteToTeam`, `Team:SetRole`, `Team:MoveTeamMember`, `Bag:EquipBagItem`, `Cursor:ClearCursor`, `Cursor:SetCursorImage`, `Player:ChangeAppellation`, `Option:Set*` (all three), `Chat:DispatchChatMessage`, `Chat:ExpressEmotion`, `Map:ToggleMapWithPortal`, **`Unit:TargetUnit`** (its doc says "gets" but it takes a unit argument and may change the target, so it stays denied until proven harmless), `ADDON.ShowContent`, `ADDON.RegisterContent*` for game windows, `api:Emit` (only `ADDON_AACS_*` names), `api.Log:*` (debug build only, so chat isn't spammed), and `api.SaveSettings()` (only on `LEAVING_WORLD_STARTED` and at most every 10 min; the doc says "do not call too often").

### 2.5 API-surface introspection (every login)

`pairs()` over `api` and its sub-tables to depth 2 records name and type (no calls). **This matters because `Quest`, `ItemEnchant`, `Map`, `Zone` and `Craft` are documented with functions but are missing from the `ADDON_API = {...}` declaration.** The manifest shows whether they exist at runtime. Other oddities to confirm: `api.On` uses a dot but `api:DoIn` and `api:Emit` use a colon, and the method is named `Team:IsPartyRaid`.

---

## 3. Chunk format and versioning

### 3.1 Files (matching the PlayerDB convention)

```
Addon/aacs/
  main.lua …                        (code: changed only while the game is closed)
  out/_count.dat                    { addon_version="…", sess_counter=N, last_sess="…", last_seq=M }
  out/<sessKey>_<seq6>.dat          write-once chunk
  in/inbox.dat                      written by the uploader, read by the addon (optional)
```

- `sessKey` = `Time:GetLocalTime()` formatted `YYYYMMDDhhmmss` + `sess_counter`.
- Write-once names mean a file never changes after it is written. The uploader can treat a stable name + hash as done.
- **Cleanup:** the uploader removes `out/*.dat` files older than 14 days **only while the game process is not running** (detected under Proton). That respects "no modifying while the game runs" for anything the addon owns.

### 3.2 Rotation

A chunk is closed at whichever comes first: **60 s**, **500 records**, or about **256 KB** estimated size, or on `LEAVING_WORLD_STARTED` / `UI_RELOADED` (if verified, A18/A19). Worst-case loss on a crash is one interval.

### 3.3 Chunk table (what `api.File:Write` serializes)

```lua
{
  addon_version = "1.0.0",            -- same key PlayerDB uses
  fmt = "1.0",
  hdr = { build="capture", install="…", sess="…", seq=12, mode="capture",
          clk = { ui_ms0=…, local_time={…}, game_time={…} },
          cfg_ver=3, events_hash="…", getters_ver=2, char={ name=…, faction=… } },
  rec = {                              -- array, in order
    { t="E", ms=123456, ev="LABORPOWER_CHANGED", n=2, a={ … }, s=1 },
    { t="S", ms=123460, k="Bag:GetCurrency", v=1234567, kf=false },
    { t="C", counts={ BAG_UPDATE=14, … } },
    { t="T", ms=…, text="crafting" },
    …
  },
  ftr = { n=37, last_ms=…, closed="rotate" },
}
```

| `t` | Meaning |
|---|---|
| `M` | manifest entry (introspection) |
| `R` | registration result per event |
| `E` | event (`ev`, `n`, `a`, `s` = sampling weight) |
| `S` | getter snapshot (`k`, `v`, `kf` = keyframe) |
| `C` | exact per-event counters since the last chunk |
| `T` | marker |
| `K` | health |
| `X` | error (`where`, `msg`) |

**A chunk is valid** if it parses as a Lua table literal, has `hdr` and `ftr`, and `#rec == ftr.n`. The uploader does **not** validate; it only ships bytes. The worker validates and records `parse_status` (ok / partial / bad) per chunk. If a file can't be read (the game is mid-write), the uploader retries on the next scan, as PlayerDBSync does.

### 3.4 Versioning

| Thing | Scheme | Rule |
|---|---|---|
| `fmt` | MAJOR.MINOR | Minor: new fields or record types, which older parsers keep raw. Major: the worker parks the chunks as `unsupported_fmt` until a parser exists. They are never lost, since raw bytes are kept. |
| `addon_version` | semver | Stored per chunk |
| `events_hash` | hash of the subscribed names | Separates "never fired" from "not subscribed" |
| `getters_ver` | integer | Same purpose, for getters |
| Rules | `rule_id@version` on every derived row | Rebuilt on purpose |
| DB | numbered migrations | Raw is append-only |
| **Game patch** | `game_patch` fact (date) | A patch triggers a new event test (short form) and a new catalog run |

---

## 4. Go uploader (Linux)

| Concern | Behavior |
|---|---|
| Path | Default `~/.local/share/AAClassic/steam-compatdata/pfx/drive_c/users/steamuser/Documents/AAClassic/Addon/aacs/`, configurable, with auto-detect of the PlayerDBSync-style Wine paths. |
| Scan | Every 10 s (inotify is unreliable across Proton). Files whose size and mtime match a known record are skipped. Otherwise: read with a shared open, SHA-256, skip if the hash is known, retry later on an I/O error. |
| Insert | `raw.chunk` with `ON CONFLICT (sha256) DO NOTHING`. Stores **bytes unmodified** (`bytea`) and the file metadata. **No parsing.** |
| Batching | Up to 200 files per transaction when catching up |
| Offline | Back off from 2 s to 5 min. Files stay where they are. |
| Inbox writer | Writes `in/inbox.dat` (`{ msg_id=…, kind="checkin_due" \| "note", text="…", expires=… }`) **atomically**: write a temp file, then rename (fine while the game runs; PlayerDBSync does the same with `ignore.dat`). |
| Notifications | Desktop notification through D-Bus (`notify-send`) for due check-ins. It opens the website. |
| Game detection | Process scan for the game executable under Proton. Used for cleanup timing and session hints. |
| Run as | `systemd --user` service, plus an optional tray icon |
| DB role | `aacs_ingest`: INSERT on `raw.*`, SELECT on `assistant.checkin` |
| Health | `localhost:7781/healthz` reports last file, backlog, and parse failures reported back by the worker |

---

## 5. Database schema (Postgres 16)

### 5.1 `raw`

| Table | Columns |
|---|---|
| `raw.chunk` | `chunk_id` PK · `file_name` · `sha256` UNIQUE · `bytes` bytea · `size` · `mtime` · `received_at` · `parse_status` {pending, ok, partial, bad, unsupported_fmt} · `parse_error` · `addon_version` · `fmt` · `sess_key` · `seq` · `hdr` jsonb · UNIQUE(`sess_key`,`seq`) where parsed |
| `raw.record` | `chunk_id` · `idx` · `t` · `ms` · `ts_est` timestamptz · `ev` · `k` · `payload` jsonb · PK(`chunk_id`,`idx`) · partitioned by month · indexes on (`ev`,`ts_est`) and (`k`,`ts_est`) |

`ts_est` = session wall start (from `hdr.clk.local_time`, converted with the PC's time zone) + (`ms` − `ui_ms0`). It is checked against the file mtime (A6).

### 5.2 `catalog`

| Table | Columns |
|---|---|
| `catalog.event` | `name` PK · `documented_in` {api_on_comment, ui_events} · `status` {unverified, registered, register_error, fired, verified, dead, unsafe} · `first_fired_at` · `fire_count` · `rate_p95_per_min` · `arg_shape` jsonb · `samples` jsonb (≤ 5) · `verified_by` · `notes` |
| `catalog.api_fn` | `path` PK · `exists_runtime` · `status` {listed, allowlisted, called_ok, errors, slow, denied} · `avg_ms` · `sample` jsonb |
| `catalog.chat_filter` | `filter` PK · `id_value` · `status` · `parse_pattern` (regex for the client locale) · `samples` |
| `catalog.semantic_map` | `concept` (gold, bank_gold, labor, leadership, honor, craft_done, ah_sold, pack_sold, coinpurse_opened, kill_player, death, …) · `source_kind` {event, getter, chat_filter, derived, manual} · `source_ref` · `transform` · `verified` · `since_addon_version`. **Rules depend on concepts only.** |
| `catalog.event_test` | `test_id` · `addon_version` · `script_ver` · `results` jsonb (A-id → verdict + evidence) |

### 5.3 `core` (derived and rebuildable)

| Table | Columns |
|---|---|
| `core.character` | `char_id` · `name` · `server` · `faction` |
| `core.play_session` | `session_id` · `char_id` · `started_at` · `ended_at` · `end_reason` · `active_s` · `afk_s` · `seq_gaps` |
| `core.sample` | `char_id` · `ts` · `concept` · `value` numeric · `src` (chunk, idx) · PK(`char_id`,`concept`,`ts`) |
| `core.labor_state` | `char_id` · `ts` · `labor_observed` NULL · `labor_model` · `confidence` · `to_cap_minutes` · `wasted_since_last` (§6.4) |
| `core.inventory_snapshot` | `char_id` · `ts` · `where` {bag, bank, equipped} · `items` jsonb · `value_est_g` |
| `core.activity_segment` | `seg_id` · `session_id` · `start_ts` · `end_ts` · `activity` · `sub` (route, zone, target type) · `confidence` · `rule_id@ver` · `evidence` jsonb · `label_source` {rule, classifier, user} · `gold_delta_c` (copper) · `item_value_delta_c` · `labor_spent` · `leadership_delta` · `honor_delta` · `deaths` · `context` jsonb (real hour, in-game hour, weekday, party size, zone state) |
| `core.group_state` | `char_id` · `ts` · `team_type` {solo, party, raid} · `is_leader` · `size` |

### 5.4 `knowledge`

| Table | Columns |
|---|---|
| `knowledge.item` | `item_id` · `name` · `info` jsonb (from `GetItemInfoByType`) · `tradeable` |
| `knowledge.recipe` / `recipe_material` / `recipe_product` | From the **in-game catalog run** (source=`game`), with `recipes.csv` as a fallback (source=`csv`) |
| `knowledge.price_week` | Weekly AH CSV, as before |
| `knowledge.price_observed` | Your own AH sales and purchases (item, unit price, ts). Better than the weekly sheet for items you trade. |
| `knowledge.pack_ratio` | `ts` · `from_zone` · `to_zone` · `ratio` · `seller_share` (hourly `Store:*` snapshots) |
| `knowledge.zone_state` | `ts` · `zone_id` · `state` jsonb |
| `knowledge.schedule_event` | `name` · `kind` {world_boss, daily_event, game_time_event} · `rule` (cron/real time or game time) · `source` (aa-classic.com/timers) · **`dst_correction_h`** (+1 for the "world bosses" and "daily events" headers in winter, 0 for game-time events) |
| `knowledge.fact` | `key` · `value` jsonb · `source` {user, doc, observed} · `valid_until` · `confidence`. Seeded with: `labor.regen_per_5min=40` (online and offline), `labor.cap=10000`, `money.units` (1 g = 100 s, 1 s = 100 c; Coin = 1 c), `reset.daily_utc≈04:00` (confirm), `game_time.cycle_real_h=4`, `leadership.hero_target=4000`, `leadership.hero_reward_g=90000` (+ a 1-month ring) |

### 5.5 `econ`

| Table | Columns |
|---|---|
| `econ.proficiency` | `char_id` · `skill` · `value` · `as_of` · `source` (observed `ACTABILITY_EXPERT_CHANGED` or user) |
| `econ.exclusion` | `subject` (recipe/activity/route) · `reason` · `until` |
| `econ.transaction` | `tx_id` · `char_id` · `ts` · `kind` {ah_sale, ah_buy, mail_money, loot_money, pack_sale, vendor, tax, fee, unknown} · `item_id` · `qty` · `amount_c` · `source_record` · `segment_id` |
| `econ.activity_stats` | `activity` · `sub` · `context_bucket` · `n_segments` · `hours` · `gold_per_h_c` (mean, p25, p75) · `labor_per_h` · `silver_per_labor` · `leadership_per_h` · `honor_per_h` · `death_rate_h` · `updated_at` (§7.2) |
| `econ.labor_sink` | Ranked options: `option` (recipe / coinpurse type / pack route / gather node) · `silver_per_labor` · `silver_per_min` · `max_units_today` (volume cap) · `requires` · `basis` {observed, priced, mixed} |

### 5.6 `leadership`

| Table | Columns |
|---|---|
| `leadership.period` | `period_id` · `start_at` · `end_at` (from `START/END_HERO_ELECTION_PERIOD` and `HERO_SEASON_UPDATED`, else user) · `mode` {election, hero, off} · `target` (4000 in hero mode) · `reward_g` (90,000) |
| `leadership.progress` | `period_id` · `ts` · `points` · `rank` NULL (`HERO_SCORE_UPDATED` if it carries one) · `pace_needed_per_day` · `projected_end` · `p_reach_target` |
| `leadership.source` | `method` (from your upcoming list) · `observed_per_h` · `n` · `notes` |

### 5.7 `assistant`

Same as v1: `checkin`, `message`, `question`, `recommendation`, `rec_event`, `llm_call`, `budget_month` (see §8–§10, §12). Added: `checkin.inbox_msg_id` (if in-game notification was used).

---

## 6. Activity rules (time tracking)

### 6.1 Taxonomy

`crafting` · `pack_run` (craft, carry, sell) · `fishing` · `gathering` · `farming` (own land) · `mob_farming` · **`larceny`** (opening coin purses with labor; see note) · `ganking` / `pvp` · `group_content` (party/raid; overlays other activities) · `market` (AH/mail/vendor) · `travel` · `idle_social` · `afk` · `dead` · `unknown`.

*Note: my understanding is that larceny = opening coin purses dropped by mobs, which costs labor and trains the Larceny proficiency. Please confirm (§11).*

### 6.2 Activity fingerprints (starting rules)

Each rule only becomes active once all its concepts are verified (§13).

| Activity | Fingerprint (window 30–120 s) | Conf. |
|---|---|---|
| crafting | Repeated `SPELLCAST_START/SUCCEEDED` while stationary + `LABORPOWER_CHANGED` drops matching the recipe labor (after proficiency) + `ADDED_ITEM` of a recipe product + `REMOVED_ITEM` of materials + `ACTABILITY_EXPERT_CHANGED` | 0.9 |
| pack_run | `BACKPACK` slot holds a specialty pack (equipment scan) + movement across zone groups → ends with `SELL_SPECIALTY` + gold up. The pack-crafting step before it is linked by labor drop + pack item. | 0.9 |
| fishing | `DYNAMIC_ACTION_BAR_SHOW/EXECUTE` + fishing buffs + stationary on water + `ADDED_ITEM` of fish | 0.8 |
| gathering | `INTERACTION_START/END` + `DOODAD_PHASE_MSG`/`CHAT_MSG_DOODAD` + small labor drops + raw-material gains, away from your own land | 0.8 |
| farming | Same as gathering, near a known plot and/or `HOUSE_FARM_MSG` | 0.75 |
| mob_farming | Combat with NPC targets (`UnitInfo`) + `EXP_CHANGED` + `MONEY/ITEM_ACQUISITION_BY_LOOT`, `LOOT_BAG_CLOSE`, coin-purse items gained | 0.85 |
| larceny | Coin-purse `REMOVED_ITEM` + labor drop + gold/items gained, stationary, Larceny proficiency change | 0.9 |
| ganking / pvp | Combat with **player** targets of a hostile faction (`UnitInfo`, `GetFactionName`), `UnitIsForceAttack`, `PLAYER_HONOR_POINT` up, combat chat filters, conflict/war `zone_state`. Picking up an enemy pack then `SELL_SPECIALTY` = **ganking profit**. | 0.8 |
| group_content | `IsPartyRaid`/`IsPartyTeam`, size ≥ N, `UnitTeamAuthority("player")` (leader?), `PLAYER_LEADERSHIP_POINT` / `SELF_LEADERSHIP_POINT_CHANGED` | 0.9 |
| market | `MAIL_*`, `AUCTION_*`, NPC interaction events, gold change without labor | 0.9 |
| travel | Position change with nothing else matching. Gliding and mounts from buffs and `GLIDER_MOVED_INTO_BAG`. | 0.6 |
| afk | No position change, `MOUSE_DOWN` count 0, no combat, for ≥ 5 min (backdated) | 0.9 |
| dead | HP 0 until resurrection | 1.0 |
| fallback | `unknown`, which becomes a question candidate if > 10 min | — |

**Precedence:** explicit event > `dead` > `afk` > `pack_run` (carrying a pack dominates) > `ganking/pvp` > `larceny` > `crafting` > `fishing` > `gathering`/`farming` > `mob_farming` > `market` > `travel` > `idle_social` > `unknown`. `group_content` is an **overlay tag** on top of the primary activity.

### 6.3 Learning what activities look like

1. **Rules first** (the table above).
2. **Labels:** check-in answers and website corrections become `label_source=user` segments.
3. **Classifier (after ≥ 30 labeled segments per activity):** a small gradient-boosted model on window features (event counts per type, labor slope, gold slope, movement speed, target type, zone state, party size, buffs present). It is used **only** where it beats the rules on a held-out week, and its suggestions always carry confidence. There is no LLM in classification, which keeps it cheap and deterministic.

### 6.4 Labor model (central to profit)

- **Facts:** regen 40 labor per 5 min = **8 per minute = 480 per hour = 11,520 per day**, online and offline. Cap 10,000. Regen beyond the cap is lost. **From empty, you hit the cap in about 20.8 h.** So to waste nothing you must spend about 11.5k labor per real day, or about 3,840 per hour if you play 3 h a day.
- **State:** there is **no labor getter** in the API. Labor comes from `LABORPOWER_CHANGED` arguments (A10). Between events, and while offline, the model applies `min(cap, L + 8 × minutes)`. If the event only carries deltas, one seed value (a check-in question, P1, once) anchors it. The seed is re-asked only if the model drifts (a craft's observed labor cost contradicts it).
- **Outputs:** labor now · **minutes to cap** · labor that will be wasted before your next typical session (from your play-hour pattern) · labor wasted so far (KPI).
- **Shadow price of labor:**
  - If the forecast says labor overflows before the next session, the overflow is **free** (0 s/l): burn it on the highest silver-per-minute sink, even a low s/l one.
  - Otherwise labor costs the best available s/l among the labor sinks (§7.3).

### 6.5 Leadership tracking

- **Source:** `PLAYER_LEADERSHIP_POINT`, `SELF_LEADERSHIP_POINT_CHANGED` chat lines, and hero events. If no absolute value comes through (A11), one value per session is asked.
- **Periods:** start and end from the hero election/season events, or from you. Leadership **cannot be spent and resets each period**, so it is tracked as progress, not balance.
- **Modes:**
  - `election`: you are always elected, so only light tracking and a sanity alert if `HERO_SCORE_UPDATED` shows risk.
  - `hero`: target **4,000 in the period**, reward **90,000 g + ring** if reached.
- **Pace:** points needed ÷ days left, required leadership per play-hour, and P(reach) from your observed leadership/hour by method and planned playtime.
- **Value for the optimizer:** in hero mode the reward is all-or-nothing. A leadership hour is worth `90,000 g × ΔP(reach)` for that hour. When you are comfortably ahead (P > 0.95) it drops to about 0; when you are behind, it can dominate. The website shows the reward's average value (≈ 22.5 g per point) for intuition only.
- **Methods:** observed leadership per hour for each method in `leadership.source`, filled from the list you will send.

### 6.6 Time metrics

Active and AFK hours per day and week · time by activity and route · **gold per active hour by activity** · labor used vs regenerated and wasted · leadership pace · deaths per hour (a risk factor for packs and ganking) · in-game hour at activity start (`Time:GetGameTime`, a 4-real-hour cycle) and real time vs the event schedule.

---

## 7. Gold profit engine (reworked and simpler)

### 7.1 Money truth (all in copper)

- **Cash:** `Bag:GetCurrency()` + `Bank:GetCurrency()` samples, cross-checked against `X2Util.GetMyMoneyString()` (A9).
- **Transactions:** sales, purchases, mail, loot, pack sales and taxes from events, linked to segments.
- **Inventory value:** bag + bank + equipment scans × conservative price (`min(24h, 7d)` from the weekly sheet, or your own last observed price, minus the 5% AH fee). Items with low volume are discounted.
- **Net profit for a segment** = cash Δ + inventory value Δ − (labor spent × shadow price) − consumables. Unexplained cash change above max(200 g, 5% of turnover) becomes a P0 question.

### 7.2 Activity value model (learns what pays, per hour)

For each `activity × sub × context bucket` (sub = route/zone/target; context = real hour block, party size, zone state):

- Observed **gold/h**, **labor/h**, **s/labor**, **leadership/h**, **honor/h**, **death rate**, and variance.
- **Shrinkage:** estimate = (n·observed + k·prior) / (n + k), with k = 3 segment-hours. The prior is your own one-time guess (asked once per activity) or a neutral default.
- **Trust:** shown as "learning" until ≥ 3 segments and ≥ 1 h of data.
- **Ranking score per hour** = gold/h + labor/h × (shadow-price adjustment) + leadership value/h (§6.5) − risk penalty (death rate × average loss, e.g. pack loss), filtered by your **priorities** and exclusions.
- **Exploration:** at most 1 suggestion per day may be an under-sampled activity you haven't excluded, labelled "explore".

### 7.3 Labor-sink loop (replaces the Excel crafting loop)

This is the **one simple loop** for crafting and every other labor use:

1. **Inputs, all automatic:** recipes from the game catalog · proficiencies from `ACTABILITY_EXPERT_CHANGED` · prices from the weekly sheet plus your own sales · materials you already hold (inventory and bank scans, which lower the gold needed) · labor now and forecast · pack ratios (hourly snapshots).
2. **Candidates compete on one list:**
   - craft X (via `analyze.py`'s recursive coster, unchanged)
   - open coin purses
   - craft and run pack route A→B
   - gather node Y
   - farm your plot
3. **Show the top 3** by **silver per labor** *and* **silver per minute**, with:
   - a volume check (≤ 25% of 24h volume, learned per item from your actual sell-through)
   - a shopping list
   - the labor-cap context ("you'll waste 2,100 labor before tomorrow unless you spend about 4k today")
4. **One tap** "doing it" → a recommendation (§8).
5. **Measured automatically:** labor drop, items made, sales events. No fill-in cells.
6. **Learning:** realized sell price and sell-through time per item adjust that item's volume cap and price discount, and a refusal reason becomes an exclusion. This replaces `learnings.md` and the yellow cells.

The Excel ledger is **retired**. Optional one-time import of existing rows (no gate).

### 7.4 Daily plan (deterministic, then explained by the LLM)

Inputs: planned playtime today (asked or learned from your pattern), labor forecast, leadership mode and pace, schedule events (world bosses and daily events with the DST fix, game-time events), and your priorities. Output: a time-boxed plan such as "45 min packs A→B (2 packs) · burn 3.2k labor on X · raid at 21:00 for leadership", with expected gold, labor use and leadership.

---

## 8. Recommendation ledger

Every suggestion (rules, labor-sink ranker, daily plan, LLM) is a row. A suggestion that is not in the ledger is not shown.

| Field | Meaning |
|---|---|
| `rec_id` · `created_at` · `checkin_id` | |
| `source` | rule:`id` / ranker / planner / llm:`call_id` |
| `type` | labor_sink, activity_choice, pack_route, sell_timing, labor_cap_warning, leadership_pace, explore, data_quality, other |
| `text` | What you see |
| `prediction` | **Required.** Metric + value + range (e.g. silver/min 18 ± 5 for 45 min; labor waste avoided 2,100) |
| `assumptions` | Prices week, ratios, proficiencies, labor state |
| `eval_window` · `evaluator` | e.g. `segment_rate(activity, sub)` over the next session; `sales_realized(item)` over 72 h |
| `status` | proposed → accepted / rejected (reason) / ignored → executed → measured / unmeasurable / expired |
| `outcome` · `score` | Measured from segments and transactions only. Hit / partial / miss. |

Hit rates per source and type are shown on the website and fed to the LLM as one line. **Realized values are never invented**; missing data keeps the status at `executed` and queues a question.

---

## 9. Hourly check-in

### 9.1 Trigger and delivery

- Due after **60 min of active (non-AFK) play** since the last check-in or since login.
- **Deferred** in 5-min steps (max 20 min) during `pack_run`, `ganking/pvp`, `group_content` combat, or `dead`. AFK pauses the clock.
- **Delivery:**
  - desktop notification (uploader)
  - website badge
  - optionally **in-game**: the uploader writes `inbox.dat` and the addon shows a small "check-in ready" window (A27)
- You can open it, snooze it (15/30 min) or skip it for the session. Not opened within 30 min = `missed`; its questions go back to the pool and don't count against the budget.
- Leaving the world (`LEAVING_WORLD_STARTED`) triggers a short wrap-up.

### 9.2 Content and conversation

1. **Deterministic packet:**
   - last hour and session: time by activity, gold (cash, transactions, net with inventory), labor (now, to cap, wasted, forecast), leadership (points, pace, P(reach))
   - open recommendations and their status
   - next schedule events, in real and game time
2. **Questions** within the budget (§10), with quick-reply buttons.
3. **Suggestions:** 1–2 from the ranker or planner, explained by the LLM. Each is in the ledger.
4. **Ongoing conversation per check-in:** a chat thread where you add context ("guild raid at 21:00", "saving for a farmhouse", "this route got ganked twice") and ask anything. Statements of lasting value are extracted (local LLM) into `knowledge.fact` or `econ.exclusion`, and you confirm each one.
5. **Close:** a summary (local LLM). Later check-ins carry **summaries, not transcripts**.

### 9.3 LLM router

| Task | Default | Fallback |
|---|---|---|
| Phrase questions, parse answers into facts, summarize threads, extract context | Local (7–9B instruct via Ollama, JSON output) | Haiku 5.5 |
| Check-in suggestion + conversation | Sonnet 5.5 (effort low/medium) | Haiku 5.5 → local |
| Daily plan explanation | Sonnet 5.5 (Batch API when not urgent) | local |
| Weekly review (hit rates, activity value changes, leadership month) | Sonnet 5.5, high effort | Haiku 5.5 |
| Any number | **SQL and rules only** | — |

Context per check-in is about 8k tokens: about 5k cached frozen prefix (persona, rules, a **game-knowledge digest** built from §11 sources, output schema) plus about 3k volatile (packet, answers, last 3 summaries, hit-rate line, standing priorities).

---

## 10. Question-budget logic

| Scope | Cap |
|---|---|
| Per check-in | 3 (a 4th only for a P0 with ≥ 1,000 g at stake) |
| Per play-day | 8 |
| Per topic | Once per 24 h. Not re-asked within 7 days once answered, unless contradicted by data. |
| Free (doesn't count) | Your own questions, and one-tap confirmations of observed data |

**Candidates**

| Kind | When | Priority |
|---|---|---|
| `unexplained_gold` | Reconciliation gap above threshold | P0 |
| `labor_seed` | Labor model has no anchor or drifted | P1 (once) |
| `leadership_value` | Leadership not readable and none reported this session (hero mode only) | P1 |
| `classify_segment` | `unknown` > 10 min, or confidence < 0.6 for > 20 min | P1 |
| `period_dates` | Leadership period start/end unknown | P1 |
| `stale_prices` | Weekly sheet older than this Monday | P1, weekly |
| `activity_prior` | First time an activity is seen: "what do you usually make per hour doing this?" | P2, once per activity |
| `rec_feedback` | Proposed recommendation with no response after 1 check-in | P2 |
| `preference` | Priorities, risk appetite, disliked activities | P3 |

**Selection:** `value = weight(P0=8, P1=4, P2=2, P3=1) × min(1, gold_at_stake/1000) × uncertainty × freshness × 1/(1+skips)`.
- Anything the data can already answer is **auto-resolved, not asked**.
- Questions that share an answer are merged.
- Two skips suppress a question for 3 days.
- Answers become facts with a TTL.

---

## 11. Sources needed to interpret the game

| # | Source | Status / why |
|---|---|---|
| 1 ★ | **PlayerDB and RaidsDB addon folders** (copy them into this repo under `reference/addons/`, or share the folder through Remote Control) | Real `File:Write` output, `_count.dat`/`_files.dat` handling, how they read `request.dat`/`ignore.dat`, and real event arguments |
| 2 ★ | **Your list of ways to earn leadership** | Fills `leadership.source`; you said it is coming |
| 3 ★ | **Leadership period dates** and the hero rules: when the month starts and ends, whether "4,000" counts from the period start, and whether the election ranking uses the same points | Pace and P(reach) |
| 4 ★ | **Confirm larceny** = opening mob coin purses with labor (Larceny proficiency). Coin purse types and typical yields if known. | Labor-sink candidate and fingerprint |
| 5 | The **HTML link that prints in-game time** | Cross-checks `Time:GetGameTime` and the schedule |
| 6 | aa-classic.com/timers (noted: the "world bosses" and "daily events" headers run 1 h behind in winter; game-time events are correct) | Seeds `schedule_event` with `dst_correction_h` |
| 7 | **Daily reset time** (derived ≈ 04:00 UTC from your note; please confirm the exact time and the server time zone) | Day boundaries, daily-event planning |
| 8 | What `PREMIUM_LABORPOWER_CHANGED` means for you (patron/premium labor?) and whether premium changes regen or cap | Labor model |
| 9 | Pack basics: which packs you run, their craft cost and labor, typical routes, carry risk | Seeds priors; the ratios come from `Store:*` |
| 10 | Gank and PvP context: faction, the zones you hunt in, and whether stolen packs count as your profit (yes, presumably) | Fingerprint + value |
| 11 | Sample chat lines in your client language for `SELF_MONEY_CHANGED`, `SELF_LEADERSHIP_POINT_CHANGED`, `ADDED_ITEM_SELF`, combat kill lines (a screenshot or copy) | Chat parse patterns |
| 12 | Weekly AH prices CSV (still useful for prices), `items.csv` | Prices. Recipes now come from the game. |
| 13 | Your priorities and play profile: typical play hours per weekday, gold goals, risk tolerance, activities you refuse | Seeds facts so early check-ins don't have to ask |
| 14 | Game patch notes going forward | Triggers a short re-test and catalog run |

---

## 12. Claude call budget (< $10/month)

Prices per million tokens (first-party API): **Haiku 5.5** $0.10 in / $0.50 out · **Sonnet 5.5** $2 / $10, cache read $0.20 · Batch −50%. The 5-min cache helps within a check-in thread, not between hourly check-ins.

Assumption: 3 h/day × 30 days = 90 check-ins, about 3 turns each.

| Item | Per unit | Count/month | Monthly |
|---|---|---|---|
| Check-in open (Sonnet): about 8k in (5k cache write) + 600 out | ≈ $0.025 | 90 | $2.25 |
| Check-in turns (Sonnet): about 9k in, mostly cache reads, + 400 out | ≈ $0.008 | 270 | $2.16 |
| Daily plan explanation (Sonnet, Batch) | ≈ $0.02 | 30 | $0.60 |
| Weekly review (Sonnet, high effort) | ≈ $0.10 | 4 | $0.40 |
| Parsing, summaries, fact extraction (local; Haiku fallback) | ≈ $0 | ~400 | ≤ $0.20 |
| **Expected** | | | **≈ $5.6** |
| **Hard cap** | | | **$9.00** |

**Enforcement:**
- Estimate the cost before every call and refuse it if spent + estimate > cap.
- Modes:
  - `normal` below 70% of the cap
  - `conserve` at 70%: opens move to Haiku, max 2 turns per check-in, daily explanation goes local
  - `local_only` at 90%: Claude only for the weekly review
- Per-check-in ceiling $0.15, after which the thread continues on the local LLM.
- Spend is computed from the real `usage` in each response. Every call is logged.

---

## 13. Assumptions the event test must confirm

**Protocol (probe mode, about 60–90 min, spread over normal play).** Press the in-game marker before each step:

login → idle 3 min (AFK) → open bags and bank → walk and glide 300 m → change zone → craft 1 recipe → craft 1 trade pack, carry it, sell it → fish 5 min → gather 3 nodes → farm your plot → kill 5 mobs → open coin purses → list 1 AH item → wait for any AH sale → collect mail money → join a party, then a raid, become leader → leadership-earning activity (from your list) → PvP or gank if the chance comes up → die once (optional) → `/reload` → logout.

| ID | Assumption | Pass | Fail → consequence |
|---|---|---|---|
| A1 | `api.On` accepts all 206 `UI_EVENTS` + 4 under `pcall` without crashing | All return; client stable for 30 min; mode recorded per event | Register in halves to find the culprit and mark it `unsafe` |
| A2 | The 5 documented events behave as described (`UPDATE` dt in ms each frame; the other 4 fire on their trigger) | `UPDATE` dt ≈ frame time; each of the other 4 fires during its step | Use `api:DoIn` for timing; mark the others dead |
| A3 | Each `UI_EVENTS` entry ends classified | 100% classified registered/fired/dead/unsafe, with ≥ 1 sample per fired event | Extend the script |
| A4 | `api.File:Write` creates new files at `aacs/out/<name>.dat` (relative to `api.baseDir`) with arbitrary names; the write is complete on return | 200 consecutive chunks parse; 0 partial | Fixed-name ring files (`slot_000..999`) |
| A5 | `api.File:Write` output is a Lua table literal our parser handles (nesting, escapes, unicode, numbers, booleans) | Byte-exact round trip on 5 test tables (incl. non-ASCII item names) | Adjust the parser to the real format |
| A6 | `Time:GetUiMsec` is monotonic; `Time:GetLocalTime` gives wall time | Drift vs file mtime < 2 s over 1 h; note whether `GetUiMsec` resets on `/reload` | Re-anchor `ui_ms0` on each `UI_RELOADED` |
| A7 | `UPDATE` + a dt accumulator gives stable timing; `api:DoIn` works | Timer jitter ±20% | Rely on `DoIn` |
| A8 | Full capture doesn't hurt play | Handler + poller < 1 ms/frame on average, no hitch > 50 ms, no FPS drop in a crowded town for 10 min | Drop to the `lean` profile |
| A9 | `Bag:GetCurrency()` returns copper and matches the UI; `PLAYER_MONEY` fires on change | Matches after 5 transactions, to the copper; ratio to `GetMyMoneyString` consistent | Find the unit factor and log it |
| A10 | `LABORPOWER_CHANGED` carries labor (absolute or delta) | Craft and gather steps give values consistent with the in-game labor UI; regen ticks visible or modelable at 8/min | One labor seed question per session + model only |
| A11 | Leadership readable via `PLAYER_LEADERSHIP_POINT` or `SELF_LEADERSHIP_POINT_CHANGED` | Value or delta matches the UI after a leadership activity | One leadership question per session |
| A12 | Bag scan via `Bag:GetBagItemInfo(1, i)` gives item ID + count; `ADDED_ITEM`/`REMOVED_ITEM` carry the item | Crafted, gathered and looted items appear within 5 s | Rescan-only, lower confidence |
| A13 | Bank contents readable via `Bank:GetLinkText(slot)` (bank window closed vs open) | Parsed links match the bank UI | Bank valued only when the bank window was opened |
| A14 | `AUCTION_BOUGHT_BY_SOMEONE` identifies your sold item (item, qty, price) | Fires on a real sale with parseable arguments; gold after mail collection matches price × 0.95 | Infer from mail money + listing records |
| A15 | `SELL_SPECIALTY` + `BACKPACK` equipment slot identify pack runs and payouts | Pack step recorded end to end | Pack runs from gold + position only |
| A16 | `Store:*` ratio getters return the pack price table | Values consistent with the trade-outlet UI | Use manual route priors |
| A17 | Position and zone (`UnitWorldPosition`, `GetCurrentZoneGroup`, `GetPlayerSextants`) | Walk and zone steps visible | AFK and travel from events only |
| A18 | `LEAVING_WORLD_STARTED` fires before logout with time to write | Final chunk has `closed="logout"` | Accept ≤ 60 s loss; rotate every 30 s |
| A19 | Handlers survive `/reload` (or are re-registered by addon reload) and `UI_RELOADED` fires | Events continue after reload | Re-register in boot |
| A20 | Data volume ≤ 20 MB/h after sampling; no event > 2 records/s | Measured | Tighten the sampler |
| A21 | A handler error doesn't break other handlers or print to chat | Forced error test | Wrap everything; `Log` off |
| A22 | `pairs(api)` introspection works; `Quest`/`ItemEnchant`/`Map`/`Zone`/`Craft` exist at runtime | Manifest lists them | Drop those getters |
| A23 | Combat target type (NPC vs player) and faction readable via `UnitInfo`/`GetFactionName` | Mob and player targets separable | Ganking only from honor + chat lines |
| A24 | Crime and larceny visible (`CRIME_REPORTED`, `GetCrimeInfo`, coin purse items, Larceny proficiency) | Coin-purse step recorded with labor and gold | Larceny from item removal + labor only |
| A25 | Recipe "Coin" = copper | A craft with a fee shows gold Δ = fee in copper | Fix the unit factor |
| A26 | Catalog run: `Craft:GetCraftTypesByName` enumerates all recipes without hitches when throttled | Recipe count is the same order as `recipes.csv`; no hitch > 50 ms | Keep `recipes.csv` |
| A27 | `api.File:Read` sees `inbox.dat` changes made while the game runs (as `request.dat`/`ignore.dat` do for PlayerDBSync) | New `msg_id` shown in game within 35 s | Desktop notification only |
| A28 | `Time:GetGameTime` returns in-game time consistent with the 4-hour cycle and the HTML game-time link | Matches within 1 game minute | Compute from the anchor + cycle |
| A29 | Hero events carry the period dates and score or rank | Dates and score readable | Ask once per period |
| A30 | The ToS allows a read-only, file-writing addon of this scope (as PlayerDB/RaidsDB already are) | Your confirmation | Reduce the scope |

---

## 14. Build stages with pass/fail criteria

| Stage | Deliverable | Pass | Fail action |
|---|---|---|---|
| **S0 Sources** | §11 ★ items | `api.lua` ✓; example addons in `reference/addons/`; leadership list + period rules; larceny confirmed; A30 confirmed | S1 can start without the leadership list; S6 can't finish without it |
| **S1 Probe v0.1** (introspection + 5 documented events + `File:Write` test) | First `.dat` files | Loads with 0 Lua errors over 3 logins; manifest written; A4, A5, A6, A22 pass | Adjust the format (ring files, parser) |
| **S2 Event test** (probe, all events + getters) | `catalog.event_test` | A1–A29 each with a verdict and evidence. **Go/no-go minimum: A4, A5, A6/A7, A9, and A10 or a labor seed workflow.** | If gold (A9) fails: stop and rethink, since the core value depends on it |
| **S3 Capture v1.0** | Daily addon | 3 sessions ≥ 1 h; 0 crashes; ≤ 60 s lost per session; A8 and A20 budgets met | `lean` profile |
| **S4 Uploader** | Linux binary + service | Kill/restart 10× during a backlog: 0 duplicates, 0 losses; 24 h backlog catches up in < 5 min; cleanup never runs while the game runs; inbox writes are atomic | Fix |
| **S5 DB + parser** | `raw` → `core` | Reparse of all chunks is deterministic (equal row hashes twice); 1-month queries < 200 ms; parse failures 0% on S3 data | Fix the parser or time zones |
| **S6 Rules + labor + leadership** | §6 | On the labeled event-test session: ≥ 85% of seconds correct for verified activities; `unknown` < 25% over a week; gold matches the UI to the copper; labor model within ±2% of the UI at 3 spot checks; leadership pace shown | Tune rules; more labels |
| **S7 Website + labor-sink loop** | Dashboard, activities, sinks, leadership | Labor-sink top 3 reproduces `analyze.py` numbers for crafts; pack and coin-purse options appear once data exists; labor-waste forecast visible; Excel optional | Fix the ranker |
| **S8 Check-in** | Scheduler, packet, questions, chat, router, budget | 1 week: on-time ±5 min of the due play-hour; 0 interruptions during pack runs or PvP before the 20-min cap; question caps never exceeded; median time per check-in < 2 min; monthly projection < $10 from real usage; in-game inbox works (if A27) | Tune deferral or budgets |
| **S9 Learning loop** | Ledger, evaluators, activity model, classifier | 100% of shown recommendations in the ledger with a prediction; ≥ 80% resolved within their window; activity gold/h shown with n and confidence; classifier enabled only where it beats the rules on held-out data; 0 invented outcomes (audit) | Fix evaluators; keep the rules |

Dependencies: S0 → S1 → S2 is a strict gate. S4 and S5 run alongside S3. S6 needs S2 + S5. S7 needs S6. S8 needs S6 + S7. S9 needs S8.

---

## 15. Out of scope for the MVP

Screenshots/OCR (possible, as PlayerDBSync does, but not cost-efficient now) · multi-user hosting · live AH price scraping · LLM tool access to the DB · automated route optimizer beyond ranking observed routes · voice.
