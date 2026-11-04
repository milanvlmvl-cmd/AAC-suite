# AAC-suite — MVP Plan (ArcheAge Classic assistant)

> Status: **plan only, no code.** Scope: gold profit, time tracking and leadership tracking.
> Date: 2026-11-04

---

## 0. Input status (read first)

| Input | Status | Effect on this plan |
|---|---|---|
| `/mnt/user-data/uploads/1793764470457_api.lua` | **Not in the session.** The uploads folder is empty. | Every API function name and every `UI_EVENTS` entry below is a **placeholder to be confirmed**. The plan is built so nothing depends on a specific event name until the event test (Stage 2) checks it. |
| `/mnt/skills/plugins/aa-classic-profit/scripts/analyze.py` | Path missing. The same file was read from the installed `aa-classic-profit` skill. | Reused as the planner (§7.4). |
| `/mnt/skills/plugins/aa-classic-profit/scripts/ledger.py` | Same as above. | Its workbook schema becomes Postgres tables (§5.5). |

**Ground rule from the brief:** every `UI_EVENTS` entry is **unverified**. The comment on `api.On` names only five events, called **E1–E5** below until `api.lua` is supplied. Even E1–E5 are marked *documented-unverified*, not *verified*. An event is **verified** only once the event test has seen it fire with a known argument shape during a scripted action.

---

## 1. Architecture

```
 ArcheAge Classic client
   └─ Lua addon "aacs_probe" / "aacs_capture"
        writes chunk files ──► ~/Documents/AAClassic/Addon/aacs/out/*.jsonl
                                       │
 Go uploader (Windows tray app / service)
   watch → validate footer → hash → INSERT raw → move to archive/
                                       │
 Postgres  raw.*  (immutable)  ──►  rules engine (Python worker)
                                     ├─ normalize → core.* (sessions, samples, segments)
                                     ├─ planner (analyze.py) → econ.plan*
                                     ├─ question generator → assistant.question
                                     └─ check-in scheduler → assistant.checkin
                                       │
 Website (FastAPI + htmx, served locally)
   dashboard · ledger · check-in chat · event catalog · budget
                                       │
 LLM router ── local LLM (Ollama/LM Studio) for cheap tasks
            └─ Claude API (Sonnet 5.5 / Haiku 5.5) for suggestions, with a hard $ cap
```

**Design principles**

1. **Raw is immutable and everything else can be rebuilt.** The uploader never interprets data. Rules can change, and derived tables are rebuilt from `raw.*`. This lets the addon capture "too much" without regret.
2. **Run everything locally for the MVP.** Postgres, the worker and the website run under `docker compose` on the gaming PC. The uploader is a native Windows binary. The local LLM is reachable without tunnels. Remote hosting is a later step.
3. **Few languages.** Go only for the uploader, which must be one standalone binary on Windows. Python for the rules engine and web, because `analyze.py` and `ledger.py` already exist in Python and can be reused directly.
4. **Read-only addon.** The addon observes and never acts: no automation, no input simulation, no calls to anything that changes game state (see the deny-list in §2.4). This is both a safety rule and a game terms-of-service rule.
5. **Deterministic first, LLM last.** Numbers, activity classification, question choice and scheduling are rules. The LLM only phrases things, interprets free text and suggests, and every suggestion goes into the recommendation ledger.

---

## 2. Probe addon spec

There are two builds from one codebase:

| Build | Purpose | Subscriptions | Polling |
|---|---|---|---|
| `aacs_probe` v0.x | Discovery and the event test (Stages 1–2) | All `UI_EVENTS`, wrapped in `pcall` | API introspection and the allow-listed getters |
| `aacs_capture` v1.x | Daily use (Stage 3+) | Every event that is not marked `unsafe` in the catalog (it still captures widely) | Tiered getters |

### 2.1 Modules

| Module | Responsibility |
|---|---|
| `boot` | Loads the config, makes the install ID and session key, writes the header, and catches all errors. |
| `introspect` | Walks the `api` table (and any other global tables the probe finds) to depth 4 with `pairs`. Records path, Lua type and arity if it can be known. Never calls anything. Output: `M` (manifest) records. |
| `subscribe` | For each name in `UI_EVENTS` plus E1–E5: `pcall(api.On, name, handler(name))`. Records success, error text, or "accepted silently". Output: `R` (registration) records. |
| `handler` | A generic varargs handler. It records event name, `select('#', ...)` argument count, and the serialized arguments, and keeps counters per event. |
| `poller` | Driven by a timer or frame event (to be confirmed, A7). Calls allow-listed getters at tiered rates and emits `S` records **only when a value changes**, plus a full keyframe every 5 min. |
| `serializer` | A small JSON encoder: depth ≤ 4, strings ≤ 512 chars, ≤ 64 keys per table, cycle-safe, NaN/inf become `null`, functions/userdata become `"<type>"`. |
| `sampler` | Per-event token bucket. **Counts are always exact.** Payloads are kept in full for the first 200 per event per session, then 1 in N (N adapts to keep the event under 2 records/s). |
| `writer` | Buffers records and rotates chunks (§3.2). One whole-file write per chunk. |
| `selfmon` | Records time spent in handlers and the poller (if a clock exists), dropped records, getters disabled after errors, and buffer high-water mark. Output: `K` (health) records each rotation. |
| `marker` | If a slash command or chat hook exists (unverified), `/aacs mark <text>` writes a `T` (marker) record for the event test. Otherwise the website's marker button takes over (§9.2). |

### 2.2 What gets captured (deliberately wide)

**Events:** every `UI_EVENTS` entry, plus E1–E5, plus any event-like strings introspection finds that are not in `UI_EVENTS` (logged as `candidate`, subscribed in the probe only).

**Getters, polled in tiers** (names to be confirmed from the `api.lua` manifest):

