-- Area loot on Retail: every corpse in the window is its own kill.
--
-- What matters: Retail loots every corpse in reach at once, so the other
-- corpses the window names count as kills of their own, with only what the
-- client says came off each, in the kill tally and in the drop rates; the
-- session's loot and coin still take the window once; a corpse with no name
-- known stays out, as before; and nothing counts twice when one of them is
-- opened again later.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("aoeloot")

local ns = env.Load()
local Tracker = ns.Tracker
local Harvest = ns.Harvest

_G.GetRealZoneText = function() return "Elwynn Forest" end
_G.GetSubZoneText = function() return "" end

local BANDIT, THUG, WOLF = "Defias Bandit", "Defias Thug", "Mangy Wolf"
local A = "Creature-0-1-2-3-116-0000000A"   -- the one you open
local B = "Creature-0-1-2-3-38-0000000B"    -- seen alive, so named
local C = "Creature-0-1-2-3-299-0000000C"   -- named by its ID only
local D = "Creature-0-1-2-3-88888-0000000D" -- nothing names it

-- B is seen alive first, the way a nameplate or the mouse shows it.
env.world.target = { name = THUG, level = 9, dead = false, guid = B }
Harvest:NoteUnit("target")
ns.db.npcNames = ns.db.npcNames or {}
ns.db.npcNames[299] = WOLF

local window = {
    { name = "Linen Cloth", id = 2589, quantity = 4 },
    { name = "Chunk of Boar Meat", id = 769, quantity = 1 },
    { name = "Red Linen Robe", id = 2572, quantity = 1 },
    { name = "1 Silver", money = true },
}
local sources = {
    { A, 1, B, 2, D, 1 },              -- the linen
    { C, 1 },                           -- the meat is the wolf's
    { D, 1 },                           -- the robe is the unnamed one's
    { A, 30, B, 40, C, 20, D, 10 },     -- the coin, in copper
}

local function Open(guid, name, loot, lootSources)
    env.world.target = { name = name, level = 10, dead = true, guid = guid }
    env.world.loot = loot
    _G.GetLootSourceInfo = function(slot) return unpack(lootSources[slot] or {}) end
    Harvest:RecordCorpse()
    return Tracker:OnLoot()
end

local function Mob(name) return ns.db.tracker.mobs[name] end
local function Record(name) return Harvest.records[name .. "|Elwynn Forest|"] end

suite.check("the corpse you opened is a kill", Open(A, BANDIT, window, sources) == true)
suite.check("so is the one seen alive", Mob(THUG) and Mob(THUG).kills == 1)
suite.check("and the one named by its ID", Mob(WOLF) and Mob(WOLF).kills == 1)
suite.check("three kills, not four", Tracker:SessionKills() == 3, Tracker:SessionKills())
suite.check("the unnamed one is no kill", ns.db.tracker.mobs["Creature #88888"] == nil)

suite.check("your kill keeps only its own linen", Mob(BANDIT).qty["Linen Cloth"] == 1)
suite.check("the thug gets its two", Mob(THUG).qty["Linen Cloth"] == 2, Mob(THUG).qty["Linen Cloth"])
suite.check("the wolf gets the meat", Mob(WOLF).items["Chunk of Boar Meat"] == 1)
suite.check("and none of the linen", Mob(WOLF).items["Linen Cloth"] == nil)
suite.check("each has its own coin", Tracker:CoinPerKill(BANDIT) == 30
    and Tracker:CoinPerKill(THUG) == 40 and Tracker:CoinPerKill(WOLF) == 20)

suite.check("the session has all the linen once", Tracker.sessionLoot["Linen Cloth"] == 4,
    Tracker.sessionLoot["Linen Cloth"])
suite.check("the unnamed corpse's robe is still yours", Tracker.sessionLoot["Red Linen Robe"] == 1)
suite.check("and the whole silver once", Tracker.sessionCopper == 100, Tracker.sessionCopper)
suite.check("the thug's linen is listed under it", Tracker.sessionFrom["Linen Cloth"][THUG] == 2)
suite.check("your kill stays on top of the panel", Tracker.current == BANDIT, Tracker.current)

suite.check("the drop rates count each corpse", Record(BANDIT).corpses == 1
    and Record(THUG).corpses == 1 and Record(WOLF).corpses == 1)
suite.check("with its own share", Record(THUG).items["Linen Cloth"].count == 2
    and Record(BANDIT).items["Linen Cloth"].count == 1)
suite.check("the wolf's meat is the wolf's", Record(WOLF).items["Chunk of Boar Meat"] ~= nil
    and Record(BANDIT).items["Chunk of Boar Meat"] == nil)
suite.check("coin is no item", Record(THUG).items["1 Silver"] == nil)
suite.check("the thug's level is the one seen", Record(THUG).minLevel == 9, Record(THUG).minLevel)

-- Bags were full: the thug is opened later for its leftover linen.
local before = Tracker:SessionKills()
Open(B, THUG, { { name = "Linen Cloth", id = 2589, quantity = 2 } }, { { B, 2 } })
suite.check("opening one again is no new kill", Tracker:SessionKills() == before, Tracker:SessionKills())
suite.check("nor a new corpse in the rates", Record(THUG).corpses == 1, Record(THUG).corpses)
suite.check("and its linen is not counted twice", Mob(THUG).qty["Linen Cloth"] == 2,
    Mob(THUG).qty["Linen Cloth"])

-- A mob still alive in the window is a pocket, never a kill.
local E = "Creature-0-1-2-3-38-0000000E"
env.world.target = { name = THUG, level = 9, dead = false, guid = E }
_G.GetLootSourceInfo = function() return A, 1, E, 1 end
env.world.loot = { { name = "Linen Cloth", id = 2589, quantity = 2 } }
suite.check("a living mob is not taken for a corpse", #Harvest:OtherCorpses(A) == 0)

-- A window without sources is the opened corpse's alone, as before.
_G.GetLootSourceInfo = nil
suite.check("no sources, no other corpses", #Harvest:OtherCorpses(A) == 0)

suite.done()
