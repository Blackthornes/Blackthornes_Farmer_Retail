-- Levels that follow you: Retail scales most mobs to the player's level.
--
-- What matters: a mob met at your own level in a zone the game gives a
-- range for keeps that range on its record, and the Grind tab, Rankings,
-- the search and Where to farm read the range rather than the level you
-- met it at; a mob not at your level, or in a zone with no range, keeps the
-- levels it was seen at; the levels seen are never rewritten; and your own
-- level is the one the fight uses (Party Sync, Timewalking).

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("scaledlevels")

local ns = env.Load({ ui = true, retail = true })
local Harvest = ns.Harvest

_G.GetRealZoneText = function() return "Elwynn Forest" end
_G.GetSubZoneText = function() return "" end

local ranges = { [37] = { 10, 70 } }
env.world.mapID = 37
_G.C_Map.GetMapLevels = function(mapID)
    local range = ranges[mapID]
    if not range then return 0, 0, 0, 0 end
    return range[1], range[2], range[1], range[2]
end

-- The test player is level 25.
suite.check("your level is read", Harvest.PlayerLevel() == 25, Harvest.PlayerLevel())
_G.UnitEffectiveLevel = function() return 18 end
suite.check("Party Sync's lower level comes first", Harvest.PlayerLevel() == 18)
_G.UnitEffectiveLevel = function() return 25 end

suite.check("the zone's range is read", select(2, Harvest.ZoneScales()) == 70)

-- A wolf at your level: it scales.
local wolf = Harvest:GetRecord("Timber Wolf", 25, "Elwynn Forest", "")
suite.check("a mob at your level keeps the zone's range",
    type(wolf.scales) == "table" and wolf.scales[1] == 10 and wolf.scales[2] == 70)
suite.check("the level seen stays as it was", wolf.minLevel == 25 and wolf.maxLevel == 25)
local low, high, scaled = Harvest.Levels(wolf)
suite.check("readers get the range", low == 10 and high == 70 and scaled == true)

-- A boss well over you: no range.
local boss = Harvest:GetRecord("Hogger", 40, "Elwynn Forest", "")
suite.check("a mob far from your level keeps no range", boss.scales == nil)
low, high, scaled = Harvest.Levels(boss)
suite.check("and reads as the level seen", low == 40 and high == 40 and scaled == false)

-- A zone that does not scale.
env.world.mapID = 99
local kobold = Harvest:GetRecord("Kobold Miner", 25, "Elwynn Forest", "Fargodeep Mine")
suite.check("no range where the game gives none", kobold.scales == nil)
env.world.mapID = 37

-- A record from before: no scales, read as it was.
local old = { mob = "Old Mob", zone = "Elwynn Forest", minLevel = 12, maxLevel = 14, corpses = 3, items = {} }
low, high, scaled = Harvest.Levels(old)
suite.check("a record from before reads as it was", low == 12 and high == 14 and scaled == false)

-- The Grind tab: at level 60 the wolf is still in band.
wolf.corpses = 5
Harvest.changes = (Harvest.changes or 0) + 1
ns.Grinding.cache = nil
local found = false
for _, camp in ipairs(ns.Grinding:Camps({ low = 58, high = 62 }) or {}) do
    for _, mob in ipairs(camp.mobs or {}) do
        if (mob.name or mob) == "Timber Wolf" then found = true end
    end
end
suite.check("the Grind tab finds a scaling mob at any level in range", found)

-- Rankings: the range, not the level you met it at.
ns.Rankings.ownLevels = nil
local levels = ns.Rankings:OwnLevels()
suite.check("Rankings reads the range", levels["Timber Wolf"] and levels["Timber Wolf"].min == 10
    and levels["Timber Wolf"].max == 70)

-- The colour goes by your level inside the range, never the range's top.
local source = { minLevel = 10, maxLevel = 70, scales = true }
suite.check("a scaling mob is coloured at your level", ns.UI.ColorLevel(source) == 25)
suite.check("a fixed one by its top level", ns.UI.ColorLevel({ minLevel = 30, maxLevel = 32 }) == 32)

_G.UnitEffectiveLevel = nil

suite.done()