| Tier | Rate | Intended data (if a getter exists) |
|---|---|---|
| fast | 5 s | gold/money, labor (current/max), combat state, position (x, y, z), zone, target, HP/MP, mounted/gliding state |
| medium | 30 s | party/raid roster, leader flag, buffs/debuffs, cooldowns, bag-slot hash, honor/vocation/leadership and other currencies, AFK/idle flag |
| slow | 5 min (and on login) | full inventory and bank (item ID, count, grade), equipment, proficiencies/skills, character name, server, level, faction, guild, house/farm data if exposed |
| once | login | client/game version, locale, screen/UI scale, addon list |

**Chat:** keep the metadata (channel, sender hash, length) for every message. Keep the text **only** for system, loot, trade/AH, mail and your own messages. Other players' text is personal data and stays off by default (a config flag can change this).

### 2.3 Getter allow-list rules (how "capture everything" stays safe)

- Only zero-argument functions whose names match `^(Get|Is|Has|Can|Count|Find|Query)` qualify, plus explicit additions after review.
- Every call is wrapped in `pcall`. Three errors in one session disable that getter for the session and log it as `getter_disabled`.
- A getter whose single call takes more than 2 ms is moved to the slow tier.
- The allow-list ships as data in the addon config, generated from the probe manifest and the Stage 2 results. No getter is called before it has been seen in the manifest.

### 2.4 Hard deny-list (never called by either build)

Names containing `Set|Use|Send|Buy|Sell|Bid|Craft|Make|Move|Cast|Request|Delete|Destroy|Drop|Equip|Unequip|Accept|Decline|Invite|Kick|Post|Mail|Trade|Open|Close|Click|Press|Toggle|Start|Stop|Reload|Logout|Quit`, and anything not on the allow-list.

### 2.5 Config (per install, in the addon folder)

`install_id`, `capture_level` (`probe|full|lean`), the tier rates, the sampler thresholds, the chat policy, and the allow-list/deny-list versions. The config's version is written into every chunk header.

---

## 3. Chunk format and versioning

### 3.1 File layout

```
~/Documents/AAClassic/Addon/aacs/out/
  aacs_<fmtMajor>_<install8>_<sessKey>_<seq6>.jsonl     ← written once, never modified
~/Documents/AAClassic/Addon/aacs/archive/YYYY-MM-DD/     ← moved here by the uploader after a successful insert
~/Documents/AAClassic/Addon/aacs/quarantine/              ← bad footer, unknown major version, parse error
```

- `sessKey` is a login timestamp if the addon has a clock (A6). Otherwise it is a counter kept in saved settings, plus random hex.
- `seq` is a per-session counter starting at 0. A gap in it means data was lost, and the uploader reports it.

### 3.2 Rotation

A chunk is closed at whichever comes first: **60 s**, **500 records**, or **256 KB**, or on a logout/reload/zone event if one is verified (A18). Worst-case loss on a crash is one interval (≤ 60 s).

### 3.3 Record types (JSON Lines, UTF-8, LF)

| `t` | Name | Key fields |
|---|---|---|
| `H` | header (line 1, always) | `fmt` "1.0", `addon` semver, `build` (probe/capture), `install`, `sess`, `seq`, `clk` {src, t0_wall, t0_mono}, `cfg_ver`, `events_hash` (hash of the subscribed set), `allow_ver`, `char` (if known), `game_ver` (if known) |
| `M` | manifest | `path`, `ltype`, `arity?`, `src` (introspect/ui_events/comment) |
| `R` | registration result | `ev`, `ok`, `err?`, `mode` (accepted/error/silent) |
| `E` | event | `i` (index in chunk), `ms` (since session start), `ev`, `n` (argument count), `a` (serialized arguments), `s` (sampling weight; 1 = not sampled) |
| `C` | counters | per-event exact counts since the last chunk, including suppressed payloads |
| `S` | snapshot | `ms`, `k` (getter path), `v` (value), `kf` (true = keyframe) |
| `T` | marker | `ms`, `text`, `src` (addon/website) |
| `K` | health | handler time, poller time, dropped records, disabled getters, buffer peak |
| `X` | error | `ms`, `where`, `msg` (truncated) |
| `F` | footer (last line, always) | `n` (record count excluding H/F), `bytes` (byte length of lines 2..n+1), `closed` (rotate/logout/reload/size/count), `hash?` (FNV-1a 32 if bit operations are available) |

**A chunk is valid only if** it has an `H` first line and an `F` last line, and the footer's `n`/`bytes` match. The uploader ignores files younger than 5 s, or with an mtime that changed in the last 2 s, so it never reads a half-written file.

### 3.4 Versioning rules

| Thing | Scheme | Compatibility rule |
|---|---|---|
| Chunk format `fmt` | MAJOR.MINOR | **Minor**: new record types or fields only. Older ingest stores unknown fields raw. **Major**: breaking change. The uploader quarantines unknown majors and the website shows a warning. |
| Addon `addon` | semver | Free to change. Recorded per chunk so data quality can be traced to a build. |
| Subscribed set `events_hash` | hash of the sorted event names | Separates "event never fired" from "event wasn't subscribed". |
| Allow-list `allow_ver` | integer | Same purpose, for getters. |
| Rules `rule_id@version` | per rule | Stored on every derived row, so rule changes are auditable and rebuilt deliberately. |
| DB schema | numbered migrations | Raw tables are append-only. Derived tables may be dropped and rebuilt. |

---

## 4. Go uploader

