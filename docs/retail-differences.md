# Retail differences

Every place this repo (Farmer for Retail) differs from Forever Farmer on
purpose, and what a catch-up with Forever does when Forever changes the same
code. A developer note: it never ships (`.pkgmeta` ignores `docs`).

**Read this before every catch-up.** For each Forever commit, check its files
against the list below. A file not listed here is the same as Forever's and
takes Forever's change as it is. A file listed here is a clash only where
Forever's change touches the lines named; then follow that entry's rule and
show the owner both versions.

The rules:

- **Keep Retail:** skip Forever's change to these lines.
- **Blend:** bring Forever's idea over on top of Retail's version (the usual
  pick). Retail's lines stay; Forever's fix or feature is added to them.
- **Forever only:** the file stays in the repo, untouched, so merges stay
  clean, but Retail never loads it. Take Forever's changes to it as they are;
  they do nothing on Retail. A new Forever feature that needs one of these
  is a question for the owner.

Baseline: Forever `main` at `16167e1` (2026-10-24, the fold gem), merged in
PR #3. `git diff 16167e1 HEAD` on Retail's `main` shows every line below.

**Keep it current:** every Retail-only PR adds or updates its entry here in
the same PR, and every catch-up PR moves the baseline line.

---

## 1. The TOC and what Retail loads

`Blackthornes_Farmer.toc`, `.pkgmeta`, `tools/testenv.lua`
(`env.FOREVER_DATA`, `env.RETAIL_LEFT_OUT`, `env.RETAIL_ONLY`, `env.Load`'s
`opts.retail`), `tools/test_retail.lua`. PRs: the copy commits
(`905053a`, `613fcd5`), #8, #9.

- `## Interface: 120105`, the number the Retail game reports (Forever: 16001).
- `## X-Curse-Project-ID: 1763183`, Retail's own CurseForge project. Never
  Forever's 1710618.
- Not listed in the TOC, and in `.pkgmeta`'s ignore list:
  - Classic and Forever data: `Data/NpcNames.lua`, `Data/ForeverNpcNames.lua`,
    `Data/Data_Mining.lua`, `Data_Herbalism`, `Data_Cloth`, `Data_Leather`,
    `Data_Misc`, `Data_MobDrops`, `Data_ClassicDrops`, `Data_Harvested`, and
    the `Harvest_Carryover` lines with their `#@do-not-package@` fence.
  - Forever-only features: `Logic/Contribute.lua` (sending drops to
    Blackthornes) and `Logic/Legacy.lua` (Legacy perks). `Contribute.RECIPIENTS`
    is unchanged from Forever's; Retail never sends because the file never
    loads, so never add it to the TOC.
  - Built on the Classic world: Guide Me (`Data/Travel.lua`,
    `Data/TravelZones.lua`, `Logic/Travel.lua`, `UI/TravelCard.lua`,
    `UI/TravelMap.lua`) and Gather to cap (`Logic/GatherToCap.lua`,
    `UI/GatherToCap.lua`).
- Listed in the Retail TOC only: `Logic/RoadToMax.lua`, `UI/RoadToMax.lua`
  (section 6), where Forever lists Gather to cap.

**Sync rule: Keep Retail.** Never take Forever's `## Interface` or
`X-Curse-Project-ID` lines. A Forever commit that adds a file to its TOC:
add it to Retail's TOC in the same place, unless it is Forever or Classic
data or built on one of the left-out features; then leave it out, add it to
`.pkgmeta`, `env.FOREVER_DATA` or `env.RETAIL_LEFT_OUT`, and ask the owner.
The left-out files themselves are **Forever only** (take Forever's changes,
they never load).

## 2. Code that runs without the left-out files

So the addon loads and logs in without them (checked by
`tools/test_retail.lua`).

- `UI/Settings.lua`: the "Guide Me:" row and its `Refresh` line only
  `if ns.Travel`; the About page's drop-sending box only
  `if ns.Contribute`.
- `Logic/Share.lua`: `/farm share drops` only `and ns.Contribute`.
- `UI/Grinding.lua`: draws `ns.RoadToMaxUI or ns.GatherToCapUI` in `Build`
  and `Render`.

