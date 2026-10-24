-- The item icons on the gathering markers, fishing markers, and nodes that
-- sit within a few meters of each other.
--
-- What matters: a world map marker shows the game's icon for the item its
-- spot gave most, else what that node gave anywhere, else the plain herb or
-- ore; it is grey until your own grow-back time says the node is back, then
-- in colour without its check, and it turns by itself when that time comes;
-- the hover lists what the spot gave; a catch marks where you stood with the
-- fish's icon, never teaching a grow-back time and never turning to colour;
-- a herb or vein within about 3 meters of a spot joins it whatever its name,
-- and older saves with two that close draw as one.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("mapicons")

local clock, wall = 500, 1000000

local ns = env.Load({ ui = true })
local Gathering, MapMarkers, Respawn = ns.Gathering, ns.MapMarkers, ns.Respawn

_G.GetTime = function() return clock end
_G.time = function() return wall end

-- 3000 yards across, 2000 down.
_G.C_Map.GetMapWorldSize = function(mapID)
    if mapID == 37 then return 3000, 2000 end
    return nil
end

local ICON = { [2447] = 133939, [2770] = 135232, [2771] = 135240, [6291] = 133888 }
_G.C_Item = { GetItemIconByID = function(id) return ICON[id] end }

for _, module in ipairs(ns.moduleOrder) do
    if module.OnEnable then module:OnEnable() end
end

local fire = ns.eventFrame:GetScript("OnEvent")
local HERB_GATHERING, MINING = 2366, 2575
local casts = 0