| Concern | Behavior |
|---|---|
| Discovery | fsnotify on `out/`, plus a 10 s polling fallback (OneDrive-redirected Documents folders sometimes drop notifications). Finds `Documents` through the Windows known-folder API, not a hard-coded path. |
| Validation | Header and footer present, `n`/`bytes` match, `fmt` major supported. Any failure goes to `quarantine/` with a `.reason` file. |
| Idempotency | SHA-256 of the file is the idempotency key. Insert into `raw.chunk` with `ON CONFLICT (sha256) DO NOTHING`, plus a unique key on (install, sess, seq). One transaction per chunk inserts the chunk and its records. The file moves to `archive/` only after commit. |
| Crash safety | A kill at any point leaves the file in `out/` or already committed. Re-processing is a no-op. |
| Offline | If Postgres is down, back off (2 s → 5 min). Files simply stay in `out/`. |
| Retention | Keep archives 14 days (configurable). Keep quarantine until the user clears it. |
| Own stream | The uploader writes its own records too: uploader start/stop, gaps found, and **website markers** (§9.2). These go into `raw.chunk` with `build='uploader'`. |
| Notification bridge | Polls `assistant.checkin` for due check-ins and shows a Windows toast that opens the website. This works even when the game is full-screen. |
| DB rights | Uses the `aacs_ingest` role: INSERT on `raw.*` and SELECT on `assistant.checkin` only. |
| Observability | Local log file. `/healthz` on localhost reports last upload, backlog and quarantine count. |

---

## 5. Database schema (Postgres 16)

Names and columns only; types are indicative.

### 5.1 `raw` (append-only)

| Table | Columns |
|---|---|
| `raw.chunk` | `chunk_id` bigserial PK · `install_id` text · `sess_key` text · `seq` int · `build` text · `fmt` text · `addon_ver` text · `cfg_ver` int · `events_hash` text · `allow_ver` int · `sha256` bytea UNIQUE · `n_records` int · `closed_reason` text · `file_mtime` timestamptz · `received_at` timestamptz · `header` jsonb · UNIQUE(`install_id`,`sess_key`,`seq`,`build`) |
| `raw.record` | `chunk_id` FK · `idx` int · `t` char(1) · `ms` bigint · `ts_est` timestamptz (estimated wall time) · `ev` text NULL · `k` text NULL · `payload` jsonb · PK(`chunk_id`,`idx`) · **partitioned by month on `ts_est`** · indexes (`ev`,`ts_est`), (`k`,`ts_est`) |
| `raw.quarantine_log` | `file_name`, `reason`, `seen_at`, `header` jsonb NULL |

### 5.2 `catalog` (what the game exposes and what is verified)

| Table | Columns |
|---|---|
| `catalog.event` | `name` PK · `source` {comment_E1_5, ui_events, introspect_candidate} · **`status`** {unverified, registered, register_error, fired, verified, dead, unsafe} · `first_registered_at` · `first_fired_at` · `fire_count` · `rate_p95_per_min` · `arg_shape` jsonb (inferred types per position) · `sample_payloads` jsonb (≤ 5) · `verified_by` (event-test ID + marker) · `notes` |
| `catalog.api_fn` | `path` PK · `ltype` · `status` {listed, allowlisted, called_ok, errors, slow, denied} · `sample_value` jsonb · `avg_call_ms` · `notes` |
| `catalog.event_test` | `test_id` PK · `addon_ver` · `started_at` · `script_ver` · `results` jsonb (assumption ID → pass/fail/unknown + evidence) |
| `catalog.semantic_map` | `concept` (e.g. `gold`, `labor`, `leadership`, `craft_done`, `ah_sale`) · `source_kind` {event, getter, derived, manual} · `source_ref` · `transform` · `verified` bool · `since_addon_ver` — **the only bridge between game data and rules**. Rules depend on concepts, never directly on event names. |

### 5.3 `core` (derived and rebuildable)

| Table | Columns |
|---|---|
| `core.character` | `char_id` PK · `name` · `server` · `faction` · `install_id` |
| `core.play_session` | `session_id` PK · `char_id` · `started_at` · `ended_at` · `end_reason` {logout, gap, crash} · `active_s` · `afk_s` · `chunk_from`/`chunk_to` · `seq_gaps` int |
| `core.sample` | `char_id` · `ts` · `concept` (gold, labor, labor_max, leadership, honor, …) · `value` numeric · `src_record` (chunk_id, idx) · PK(`char_id`,`concept`,`ts`) |
| `core.inventory_snapshot` | `char_id` · `ts` · `items` jsonb (item_id → count) · `value_gold_est` numeric (at the price basis of §7.1) |
| `core.activity_segment` | `seg_id` PK · `session_id` · `start_ts` · `end_ts` · `activity` · `confidence` 0–1 · `rule_id` · `rule_ver` · `evidence` jsonb · `label_source` {rule, user, user_confirmed_llm} · `gold_delta` · `labor_delta` · `leadership_delta` |
| `core.group_state` | `char_id` · `ts` · `in_party` · `in_raid` · `is_leader` · `member_count` |
| `core.derive_run` | `run_id` · `started_at` · `rules_hash` · `from_ts`/`to_ts` · `status` (for audit and deterministic rebuild checks) |

### 5.4 `knowledge` (game data the user supplies, §11)

| Table | Columns |
|---|---|
| `knowledge.item` | `item_id` PK · `name` · `norm_name` · `tradeable` |
| `knowledge.recipe` / `recipe_material` | Taken from `recipes.csv`: `craft_id`, `output_item`, `output_amount`, `req_labor`; materials (`name`, `amount`). "Coin" is the craft fee. |
| `knowledge.price_week` | `week_of` (Monday) · `item_id` · `p24`/`v24`/`p7`/`v7`/`p30`/`v30` · `source_file` · `last_updated_at` |
| `knowledge.harvest_zone` | Taken from the plants-by-zone CSV |
| `knowledge.fact` | `key` · `value` jsonb · `source` {user_answer, doc, observed} · `valid_until` · `confidence` (e.g. labor regen rates, leadership rules, reset times) |

### 5.5 `econ` (the Excel ledger becomes tables)