**Sync rule: Blend.** Take Forever's change, and keep each guard. A new
Forever row, command or call into Contribute, Legacy, Travel or GatherToCap
gets the same `if ns.X` guard here.

## 3. Area loot counts every corpse (PR #4)

`Logic/Harvest.lua`: `Harvest:OtherCorpses`, `Harvest:SlotShare`,
`Harvest:RecordOther`, the local `AddSlot` (pulled out of `RecordCorpse` so
both use it), and the loop at the top of `Harvest:RecordCorpse`.
`Logic/Tracker.lua`: `Tracker:OtherShare` and, in `Tracker:OnLoot`, the
`others` list and its `Record` loop (and `place` moved above it). Test
`tools/test_aoeloot.lua`.

Retail loots every corpse in reach in one window. Each other corpse the
window names is a kill and a drop-rate corpse of its own, with only its own
share of each slot and its own coin; the one clicked is recorded last.

**Sync rule: Blend.** This is the most likely clash: any Forever fix to loot
counting, `RecordCorpse` or `Tracker:OnLoot` goes on top of Retail's
version, and must reach the other corpses too (through `AddSlot`,
`RecordOther` or `OtherShare`). Never take Forever's `RecordCorpse` or
`OnLoot` whole.

## 4. Levels that follow you (PR #6)

`Logic/Harvest.lua`: `Harvest.SCALE_SLACK`, `Harvest.PlayerLevel`,
`Harvest.ZoneScales`, `Harvest:NoteScaling` (called from `GetRecord`),
`Harvest.Levels`, and `scales` merged in `Harvest:NameUnnamed`. Readers:
`Logic/Grinding.lua` (`Grinding:Mobs`), `Logic/Rankings.lua`
(`Rankings:OwnLevels`), `Logic/Search.lua` (`LowLevel`, `HighLevel`,
`Scales`, `FoundItems`, `Here`), `Logic/Spots.lua` (the same helpers,
`Spots:Player`, `Spots:Candidates`), `Logic/Goals.lua` (`Goals:BestSpot`),
`UI/Main.lua` (`UI.ColorLevel`, `DifficultyColor`, `ShowEmpty`,
`UpdateRow`), `UI/Goals.lua` (`OpenSpots`), `UI/Rankings.lua`
(`PlayerBand`). Test `tools/test_scaledlevels.lua`.

Retail scales open world mobs to you, so a record keeps the zone's range in
`record.scales` (never rename it) and the lists show that range. Your level
is `Harvest.PlayerLevel()` (`UnitEffectiveLevel` first, for Party Sync and
Timewalking) in place of the old `pcall(UnitLevel, "player")` blocks.

**Sync rule: Blend.** A Forever change that reads `record.minLevel` /
`maxLevel` for showing or sorting reads `Harvest.Levels(record)` here; one
that reads `UnitLevel("player")` for the player's level uses
`Harvest.PlayerLevel()`. World drops and the export keep the level at the
kill, as Forever does.

## 5. Level 90 cap (PR #5)

`Logic/XP.lua`: `XP.CAP = 90` (Forever 60), its comments, and
`XP.Needed`, which takes a level past Classic's 1 to 60 chart as about what
the current level needs. `Logic/Grinding.lua`: the comment on
`Grinding.MAX_LEVEL` (the steppers reach the game's cap). Tests
`tools/test_xpbar.lua`, `tools/test_grinding.lua`.

**Sync rule: Keep Retail** for `XP.CAP` and the levels past 60 in
`XP.Needed`; **Blend** any other Forever XP bar change.

## 6. Road to max (PR #9)

`Logic/RoadToMax.lua`, `UI/RoadToMax.lua` (Retail only), the TOC lines,
`UI/Grinding.lua` (section 2), the strings in every `Locale/*.lua`. Saved
as `roadToMax` (never rename it). Test `tools/test_roadtomax.lua`.

Retail's Gather to cap: the twelve expansions in order, Classic to Midnight.
Its Classic stops are its own copy of Forever's ladder (`RoadToMax.CLASSIC`),
not a call into `GatherToCap`. It wraps `Gathering.Record` and
`GrindGather.NoteSkin` at load rather than changing them.

**Sync rule: Keep Retail.** A Forever change to Gather to cap does not come
over by itself. If it fixes something Road to max shares (Classic's
ladder, the Show the Way or Set Goal buttons, how `PlacePath` makes room),
**Blend** it into the RoadToMax files and say so. Keep the wraps working if
Forever changes `Gathering:Record` or `GrindGather:NoteSkin`'s arguments.

Skills (fixed after the first look in game, 2026-10-24): with every
profession window shut, Retail gives 0 of 0 for each line by its ID, so the
road reads the game's Professions book (`GetProfessionInfo`, its line name
such as "Classic Herbalism") through `RoadToMax:ReadBook`, matched to an
expansion by the client's own line names (`LineExpansion`), else the English
word (`LINE_WORDS`). A window open adds `GetChildProfessionInfos`.
Midnight's line before a window names it is kept as `"Herbalism|midnight"`
in `roadToMax[guid].lines`.

