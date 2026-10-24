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

--------------------------------------------------------------------------------
-- Pins that would sit on each other draw as one, with a count
--------------------------------------------------------------------------------

local function At(x, y, kind, node)
    return { map = 37, x = x, y = y, kind = kind or "herb", node = node or "Peacebloom",
        gathers = 1, first = 1, last = wall - 60 }
end

-- A 1000 by 667 canvas at zoom 1: a spot's place on screen is x * 1000.
local groups = MapMarkers.Group({ At(0.5, 0.5), At(0.51, 0.5), At(0.6, 0.5) }, 1000, 667, 1)
suite.check("two herbs 10 pixels apart join, one 100 off stays its own", #groups == 2
    and #groups[1].spots == 2 and #groups[2].spots == 1, #groups)
suite.check("a joined pin sits in the middle of its spots",
    math.abs(groups[1].x - 0.505) < 1e-9 and groups[1].y == 0.5)

groups = MapMarkers.Group({ At(0.5, 0.5), At(0.51, 0.5) }, 1000, 667, 4)
suite.check("zoomed in they come apart", #groups == 2, #groups)

groups = MapMarkers.Group({ At(0.5, 0.5), At(0.501, 0.5, "ore", "Copper Vein") }, 1000, 667, 1)
suite.check("a herb and a vein never join", #groups == 2, #groups)

-- A long line of spots each 15 pixels on: the pin keeps its first spot as
-- its anchor, so the line does not join end to end.
groups = MapMarkers.Group({ At(0.5, 0.5), At(0.515, 0.5), At(0.53, 0.5), At(0.545, 0.5) }, 1000, 667, 1)
suite.check("a line of spots never joins end to end", #groups == 2, #groups)

Gathering:ClearSpots()
local saved = Gathering:Spots()
saved[1] = At(0.5, 0.5)
saved[2] = At(0.505, 0.5)
saved[2].node, saved[2].items = "Silverleaf", { Silverleaf = 3 }
saved[1].items = { Peacebloom = 1 }
saved[3] = At(0.8, 0.8)
Gathering.spotsVersion = (Gathering.spotsVersion or 0) + 1
MapMarkers:Refresh()

local pins = MapMarkers.worldPool
suite.check("three spots, two pins", pins.used == 2, pins.used)
local many = pins.pins[1]
suite.check("the joined pin counts its spots", many.count._text == "2" and many.count._shown ~= false,
    many.count._text)
suite.check("a pin of one shows no count", pins.pins[2].count._text == "")
suite.check("it shows what its spots gave most", MapMarkers.GroupItems(many.group)[1].name == "Silverleaf")

GameTooltip._lines = {}
many:GetScript("OnEnter")(many)
suite.check("its hover is named for the node taken most there",
    GameTooltip._lines[1] == "Peacebloom", GameTooltip._lines[1])
suite.check("then what they gave together", GameTooltip._lines[2] == "Silverleaf"
    and tostring(GameTooltip._lines[3]):find("Peacebloom$") ~= nil, GameTooltip._lines[3])
suite.check("then how many spots and gathers",
    GameTooltip._lines[4] == "2 spots, gathered 2 times, last 1 min ago", GameTooltip._lines[4])
suite.check("and learning while no time is known",
    tostring(GameTooltip._lines[5]):find("learning") ~= nil, GameTooltip._lines[5])

-- Peacebloom grows back in about 10 minutes; one gathered 11 minutes ago,
-- one 2 minutes ago.
for _ = 1, 3 do Respawn:Learn(37, "Peacebloom", 600) end
saved[1].last, saved[2].node, saved[2].last = wall - 660, "Peacebloom", wall - 120
local lines = Respawn:GroupLines({ saved[1], saved[2] }, wall, "Peacebloom")
suite.check("one line for those back", lines[1] and lines[1].text == "1 should be back by now  (from 3 returns)",
    lines[1] and lines[1].text)
suite.check("one for the next to come back", lines[2] and lines[2].text == "Next back in about 8 min",
    lines[2] and lines[2].text)
suite.check("and nothing else", #lines == 2)

MapMarkers:Refresh()
suite.check("a joined pin is in colour once any of its spots is back", MapMarkers.worldPool.pins[1].back == true)

--------------------------------------------------------------------------------
-- The node tooltip leaves our pins alone
--------------------------------------------------------------------------------

_G.GameTooltipTextLeft1 = env.Stub({ _text = "Peacebloom" })
env.world.mapID, env.world.position = 37, { 0.5, 0.5 }
local owner
GameTooltip.GetOwner = function() return owner end

owner = many
GameTooltip._lines = {}
Respawn.added = nil
Respawn:OnTooltipShown(GameTooltip, false)
suite.check("a map pin's card gets no \"Grows back in about\" line", #GameTooltip._lines == 0,
    GameTooltip._lines[1])

owner = nil
Respawn.added = nil
Respawn:OnTooltipShown(GameTooltip, false)
suite.check("a herb in the world still gets it",
    tostring(GameTooltip._lines[1]):find("Grows back in about") ~= nil, GameTooltip._lines[1])
Respawn.added = nil

--------------------------------------------------------------------------------
-- Round icons the Retail way
--------------------------------------------------------------------------------

local frame, icon = env.Stub(), env.Stub()
local made, added
frame.CreateMaskTexture = function() made = env.Stub() return made end
icon.AddMaskTexture = function(_, mask) added = mask end
MapMarkers.RoundIcon(frame, icon)
suite.check("an icon is cut round by a mask texture", made ~= nil and added == made)

frame, icon = env.Stub(), env.Stub()
local old
icon.SetMask = function(_, file) old = file end
frame.CreateMaskTexture = nil
rawset(frame, "CreateMaskTexture", false)
MapMarkers.RoundIcon(frame, icon)
suite.check("SetMask only where there are no mask textures", old ~= nil)

suite.done()