| Table | Columns (mirrors `ledger.py`) |
|---|---|
| `econ.proficiency` | `char_id`, `skill`, `value`, `as_of`, `source` |
| `econ.recipe_requirement` | `recipe`, `skill`, `required`, `learned_at` |
| `econ.exclusion` | `recipe`, `reason`, `date`, `until` NULL |
| `econ.learning` | `date`, `text`, `tags` (replaces `learnings.md`) |
| `econ.plan` | `plan_id` · `plan_date` · `char_id` · `inputs` jsonb (labor, gold, volume_cap, min_volume, labor_value) · `prices_week` · `analyzer_ver` · `projected_profit` |
| `econ.plan_line` | `plan_id` · `recipe` · `batches` · `units_listed` · `proj_sell_price` · `proj_mat_cost` · `proj_labor` · `proj_profit` · `spl` · fill-ins: `crafted`, `date_crafted`, `date_sold`, `actual_price`, `qty_sold`, `times_listed`, `actual_labor`, `notes` · `fill_source` per field {user, observed, observed_confirmed} |
| `econ.sale` | `sale_id` · `char_id` · `ts` · `item_id` · `qty` · `unit_price` · `fee` · `source` {observed_event, user} · `plan_line_id` NULL |
| `econ.purchase` | Same shape. Lets realized profit use the **actual** material cost rather than the projected cost (an improvement over `ledger.py`). |
| `econ.gathering_trip` | `date`, `material`, `zone`, `amount`, `labor`, `minutes`, `gold`, `notes`, `segment_id` NULL |
| `econ.ledger_day` (view) | `date`, `projected`, `realized`, `delta`, `cumulative`, `notes`, **`realized_status`** {unreported, partial, complete}. Never invents realized numbers. |

### 5.6 `assistant`

| Table | Columns |
|---|---|
| `assistant.checkin` | `checkin_id` · `session_id` · `due_at` · `notified_at` · `opened_at` · `closed_at` · `status` {due, deferred, notified, open, closed, skipped, missed} · `defer_reason` · `packet` jsonb (the deterministic summary) · `summary` text (written at close) |
| `assistant.message` | `msg_id` · `checkin_id` · `role` {system_note, assistant, user} · `content` · `llm_call_id` NULL · `ts` |
| `assistant.question` | `q_id` · `topic_key` (dedupe key) · `kind` {ledger_fillin, classify_segment, fact, preference, data_gap} · `priority` P0–P3 · `value_score` · `gold_at_stake` · `status` {candidate, queued, asked, answered, skipped, expired, suppressed, auto_resolved} · `asked_in` checkin · `answer` jsonb · `creates_fact` key NULL · `skip_count` · `cooldown_until` · `created_by_rule` |
| `assistant.recommendation` | See §8 |
| `assistant.rec_event` | `rec_id` · `ts` · `from_status` → `to_status` · `actor` {system, user, llm} · `note` |
| `assistant.llm_call` | `call_id` · `ts` · `purpose` {checkin_open, checkin_turn, parse_answer, daily_plan, weekly_review, classify_help} · `provider` {anthropic, local} · `model` · `in_tokens` · `cache_read` · `cache_write` · `out_tokens` · `cost_usd` · `checkin_id` NULL · `degraded` bool |
| `assistant.budget_month` | `month` · `cap_usd` (9.00) · `spent_usd` · `projected_usd` · `mode` {normal, conserve, local_only} |

---

## 6. Activity rules (time tracking)

### 6.1 Taxonomy (MVP)

`crafting`, `gathering` (wild harvest/mining/logging), `farming` (plant/harvest your own land), `trade_run` (packs), `fishing`, `combat_pve`, `combat_pvp`, `group_content` (party/raid activity, the leadership basis), `market` (AH/mail/vendor), `travel`, `idle_social` (in town, chatting), `afk`, `unknown`.

Every second of a play session gets **exactly one** activity. `unknown` is allowed, and its share is the main data-quality KPI.

### 6.2 Rule definition (stored as data, versioned)

| Field | Meaning |
|---|---|
| `rule_id`, `version` | e.g. `craft.labor_drop@3` |
| `requires` | List of `catalog.semantic_map` concepts. **The rule is inactive until every required concept is `verified`.** |
| `window` | Sliding window (e.g. 30 s) |
| `when` | A declarative condition over concepts (e.g. `labor_delta < 0 AND inventory_gain(crafted_output)`) |
| `emits` | Activity, confidence, and the evidence fields to keep |
| `precedence` | Integer that settles overlaps |
| `min_duration` | Segments shorter than this merge into neighbors |

### 6.3 Starting rule set (the concepts each rule needs are what the event test must confirm)

| Rule | Needs | Logic (sketch) | Conf. |
|---|---|---|---|
| `session.bounds` | any record | A session starts at the first chunk. It ends at a logout record **or** after a > 10 min gap in records. | 1.0 |
| `afk.no_change` | position, combat_state, any input-ish events | No position change, no combat, no non-periodic events for ≥ 5 min. The segment is backdated to the last activity. | 0.9 |
| `craft.labor_drop` | labor, inventory/craft event | Labor drops in steps matching `req_labor` (after proficiency discount) and an output item appears | 0.9 |
| `craft.event` | craft_done (if one exists) | A direct event | 1.0 |
| `gather.labor_drop` | labor, inventory, position | Small labor drops plus gains of raw materials found in `harvest_zone` or in no recipe output | 0.75 |
| `farm.own_land` | labor, position, house/farm data | Labor spent within the radius of a known plot | 0.7 |
| `trade_run.pack` | backpack slot/buff, position | Pack equipped plus movement, ending at a trade outlet | 0.8 |
| `fish.*` | buffs/skills, inventory | Fish items gained, stationary on water | 0.7 |
| `combat.*` | combat_state, target, faction | In combat. PvP if the target is a player of the hostile faction. | 0.85 |
| `group.content` | group_state | In a raid or party with ≥ N members for more than 50% of the window | 0.9 |
| `market.ah_mail` | AH/mail open events or gold changes without labor | Window open, or a sale/purchase observed | 0.9 |
| `travel.move` | position | Distance > threshold and nothing above applies | 0.6 |
| fallback | — | `unknown`, which becomes a question candidate if > 10 min (§7.2) | — |