## 6b. Herbs and ore off a mob's corpse (Retail)

Retail lets herbalists and miners gather some mobs (Timberlings,
elementals). `Logic/Gathering.lua`: `Gathering.CorpseWindow`,
`Gathering:IsCreatureName`, `Gathering:FromCreature` and the lines in
`Gathering:OnLoot` that mark such a record `creature = true` (never rename
it) and put no map spot down. `Logic/GrindGather.lua`'s `Zones` and
`RoadToMax`'s `OwnGathering` leave them out; `UI/MapMarkers.lua`'s
`SpotsOn` draws no pin for a spot named for a mob you killed. Records are
never rewritten. Tested in `tools/test_roadtomax.lua`.

**Sync rule: Blend.** Keep these lines if Forever changes `OnLoot`,
`GrindGather:Zones` or `SpotsOn`.

## 7. Item icons on map pins, fishing pins, nearby nodes join (PR #10, the pin fix)

`UI/MapMarkers.lua`: `ItemIcon`, `NodeItems`, `SpotItems`, `SpotIcon`,
`BackAt`, `IsBack`, `CreatePin`, `DrawWorld` (redrawn at `worldNextBack`),
`PlaceWorld`, `SpotsOn`. `Logic/Gathering.lua`: `Gathering.NEAR_YARDS`,
`NearSpot`, `Gathering.Joins`, `Gathering.Joined`, `NoteItems`,
`Gathering:AddSpot(mapID, x, y, node, kind, items, quantities)` and its call
in `Gathering:OnLoot`. `Logic/Fishing.lua`: `Fishing:OnLoot` adds a
`kind = "fish"` spot. `Logic/Respawn.lua`: `Respawn:Gathered` skips fish
spots and reads `spot.also`. Saved: spots' `items` and `also` (never rename
them). Test `tools/test_mapicons.lua`.