local function Gather(spell, node, items)
    casts = casts + 1
    local id = "Cast-" .. casts
    fire(ns.eventFrame, "UNIT_SPELLCAST_SENT", "player", node, id, spell)
    clock = clock + 2
    fire(ns.eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", id, spell)
    env.world.loot = items
    fire(ns.eventFrame, "LOOT_OPENED")
    fire(ns.eventFrame, "LOOT_CLOSED")
    clock = clock + 1
end

env.world.target = nil
env.world.zone, env.world.subZone = "Elwynn Forest", "Goldshire"
env.world.mapID = 37
env.world.position = { 0.45, 0.68 }

local COPPER = { { name = "Copper Ore", id = 2770, quantity = 2 }, { name = "Rough Stone", id = 2835 } }

--------------------------------------------------------------------------------
-- What a spot gave
--------------------------------------------------------------------------------

Gather(MINING, "Copper Vein", COPPER)
local spot = Gathering:Spots()[1]
suite.check("a spot keeps what it gave", type(spot.items) == "table"
    and spot.items["Copper Ore"] == 2 and spot.items["Rough Stone"] == 1)

local items = MapMarkers.SpotItems(spot)
suite.check("most first", items[1].name == "Copper Ore" and items[2].name == "Rough Stone")
suite.check("its icon is the game's icon for the item it gave most",
    MapMarkers.SpotIcon(spot) == 135232, MapMarkers.SpotIcon(spot))

-- A spot saved before spots kept items: what its node gave anywhere.
local old = Gathering:AddSpot(37, 0.2, 0.2, "Copper Vein", "ore")
old.items = nil
MapMarkers.nodeItems = nil
suite.check("an older spot reads its node's record", MapMarkers.SpotIcon(old) == 135232)

-- Nothing the game has an icon for: the plain one.
local unknown = Gathering:AddSpot(37, 0.3, 0.3, "Odd Vein", "ore")
suite.check("no icon known keeps the plain ore", MapMarkers.SpotIcon(unknown):find("Ore_Copper") ~= nil)

--------------------------------------------------------------------------------
-- The world map: grey until it is back
--------------------------------------------------------------------------------

Gathering:ClearSpots()
Gather(MINING, "Copper Vein", COPPER)
spot = Gathering:Spots()[1]

local canvas = env.Stub({ _width = 1000, _height = 667 })
_G.WorldMapFrame = env.Stub({ _shown = true })
WorldMapFrame.GetCanvas = function() return canvas end
WorldMapFrame.GetMapID = function() return 37 end
WorldMapFrame.ScrollContainer = { GetCanvasScale = function() return 1 end }

MapMarkers:Refresh()
local pin = MapMarkers.worldPool.pins[1]
local seen = {}
pin.icon.SetTexture = function(_, value) seen.texture = value end
pin.icon.SetDesaturated = function(_, value) seen.grey = value end
pin.badge.SetShown = function(_, value) seen.check = value end
pin.SetAlpha = function(_, value) seen.alpha = value end
MapMarkers:Refresh()

suite.check("the world marker shows the item's icon", seen.texture == 135232, seen.texture)
suite.check("grey while no grow-back time is known", seen.grey == true and seen.check == true)

-- Three returns teach it: about 10 minutes.
for _ = 1, 3 do Respawn:Learn(37, "Copper Vein", 600) end
MapMarkers:Refresh()
suite.check("still grey before that time is up", seen.grey == true)
suite.check("and it knows when to look again", MapMarkers.worldNextBack == spot.last + 600)

wall = wall + 601
MapMarkers:Step(1)
suite.check("in colour once it should be back, by itself", seen.grey == false, seen.grey)
suite.check("without its check", seen.check == false)
suite.check("at full strength", seen.alpha == 1, seen.alpha)

--------------------------------------------------------------------------------
-- The hover
--------------------------------------------------------------------------------

GameTooltip._lines = {}
pin:GetScript("OnEnter")(pin)
suite.check("the hover names the node", GameTooltip._lines[1] == "Copper Vein", GameTooltip._lines[1])
suite.check("then what it gave, with icons",
    GameTooltip._lines[2] == "|T135232:14:14|t Copper Ore" and GameTooltip._lines[3] == "Rough Stone",
    GameTooltip._lines[2])

--------------------------------------------------------------------------------
-- Within 3 meters
--------------------------------------------------------------------------------

-- 2 yards over, a Rich Copper Vein: the same place.
env.world.position = { 0.45 + 2 / 3000, 0.68 }
Gather(MINING, "Rich Copper Vein", { { name = "Copper Ore", id = 2770 } })
suite.check("another vein 2 yards off joins the spot", #Gathering:Spots() == 1, #Gathering:Spots())
suite.check("which keeps its name", spot.node == "Copper Vein" and spot.gathers == 2)
suite.check("and notes the other", spot.also and spot.also["Rich Copper Vein"] == true)
suite.check("which teaches nothing about the first one's time",
    Respawn:Estimate(37, "Copper Vein").returns == 3)
suite.check("and counts as gathered on this map", Respawn:Gathered(37, "Rich Copper Vein"))

-- 6 yards over: its own.
env.world.position = { 0.45 + 6 / 3000, 0.68 }
Gather(MINING, "Tin Vein", { { name = "Tin Ore", id = 2771 } })
suite.check("one 6 yards off is its own spot", #Gathering:Spots() == 2)

-- A herb on the vein is never joined to it.
env.world.position = { 0.45, 0.68 }
Gather(HERB_GATHERING, "Peacebloom", { { name = "Peacebloom", id = 2447 } })
suite.check("a herb beside a vein is its own spot", #Gathering:Spots() == 3)

-- An older save with two veins that close: drawn as one, the newest.
local saved = Gathering:Spots()
saved[#saved + 1] = { map = 37, x = 0.45 + 1 / 3000, y = 0.68, node = "Old Vein", kind = "ore",
    gathers = 1, first = 1, last = 1 }
local joined = Gathering.Joined(Gathering:SpotsOn(37))
local count, oldShown = 0, false
for _, entry in ipairs(joined) do
    if entry.kind == "ore" then count = count + 1 end
    if entry.node == "Old Vein" then oldShown = true end
end
suite.check("older spots that close draw as one", count == 2 and not oldShown, count)
suite.check("and the save keeps both", #Gathering:Spots() == 4)

--------------------------------------------------------------------------------
-- Fishing
--------------------------------------------------------------------------------

Gathering:ClearSpots()
env.world.position = { 0.5, 0.5 }
local function Catch(items)
    env.world.fishing = true
    env.world.loot = items
    fire(ns.eventFrame, "LOOT_OPENED")
    fire(ns.eventFrame, "LOOT_CLOSED")
    env.world.fishing = false
end
_G.IsFishingLoot = function() return env.world.fishing and true or false end

fire(ns.eventFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", 7620)
Catch({ { name = "Raw Brilliant Smallfish", id = 6291 } })
local fish = Gathering:Spots()[1]
suite.check("a catch marks where you stood", fish ~= nil and fish.kind == "fish" and fish.map == 37)
suite.check("named open water with no school", fish and fish.node == ns.Fishing.OPEN_WATER)
suite.check("with the fish's icon", fish and MapMarkers.SpotIcon(fish) == 133888)

wall = wall + 120
fire(ns.eventFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-2", 7620)
Catch({ { name = "Raw Brilliant Smallfish", id = 6291 } })
suite.check("casting again there is the same marker", #Gathering:Spots() == 1 and fish.gathers == 2)
suite.check("which teaches no grow-back time",
    Respawn:Estimate(37, ns.Fishing.OPEN_WATER).returns == 0)
suite.check("and never turns to colour", MapMarkers.IsBack(fish, wall + 99999) == false)
suite.check("nor counts as a node gathered here", not Respawn:Gathered(37, ns.Fishing.OPEN_WATER))

MapMarkers:Refresh()
local fishPin = MapMarkers.worldPool.pins[1]
GameTooltip._lines = {}
fishPin:GetScript("OnEnter")(fishPin)
suite.check("its hover says open water", GameTooltip._lines[1] == "Open water", GameTooltip._lines[1])
suite.check("and how often you fished there",
    GameTooltip._lines[3] == "Fished here 2 times, last just now", GameTooltip._lines[3])
local grows = false
for _, line in ipairs(GameTooltip._lines) do
    if tostring(line):find("Grows back") then grows = true end
end
suite.check("and nothing about growing back", not grows)

suite.done()