**Precedence:** explicit event > `afk` > `group_content` (it overlays other activities: a raid while gathering counts as group_content with a secondary tag) > `crafting` > `trade_run` > `gathering`/`farming`/`fishing` > `combat` > `market` > `travel` > `idle_social` > `unknown`.

**User labels win.** A user label for a segment overrides the rule, and the pair (rule output, user label) is stored as a training example for tuning thresholds.

### 6.4 Derived metrics

- **Time:** active hours per day and week, per activity, AFK share, longest session, labor-capped time.
- **Labor efficiency:** labor used vs regenerated. The **labor cap waste** alert fires when labor stays at its maximum for longer than X min, since that labor is lost value. This needs the labor regen facts from §11.
- **Gold:** cash Δ per session and segment (gold samples), **silver per active hour by activity**, and net-worth Δ (cash plus inventory valued at the conservative sell price).
- **Leadership:** leadership samples give Δ per segment and **leadership per hour** of group_content. If the leader flag can be read, also leader time vs member time. If leadership cannot be read (A11 fails), the value is asked for once per session through the question budget, and Δ is spread over that session's group_content time (marked `estimated`).

---

## 7. Gold profit engine

### 7.1 Price basis (kept from `analyze.py`)

Sell price = `min(24h, 7d)`. Buy price = 24h, falling back to 7d, then 30d. AH fee is 5%. Outputs need 24h volume ≥ 20, and a plan may list at most 25% of an item's 24h volume.

### 7.2 Three numbers, kept apart

1. **Projected** (plan) comes from `econ.plan`.
2. **Realized** (ledger) comes from `econ.sale` minus actual `econ.purchase` minus gathering gold. Observed sales pre-fill the plan-line fill-ins as `observed`, and the user confirms with one click, which replaces questions.
3. **Cash Δ** (wallet) comes from gold samples. Reconciliation: cash Δ − (realized − unsold inventory change) = **unexplained gold**. Above a threshold this becomes a P0 question ("+3,200 g unexplained between 21:10 and 21:40, what happened?").

### 7.3 Using observed data to remove manual entry

| Ledger field | Observed from (if verified) |
|---|---|
| Crafted?, Date Crafted | craft concept, or `craft.labor_drop` segments |
| Actual Craft Labor | labor Δ during the craft segment (captures the proficiency discount) |
| Date Sold, Qty Sold, Actual Price | AH sale or mail events |
| Times Listed | AH listing events |
| Gathering trips | `gathering` segments: labor, minutes, items gained |

### 7.4 Planner

`analyze.py` runs as a worker job (on demand and nightly after a new prices sheet). Inputs come from the DB rather than CSV and JSON files, through a thin adapter, so the analyzer itself stays unchanged in the MVP. Its known approximations carry over and are flagged in the UI: per-unit sub-craft labor (round batches up), one recipe variant per output, and the `--labor-value` opportunity cost. **The unit of `COIN_UNIT_GOLD` (copper) is still an assumption** (A25), and the gold samples can check it.

Staleness check as in the skill: a prices sheet older than this week's Monday gives a banner and a P1 question ("export this week's sheet?").

---

## 8. Recommendation ledger

Every suggestion, whether from rules, the planner or the LLM, is a row. A suggestion that is not in the ledger is not shown to the user.

| Field | Meaning |
|---|---|
| `rec_id`, `created_at`, `checkin_id` NULL | |
| `source` | rule:`<id>` / planner:`<plan_id>` / llm:`<call_id>` |
| `type` | craft_plan, sell_timing, labor_use (cap waste), activity_switch, leadership_opportunity, data_quality, other |
| `text` | What the user sees |
| `prediction` jsonb | **Required.** Measurable: metric (gold, s/l, silver/hour, leadership/hour, labor saved), value, range |
| `assumptions` jsonb | Prices week, volume, proficiency facts used |
| `eval_window` | e.g. 48 h for craft/sell, end of the next session for activity_switch |
| `evaluator` | Name of the deterministic function that measures the outcome (e.g. `plan_line_realized`, `segment_rate_compare`) |
| `status` | proposed → accepted / rejected (reason) / ignored → executed → measured / unmeasurable / expired |
| `outcome` jsonb | Measured value, delta vs prediction, data-completeness flag |
| `score` | Hit (within the range) / partial / miss |

**Rules**