Since the pin fix: `MapMarkers.RoundIcon` (a mask texture, used by
`CreatePin` and `UI/GrindPins.lua`'s pin), `WORLD_SIZE` 22, `JOIN_PIXELS`,
`Group`, `GroupItems`, `GroupIcon`, `GroupNode`, `Single`,
`ShowGroupTooltip`, the count on `CreatePin`, `Dress` taking a group, and
`PlaceWorld` drawing groups. `Logic/Respawn.lua`: `Respawn:GroupLines` and
the `farmerMarker` owner check in `OnTooltipShown`. Locale lines for the
group hover.

**Sync rule: Blend.** Forever changes to map markers, spots or grow-back
times go on top of Retail's version, keeping the item icons, the round mask, joined pins, the fish
spots (never teaching a grow-back time) and the 3 m join. Never take
Forever's `AddSpot` or `DrawWorld` whole.

## 8. Releases and versions (PRs #7, #8)

- `tools/check_release.py`: `FOREVER_PROJECT` refuses a tag whose TOC names
  1710618 (and `tools/test_check_release.py`).
- `README.md`: the Releasing table names 1763183.
- Versions are Retail's own: 0.46.0 was the first. `Core/Init.lua`'s
  `ns.RELEASED_VERSION`, `CHANGELOG.md`, `NEWS.md` and
  `Core/WhatsNewText.lua` carry Retail's sections.
- No Discord posts for Retail for now: the Discord secrets stay unset.

**Sync rule: Keep Retail.** Never take Forever's `RELEASED_VERSION`,
CHANGELOG, NEWS or What's New sections; a Forever feature that comes over
gets its own Retail CHANGELOG line at the next Retail release. Blend any
other fix to `check_release.py`.

## 9. Notes

`CLAUDE.md`: the "This repo is the Retail copy" section, "Area loot counts
every corpse (Retail)" and "Levels that follow you (Retail)".

**Sync rule: Blend.** Take Forever's new and changed sections, keep the
Retail ones, and move "Last caught up to" to the new Forever commit.

## 10. The arrow moves on past empty spots

`Logic/Arrow.lua`: `Arrow.CHECKED`, `Arrow.SWEEP`, `Arrow.checked`,
`Arrow:WasChecked`, `Arrow:NoteArrivals` (called from `Arrow:State` every
`SWEEP` seconds), `target.checked` in `Arrow:Targets` and
`Arrow:GrindTargets` (sorted after the rest, like a resting spot), and
`GrindTargets` taking `mob.kind`. `Logic/GrindGather.lua`: `NodeCamp`'s
spots carry `kind = "node"`. Nothing saved. Tests in `tools/test_arrow.lua`.

A node spot you come within `ARRIVED_NODE` (12 yards) of counts as checked
for `CHECKED` (3 minutes), gathered or not, so the arrow goes on to the next
spot and not back (the owner, 2026-10-24: sometimes the node isn't there
yet). Passing one on the way to another checks it too, and reaching a spot
picked with a right-click lets the pick go. Grind tab and Road to max node
spots now arrive at a node's 12 yards, not a mob's 35.

**Sync rule: Blend.** Forever changes to how the arrow lists or sorts places
go on top of this; keep the checked spots.

## 11. A hidden item hides its random suffixes

`Data/Database.lua`: `DB:IsHiddenItem` also answers true for a suffix
("Primal Leggings of the Monkey") whose item ("Primal Leggings") is on the
hide list, through `Harvest.RollBase`. The lists name the item once, so
that is the name a right-click hides, but the kill tally keeps each suffix
under its own name, so `Value:FromTally` still counted a hidden green in
worth per kill and the best drop (the owner, 2026-10-24: Webwood Lurker at
88g a kill off one Primal Leggings he had hidden). Every reader goes
through `DB:IsHiddenItem` or `DB:HidesItem`, so all of them follow.
Nothing saved changes. Tests in `tools/test_suffixdrops.lua`. Forever has
the same bug as of `16167e1`; not fixed there from here.

**Sync rule: Keep Retail** for `DB:IsHiddenItem` unless Forever has fixed
it the same way, then take Forever's.

## 12. The loot table comes to the front for each mob

`UI/LootTable.lua`: `LootTableUI:Show` calls `self.frame:Raise()` every
time, not only when the window opens. The main window and the loot table
are both `DIALOG` and top level, so a click on a Rankings row lifts the
main window, and a second mob picked while the loot table was open drew
behind it (the owner, 2026-10-24). Nothing saved changes. Test in
`tools/test_loottable.lua`. Forever has the same bug as of `16167e1`; not
fixed there from here.

**Sync rule: Keep Retail** for the `Raise` line in `LootTableUI:Show`
unless Forever has fixed it the same way, then take Forever's.

## 13. No Forever or sister-addon words on Retail

Retail players never read about Forever, Classic or the sister addons,
which have no Retail version yet (the owner approved the words,
2026-10-27).

- `Core/SisterNote.lua`: `Note.ON_RETAIL` and `Note:Listed()`; `ToName`
  reads `Listed`, so the login chat line names no sister without a Retail
  version. Add a folder to `ON_RETAIL` when one ships for Retail.
  `tools/test_sisternote.lua` sets it to nil for Forever's checks and adds
  a Retail check.
- `UI/About.lua`: the BLACKTHORNES ADDONS list reads `Sisters:Listed()`
  and shows only with more than Farmer in it; the third `THANKS` paragraph
  is Retail's ("Farmer is new on Retail...").
- `UI/Settings.lua`: no "Craft or Sell:" row (it needs Tradeskills;
  `/farm tooltip craft` still answers); the TSM and Auctionator hover no
  longer names Tradeskills.
- `UI/Main.lua` search footer is "Click a row to put it in chat.";
  `UI/LootTable.lua` and `UI/Rankings.lua` name TSM or Auctionator when no
  price addon is loaded; `Logic/Value.lua` `/farm value` help says
  "at auction prices"; `Data/Database.lua` `PROVENANCE.forever` is "from
  your own play"; `Logic/Search.lua` `/farm data` drops the "Classic spots"
  line. The same keys in every `Locale/*.lua`.

- `UI/Main.lua` `UI.SHOW_BADGE` and `UI/Grinding.lua`
  `GrindingUI.SHOW_BADGE` are false: no green [Forever] badge on search or
  Grind rows (every Retail row is your own play). `tools/test_textfit.lua`
  checks Forever's badge slot with it turned on.

`SisterNote.lua` and `About.lua` are otherwise the shared files.

**Sync rule: Blend.** Take Forever's changes to these files and keep these
lines. A new Forever string that names Forever, Classic or a sister addon
gets Retail words, shown to the owner first.

## 14. No Skinning by level

Retail lets any mob in an expansion's zones be skinned with that
expansion's Skinning, so Classic's rule (`Grinding.SkinSkill`, five points
a level) read "400, you have 25" on a level 80 mob and turned skinnable
corpses grey (the owner said fix it, 2026-10-27).

- `UI/Grinding.lua`: the `leather` layout has no `skill` column;
  `GrindingUI.SkinNeed` gives only the data's `skinSkill`; the Leather
  footer uses the Cloth view's words (the "comes from its level" key is
  gone from every `Locale/*.lua`).
- `UI/NodeSparkle.lua` `ColorFor`: a corpse is always `GOLD`.
- Tests: `tools/test_grindgather.lua`, `tools/test_nodesparkle.lua`.
  `Grinding.SkinSkill` itself stays (Gather to cap, Forever only, reads it).

**Sync rule: Keep Retail** for these lines; Blend any other Forever change
to the Leather view or the sparkles.

## 15. Dungeons learned as you kill

The lists in `Logic/Spots.lua` and `Data/Zones.lua` know only Classic's
dungeons, so Retail's counted as open world for "Outside dungeons only"
and World drops (the owner said fix it, 2026-10-27).

- `Logic/Spots.lua`: `Spots.INSTANCE_TYPES` (party, raid),
  `Spots.LearnedInstance`, `Spots:NoteInstance` (keeps the zone in
  `instanceZones[English name] = true`, account wide, never rename it;
  moves `Rankings.outsideVersion`); `Spots.IsInstance` reads it.
- `Logic/Tracker.lua` `Tracker:Record`: each new kill calls
  `Spots:NoteInstance` in a pcall.
- `Logic/WorldDrops.lua` `WorldDrops.Inside`: reads it too.
- Test in `tools/test_rankingsoutside.lua`.

**Sync rule: Keep Retail** for these lines; Blend Forever's changes around
them.

## 16. Bug pass of 2026-10-28

- `Logic/Spots.lua`: `Spots.MapZone(mapID)` and `Spots.mapNames`: a map's
  zone by `Spots.MAP_ZONES`, else the client's own map name (kept per map).
  `MAP_ZONES` holds Classic's map numbers, so on Retail
  `GrindGather:Zones` named no spot's zone, and the Grind tab's Ore and
  Herbs views showed no spots, no grow-back time and pointed the arrow at
  the zone only. `Logic/GrindGather.lua` `Zones` reads `Spots.MapZone`.
  Test in `tools/test_grindgather.lua`.
- `Logic/Arrow.lua`: the `arrow` command's `route` words only `and
  ns.Travel` (it raised a Lua error without Guide Me), and `Arrow:OnEnable`
  gives the command a help line without "route" when Travel is not loaded
  (a new key in every `Locale/*.lua`). Test in `tools/test_retail.lua`.
- `Logic/RoadToMax.lua` `ReadWindow` moves `RoadToMax.version` when a line
  changes, so a road already drawn shows a skill a profession window read.
  Test in `tools/test_roadtomax.lua`.

**Sync rule: Keep Retail** for these lines; Blend Forever's changes around
them. If Forever brings its own map-name fallback to `GrindGather:Zones`,
take Forever's.