- LLM suggestions use structured output, so each one arrives with a `prediction`. A suggestion with no measurable prediction is stored as `type=other`, `status=unmeasurable`, and shown with a "not trackable" tag.
- Rejections ask for a one-tap reason (too risky / no proficiency / no mats / don't like). Reasons feed `econ.exclusion`, `econ.recipe_requirement` and `econ.learning`, the same adaptive loop as the skill.
- **Realized outcomes are never invented.** If the data is missing, the status stays `executed` and a P0/P1 question is queued.
- Hit rate by source and type appears on the website and, compactly, in the LLM's context ("your craft_plan recs: 7/10 hit; sell_timing 2/6"), so the assistant learns to calibrate.

---

## 9. Hourly check-in

### 9.1 Trigger

- **Clock = play time.** Due after 60 min of **active, non-AFK** time in the current session since the last check-in (or since login).
- **Deferral:** if the current segment is `group_content`, `combat_pvp` or `trade_run`, defer in 5-min steps up to 20 min, then notify anyway. AFK pauses the clock.
- **Notification:** a toast from the uploader plus a badge on the website tab. The user can open it, snooze it (15/30 min), or skip it for this session.
- **Missed:** not opened within 30 min becomes `missed`. Its questions return to the pool and it doesn't count against the question budget.
- Logging out with an open check-in runs a short end-of-session wrap-up (same packet, no extra questions beyond the budget).

### 9.2 Check-in content (in order)

1. **Deterministic packet** (no LLM): last hour and session so far, broken down into time by activity, gold (cash Δ, realized, unexplained), labor (used, regen, cap-waste minutes), leadership Δ, and the status of open recommendations.
2. **Questions:** up to the budget (§10), each with quick-reply buttons where possible.
3. **Suggestion:** one or two LLM recommendations based on the packet and the answers. Each is written to the ledger.
4. **Open conversation:** the check-in is a **chat thread**. The user can keep talking, give context ("I'm saving for a farmhouse", "guild raid at 21:00"), and ask questions. Messages go to `assistant.message`.
5. **Close:** at close, or after 30 min of inactivity, a summary (2–5 lines, local LLM) is stored. **Later check-ins carry earlier summaries, not full transcripts**, which keeps tokens flat.

**Event-test helper:** the same website has a **"Marker"** button. The uploader writes `T` records with the click time, so the user can say "now crafting" even if the addon cannot read slash commands.

### 9.3 LLM router

| Task | Default | Fallback |
|---|---|---|
| Phrase a question, parse a free-text answer into structured data, summarize a check-in | **Local LLM** (7–9B instruct model through Ollama/LM Studio, structured JSON output) | Haiku 5.5 |
| Check-in suggestion and conversation turns | **Sonnet 5.5** (effort `low`/`medium`) | Haiku 5.5, then local |
| Daily plan narrative (planner numbers come from `analyze.py`; the LLM only explains and flags risks) | Sonnet 5.5 | Local |
| Weekly review (recommendation hit rates, trends, learnings) | Sonnet 5.5, `high` effort | Haiku 5.5 |
| Anything numeric | **Never the LLM.** Numbers come from SQL or the planner and are passed in. | — |

**Context per check-in (budget about 8k input tokens):**
- Frozen, cached prefix (about 5k): system prompt, assistant persona, game-knowledge digest (§11), rules about predictions and the ledger, output schema.
- Volatile (about 3k): packet, answers, last 3 check-in summaries, recommendation hit-rate line, the user's standing goals and preferences (`knowledge.fact`).

---

## 10. Question-budget logic

Questions are the scarcest resource, because every question interrupts play.

### 10.1 Budgets (hard caps)

| Scope | Cap |
|---|---|
| Per check-in | **3** (P0 can take a 4th slot only if gold at stake ≥ 1,000 g) |
| Per play-day | **8** |
| Per topic (`topic_key`) | One ask per 24 h. Never re-asked within 7 days once answered, unless observed data contradicts the answer. |
| User-initiated questions and quick confirms of observed data | **Free.** They don't count. |

### 10.2 Candidate generation (rules engine)

| Kind | Generated when | Priority |
|---|---|---|
| `ledger_fillin` | A plan line is past its sell window with no observed sale | P0 |
| `unexplained_gold` | Reconciliation gap > max(200 g, 5% of session turnover) | P0 |
| `classify_segment` | An `unknown` segment > 10 min, or a confidence < 0.6 segment > 20 min | P1 |
| `fact` | A rule or the planner needs a missing or expired fact (proficiency, leadership value if not readable, labor regen) | P1 |
| `stale_prices` | The prices sheet is older than this Monday | P1 (once per week) |
| `rec_feedback` | A recommendation was proposed with no accept/reject after 1 check-in | P2 |
| `preference` | Goals, risk appetite, disliked activities | P3 |

### 10.3 Scoring and selection

`value = priority_weight × min(1, gold_at_stake / 1000) × uncertainty × freshness × (1 / (1 + skip_count))`

- `priority_weight`: P0 = 8, P1 = 4, P2 = 2, P3 = 1.
- `uncertainty`: 1 − the confidence of the best automated answer. **If observed data can answer it, the question is auto-resolved instead of asked.**
- `freshness`: decays from 1.0 to 0.3 over 48 h, because old questions are harder to answer.
- Pick the top-k by value under the caps. Merge questions that share an answer (e.g. three ledger lines for one item become one question with three fields).
- **Skip handling:** a skipped question gets `skip_count + 1`. Two skips suppress it for 3 days. A suppressed P0 resurfaces in the weekly review instead.
- **Ask once, learn forever:** answers write `knowledge.fact` entries with a TTL (proficiencies 7 days, preferences until changed, leadership values per session).

---

## 11. Sources you need to provide

Interpreting the game correctly depends on these. ★ marks MVP blockers.

| # | Source | Why |
|---|---|---|
| 1 ★ | **`api.lua`** (the file that failed to upload), plus any other `.lua` files and docs in the AAClassic addon SDK or examples folder | The function names, `UI_EVENTS`, E1–E5 and the file-write API decide every placeholder in this plan |
| 2 ★ | **The addon rules / ToS for ArcheAge Classic** (what addons may read or write, whether file output is allowed) | Gate for Stage 1 |
| 3 | 1–2 working community addons for AAClassic, if any exist | Shows real event names and file I/O patterns |
| 4 ★ | `recipes.csv`, `items.csv`, the weekly AH prices CSV, the plants-by-zone CSV | Already used by the skill |
| 5 ★ | `AA-Trading-Ledger.xlsx` and `skill-data/` (proficiencies, requirements, exclusions, learnings) | Imported in Stage 7 with no loss |
| 6 ★ | **Labor rules:** regen per tick online/offline, cap, any subscription/patron effect, proficiency discount formula | Labor efficiency, cap waste, actual-labor checks |
| 7 ★ | **Leadership rules:** how leadership is earned (which content, leader vs member, party size), caps, where it is spent, and the vendor list with prices (to value leadership in gold) | Leadership tracking and leadership-per-hour value |
| 8 | Currency list and units (gold/silver/copper, honor, vocation, other tokens), and confirmation that "Coin" in recipes is copper | Validates `COIN_UNIT_GOLD` |
| 9 | Server time zone, daily/weekly reset times, and recurring event schedules (world bosses, guild raids, trade-pack timers) | Check-in deferral, leadership opportunities, sell timing |
| 10 | Trade-pack routes and payouts (if trade runs are in scope), farm/house plot info | trade_run and farm rules |
| 11 | Screenshots of the UI for money, labor, leadership, bags and the AH sold tab | Ground truth for the A9–A14 pass checks |
| 12 | Game patch notes since launch (link or paste) | Rule changes that make facts stale |
| 13 | Your play profile: characters, typical play hours, goals (e.g. save X gold by date), activities you won't do | Seeds `knowledge.fact` so the first check-ins aren't spent asking |

---

## 12. Claude call budget (< $10/month)

Prices (per million tokens, first-party API, current at time of writing): **Haiku 5.5** $0.10 in / $0.50 out · **Sonnet 5.5** $2 in / $10 out, cache read $0.20 · Opus 5.5 $4 / $20 (not used routinely) · Batch API −50%. Cache writes cost more than plain input (verify the exact multiplier on the live pricing page when building). The 5-min cache **won't survive between hourly check-ins**, but it does help across turns inside one check-in.

**Usage assumption:** 3 h/day × 30 days = **90 check-ins/month**, 3 user turns each.

| Item | Per unit | Count/month | Monthly |
|---|---|---|---|
| Check-in open (Sonnet): 5k prefix cache write + 3k volatile + 600 out | ≈ $0.025 | 90 | $2.25 |
| Check-in turns (Sonnet): about 9k in (mostly cache reads) + 400 out | ≈ $0.008 | 270 | $2.16 |
| Daily plan narrative (Sonnet, Batch API overnight): 12k in + 1.5k out | ≈ $0.02 | 30 | $0.60 |
| Weekly review (Sonnet, `high`): 30k in + 4k out | ≈ $0.10 | 4 | $0.40 |
| Answer parsing and summaries (local LLM; Haiku fallback ≈ $0.0005 each) | ~$0 | 300 | ≤ $0.15 |
| **Expected total** | | | **≈ $5.6** |
| Safety margin (longer chats, retries) | | | → cap **$9.00** |

**Enforcement (in the router, before every call):**
- Estimate the call cost from token counts and refuse it if `spent + estimate > cap`.
- Modes by month-to-date spend vs a linear projection: `normal` (< 70% of cap), `conserve` at 70% (check-in opens move to Haiku, turns capped at 2, daily narrative to local), `local_only` at 90% (Claude only for the weekly review). Shown on the website.
- Per-check-in ceiling of $0.15. When hit, the thread continues on the local LLM with a notice.
- Every call is logged in `assistant.llm_call` with the actual `usage` from the response. The month's spend is computed from real usage, not estimates.
- No tool loops in the MVP (packet-in, structured-out), so cost is bounded per call.

---

## 13. Assumptions the event test must confirm

The **event test** runs probe v0.2 and follows a fixed script, about 45 min. The user presses Marker before each step: login → idle 2 min → open bags → walk 200 m → craft 1 known recipe → gather 1 node → list 1 item on the AH → buy 1 item on the AH → collect mail/AH proceeds → join a party → become leader → fight a mob → zone change → `/reload` (if allowed) → logout.

| ID | Assumption | Pass | Fail → consequence |
|---|---|---|---|
| A1 | `api.On` with each `UI_EVENTS` name can be called in `pcall` without crashing the client | All registrations return; the client keeps running; per-event mode recorded | Register in batches of 20 to find the culprits; mark them `unsafe` |
| A2 | E1–E5 fire with stable argument shapes | Each fires ≥ 1× during the script (or the step that should trigger it is documented), with consistent `n` and types | Mark `dead`/`unverified`; rules that need them stay inactive |
| A3 | Each `UI_EVENTS` entry can be classified | 100% of entries end as registered/fired/dead/unsafe; ≥ 1 sample payload stored for each fired event | Repeat the test with an extended script |
| A4 | The addon can create new files with arbitrary names under `Documents/AAClassic/Addon/<addon>/` | 100 consecutive chunks written; uploader validates 100/100; 0 truncated | If only one fixed file (e.g. saved variables) works, switch to a ring-buffer format in one file. A minor format change, and the uploader tails it. |
| A5 | Which of append/rename/delete/list exist | Documented yes/no for each | Write-once chunks need none of them |
| A6 | A clock exists (wall and/or monotonic) with ≤ 1 s resolution | Drift between addon `ms` and file mtime < 2 s over 1 h | Use frame/timer accumulation; the uploader stamps wall time from mtime |
| A7 | A timer or update hook exists for polling | Measured callback rate is stable within ±20% | Poll only on events; snapshots become event-driven |
| A8 | Full subscription doesn't hurt play | Handler + poller time < 1 ms/frame on average, no hitch > 50 ms in a crowded town for 10 min, no visible FPS drop | Cut to the `lean` profile: drop or sample the noisiest events |
| A9 | Gold can be read (getter or event) | Matches the UI after 5 transactions, to the copper | Gold from the AH/mail events plus manual entries; cash reconciliation turned off |
| A10 | Labor can be read (current and max) | Matches the UI after craft and gather; regen ticks are visible | Labor efficiency estimated from recipes plus user input |
| A11 | Leadership can be read | Matches the UI before and after one group activity | One leadership question per session (§6.4) |
| A12 | Inventory can be read, or item gains/losses arrive as events | Craft output and gathered items appear within 30 s | Craft and gather rules lose confidence; more classify questions |
| A13 | Craft completion can be identified (item, qty) | The scripted craft produces a matching record | Use `craft.labor_drop` only |
| A14 | AH listing, sale and mail proceeds can be identified | The scripted list, buy and collect each leave a record with item, qty and price | Ledger fill-ins stay manual (P0 questions) |
| A15 | Position and zone can be read | Walking 200 m and changing zone show up | No travel or AFK-by-movement; AFK falls back to "no events" |
| A16 | Party/raid state and leader flag can be read | The join and lead steps are visible | group_content needs user labels |
| A17 | Character name and server can be read | Correct in the header | One-time setup question per install |
| A18 | A logout/reload/zone hook exists, so the last chunk is flushed | The final chunk has `closed=logout` | Accept ≤ 60 s loss; shorten rotation to 30 s |
| A19 | Handlers survive `/reload` and zoning | Events keep arriving after both | Re-register on a load event; documented |
| A20 | Data volume is manageable | ≤ 20 MB/h raw after sampling; no single event > 2 records/s after sampling | Tighten the sampler; trim the payload depth |
| A21 | An erroring handler doesn't break others or spam chat | A forced error in one handler leaves the others firing; no chat spam | Wrap all handlers; never print to chat |
| A22 | `pairs(api)` introspection works | Manifest has > 0 entries with types | Allow-list built by hand from `api.lua` |
| A23 | Item names with non-ASCII characters serialize correctly | Names round-trip byte-exact to Postgres | Escape them in the serializer |
| A24 | The ToS allows a read-only, file-writing addon | Written confirmation from the rules or a GM | **Stop.** Fall back to a manual/screenshot workflow |
| A25 | Recipe "Coin" amounts are copper | A craft with a fee shows gold Δ = fee in copper (± 0) | Fix `COIN_UNIT_GOLD`; re-run plans; add a learning |

---

## 14. Build stages with pass/fail criteria

| Stage | Deliverable | Pass criteria | Fail action |
|---|---|---|---|
| **S0 Sources** | Items in §11 marked ★ supplied | `api.lua` present; `UI_EVENTS` count N and E1–E5 names extracted; file-write API identified; A24 answered yes; CSVs and ledger present | Cannot start S1 without `api.lua` and A24 |
| **S1 Probe v0.1** (introspection + E1–E5 only) | Addon loads; writes manifest and header chunks | Loads with 0 Lua errors over 3 logins; manifest written; ≥ 1 of E1–E5 seen; uploader not needed yet (files read by hand) | Fix and repeat; if file writes are impossible, re-plan §3 (A4) |
| **S2 Event test** (probe v0.2, all `UI_EVENTS`) | `catalog.event_test` result | A1–A25 each marked pass/fail/unknown with evidence; **minimum to go on: gold (A9) or AH events (A14) work, labor (A10) works, a clock or timer (A6/A7) works, files (A4) work** | If the minimum fails, stop the automatic route: MVP becomes a manual-entry website plus planner, and the addon is shelved |
| **S3 Capture v1.0** | Daily-use addon with the allow-list from S2 | 3 real sessions ≥ 1 h each; 0 client crashes; seq gaps cover ≤ 60 s per session; A8 performance budget met; ≤ 20 MB/h | Drop to the `lean` profile; re-test |
| **S4 Uploader** | Go binary, tray, toast | Kill test (uploader killed mid-insert 10×): 0 duplicates, 0 losses; 24 h offline backlog catches up in < 5 min; bad files quarantined with a reason; toast shows over full-screen | Fix before any derived work |
| **S5 DB + derive** | Schemas `raw`, `catalog`, `core`, `knowledge` | Full rebuild of `core.*` from `raw.*` twice gives identical results (row hashes equal); dashboard queries < 200 ms on 1 month of data; disk use measured and projected | Fix non-determinism (time zones, ordering) |
| **S6 Rules engine** | §6 rules + gold reconciliation | On the labeled event-test session: ≥ 85% of seconds correct for activities whose inputs are verified; `unknown` < 25% over 3 real sessions; session bounds within ±1 min; gold and labor samples match the UI exactly | Tune thresholds; add rules; more classify questions as a stopgap |
| **S7 Website + ledger** | Dashboard, ledger, planner, import | Excel import keeps row counts and totals equal; planner output identical to the `analyze.py` CLI for the same inputs; daily view shows time by activity, gold (3 numbers) and leadership | Fix the adapter |
| **S8 Check-in** | Scheduler, packet, questions, chat, router, budget | Over 1 week: check-ins fire within ±5 min of the due play-hour; 0 during group_content/PvP (unless the 20-min deferral cap is hit); question caps never exceeded; median user time per check-in < 2 min; every LLM call logged with real usage; projected month < $10 | Tune deferral or budgets; switch routing to cheaper models |
| **S9 Recommendation loop** | Ledger, evaluators, hit-rate display | 100% of shown recommendations are in the ledger with a prediction (or tagged unmeasurable); ≥ 80% reach measured/unmeasurable/expired within their window; hit rate visible per source and type; 0 invented realized values (audit: every `measured` row links to sale or sample records or a user answer) | Fix evaluators; stop LLM types that can't be measured |

**Order and dependencies:** S0 → S1 → S2 is a strict gate. S4 and S5 can run in parallel with S3. S6 needs S2 + S5. S7 needs S5 (and S6 for the observed fill-ins). S8 needs S6 + S7. S9 needs S8.

---

## 15. Out of scope for the MVP (noted for later)

Multi-user hosting, mobile app, LLM tool use over the DB (read-only SQL tools), trade-pack route optimizer, a price-history scraper replacing the weekly CSV, multi-character labor planning, voice check-ins.
