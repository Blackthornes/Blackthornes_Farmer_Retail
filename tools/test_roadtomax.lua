-- Road to max on the Grind tab, Retail's Gather to cap (the owner approved
-- the mockup and its words, 2026-10-24).
--
-- What matters: the road is the twelve expansions in order, each with your
-- skill in its own line as the client gives it (kept per character when it
-- will not say again); the one lit is where you stand, by zone name or
-- the map's continent; Classic keeps Forever's ladder, the rest are steps
-- of their cap in their zones, the one you are on where you gathered most;
-- a line not learned says so, a line at its cap says it is done;
-- Midnight's line is learned from a profession window; "About N more
-- gathers" waits for your own rate; gathers and skins count toward it; the
-- Grind tab draws it, a tile picks an expansion, Show the Way and Set Goal
-- work; a profession you lack shows nothing; Forever never loads it.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("roadtomax")
local check = suite.check

local forever = env.Load({ ui = true })
check("Forever never loads it", forever.RoadToMax == nil and forever.RoadToMaxUI == nil
    and forever.GatherToCap ~= nil)

local ns = env.Load({ ui = true, retail = true })
local Road, RoadUI, GrindingUI = ns.RoadToMax, ns.RoadToMaxUI, ns.GrindingUI
check("Retail loads it in place of Gather to cap", Road ~= nil and RoadUI ~= nil and ns.GatherToCap == nil)

ns.Value.UnitPrice = function(_, id) if id then return 10, "auction" end end
ns.Print = function() end

-- The professions you have.
local professions = { "Mining", "Skinning" }
_G.GetProfessions = function() return 1, 2 end
_G.GetProfessionInfo = function(index)
    local name = professions[index]
    if name then return name, 0, 1, 1 end
end
ns.Spots.ForgetSkills()

-- Each skill line as the client gives it.
local lines = {
    [2572] = { 300, 300, 186 }, [2571] = { 75, 75, 186 }, [2570] = { 41, 75, 186 },
    [2564] = { 120, 300, 393 },
}
local function Info(id)
    local line = lines[id]
    if line then return { skillLevel = line[1], maxSkillLevel = line[2], parentProfessionID = line[3] } end
    local parent = 186
    if id == 2556 or id == 2555 then parent = 182 end
    return { skillLevel = 0, maxSkillLevel = 0, parentProfessionID = parent }
end
local windowLines = { 2572, 2571, 2570, 2900 }
_G.C_TradeSkillUI = {
    GetProfessionInfoBySkillLineID = Info,
    GetAllProfessionTradeSkillLines = function() return windowLines end,
}

-- Maps: Borean Tundra on Northrend.
local mapParents = { [114] = 113, [113] = 947, [550] = 572, [572] = 947, [198] = 12, [12] = 947 }
_G.C_Map.GetMapInfo = function(id)
    if mapParents[id] then return { mapID = id, parentMapID = mapParents[id], name = "Map " .. id } end
end
env.world.zone, env.world.mapID = "Borean Tundra", 114

--------------------------------------------------------------------------------
-- Where you are
--------------------------------------------------------------------------------

check("a zone's expansion by name", Road.ZoneExpansion("Hellfire Peninsula").key == "outland"
    and Road.ZoneExpansion("Isle of Dorn").key == "khazalgar")
check("Forever's zones are Classic's", Road.ZoneExpansion("Elwynn Forest").key == "classic")
check("a zone no list knows is nil", Road.ZoneExpansion("Nowhere") == nil)
check("here by the continent", Road.Here().key == "northrend")
env.world.zone, env.world.mapID = "Nagrand", 550
check("a shared name goes by the map", Road.Here().key == "draenor")
env.world.zone, env.world.mapID = "Mount Hyjal", 198
check("Cataclysm on an old continent goes by the name", Road.Here().key == "cataclysm")
env.world.zone, env.world.mapID = "Borean Tundra", 114

--------------------------------------------------------------------------------
-- The road
--------------------------------------------------------------------------------

local path = Road:Path("ore")
check("a road for Mining", path and path.english == "Mining" and #path.expansions == 12)
check("Classic and Outland done", path.expansions[1].done and path.expansions[2].done)
check("Northrend read", path.expansions[3].skill == 41 and path.expansions[3].most == 75)
check("one not learned reads 0", path.expansions[4].skill == 0)
check("lit where you stand", path.now == "northrend" and path.expansions[3].now and not path.expansions[1].now)
check("open on it", path.pick == "northrend" and path.line.skill == 41 and path.line.most == 75)
check("four steps of the cap", #path.stops == 4 and path.stops[1].from == 0 and path.stops[4].to == 75)
local now = path.stops[path.current]
check("the step you're on", now.state == "now" and now.from <= 41 and now.to > 41
    and path.stops[1].state == "done" and path.stops[4].state == "later")
check("in the zone you stand in, with nothing gathered", now.zone == "Borean Tundra")
check("no gathers line before your own rate", now.gathers == nil)
check("kept until something moves", Road:Path("ore") == path)

-- What you gathered in Northrend.
ns.db.gathering = ns.db.gathering or {}
ns.db.gathering.nodes = {
    ["Howling Fjord||Cobalt Deposit"] = { zone = "Howling Fjord", node = "Cobalt Deposit", kind = "ore",
        gathers = 30, items = { ["Cobalt Ore"] = { gathers = 30, count = 60, id = 36909 } } },
    ["Elwynn Forest||Copper Vein"] = { zone = "Elwynn Forest", node = "Copper Vein", kind = "ore",
        gathers = 12, items = { ["Copper Ore"] = { gathers = 12, count = 20, id = 2770 } } },
}
ns.db.gathering.pace = { ["Howling Fjord|Cobalt Deposit"] = { seconds = 720, gathers = 30,
    items = { ["Cobalt Ore"] = 60 } } }
ns.GrindGather.paceVersion = (ns.GrindGather.paceVersion or 0) + 1
path = Road:Path("ore")
now = path.stops[path.current]
check("the step you're on goes where you gathered most", now.zone == "Howling Fjord" and now.gathered)
check("its item for a goal", now.item == "Cobalt Ore" and now.itemID == 36909)
check("worth an hour from your own pace", now.perHour == 3000, now.perHour)

-- Your own rate.
local function Gather()
    ns.Gathering:Record("Howling Fjord", nil, "Cobalt Deposit", "ore", { "Cobalt Ore" }, { ["Cobalt Ore"] = 2 })
end
Gather()
for i = 1, 20 do
    if i % 5 == 0 then lines[2570][1] = lines[2570][1] + 1 end
    Gather()
end
local _, mine = Road:Store()
local pace = mine.pace["Mining|northrend"]
check("gathers and points counted", pace and pace.gathers == 21 and pace.points == 4, pace and pace.points)
path = Road:Path("ore")
now = path.stops[path.current]
check("then about how many more", now.gathers == math.ceil((now.to - 45) * 21 / 4 - 1e-9), now.gathers)
check("and the line is read again", path.line.skill == 45)

-- Classic picked.
local classic = Road:Path("ore", "classic")
check("Classic keeps the ladder", classic.pick == "classic" and classic.stops[1].node == "Copper Vein"
    and classic.stops[2].node == "Tin Vein" and classic.stops[#classic.stops].to == 300)
check("a node you gathered names its zone", classic.stops[1].zone == "Elwynn Forest"
    and classic.stops[2].zone == nil)
check("all done at the cap", RoadUI.NoteText(classic) == "All done here.")

-- A line not learned yet.
local cata = Road:Path("ore", "cataclysm")
check("one to learn says so", cata.learn and RoadUI.NoteText(cata) == "Learn Cataclysm Mining at a trainer first.")

-- Midnight, learned from the window.
check("no Midnight line before the window", Road:LineID("Mining", Road.Expansion("midnight")) == nil)
lines[2900] = { 12, 100, 186 }
Road:ReadWindow()
check("the newest line is Midnight's", Road:LineID("Mining", Road.Expansion("midnight")) == 2900)
local midnight = Road:Path("ore", "midnight")
check("and read", midnight.line and midnight.line.skill == 12 and midnight.line.most == 100)
check("its zones", midnight.stops[1].zone == "Eversong Woods")

-- A profession window that reads a new skill moves a road already drawn.
do
    local saved = lines[2570]
    lines[2570] = { 41, 75, 186 }
    Road:ReadWindow()
    local before = Road:Path("ore", "northrend")
    lines[2570] = { 60, 75, 186 }
    Road:ReadWindow()
    lines[2570] = { 0, 0, 186 }
    local after = Road:Path("ore", "northrend")
    check("a window's new skill shows on the road", before.line and before.line.skill == 41
        and after.line and after.line.skill == 60, after.line and after.line.skill)
    lines[2570] = saved
    Road:ReadWindow()
end

-- Kept when the client will not say.
_G.C_TradeSkillUI.GetProfessionInfoBySkillLineID = function() return nil end
ns.GrindGather.paceVersion = ns.GrindGather.paceVersion + 1
path = Road:Path("ore")
check("kept per character", path.expansions[3].skill == 45 and path.expansions[12].skill == 12)
_G.C_TradeSkillUI.GetProfessionInfoBySkillLineID = Info

-- Skinning counts skins.
ns.GrindGather:NoteSkin("Rhino", "Creature-1", { "Borean Leather" }, { ["Borean Leather"] = 2 })
ns.GrindGather:NoteSkin("Rhino", "Creature-1", { "Borean Leather" }, { ["Borean Leather"] = 2 })
_, mine = Road:Store()
check("a skin counts once", mine.pace["Skinning|northrend"] and mine.pace["Skinning|northrend"].gathers == 1)
local skin = Road:Path("skinning", "classic")
check("Classic Skinning by beast levels", skin.stops[1].low == 1 and skin.stops[1].high == 15
    and RoadUI.TitleText(skin, skin.stops[1]) == "Beasts level 1 to 15")

check("a profession you lack has no road", Road:Path("herbs") == nil)

--------------------------------------------------------------------------------
-- The words
--------------------------------------------------------------------------------

path = Road:Path("ore")
now = path.stops[path.current]
check("the road's heading", RoadUI.RoadText(path) == "YOUR MINING ROAD")
check("the heading", RoadUI.HeadingText(path) == "NORTHREND MINING 45 / 75", RoadUI.HeadingText(path))
check("a zone stop", RoadUI.TitleText(path, now) == "Ore in Howling Fjord")
check("a tile's numbers", RoadUI.TileNumbers(path.expansions[3]) == "45 / 75")
check("the line under the one you're on", RoadUI.SubText(now)
    == ("About %d more gathers."):format(now.gathers), RoadUI.SubText(now))

--------------------------------------------------------------------------------
-- The Grind tab
--------------------------------------------------------------------------------

ns.HandleSlash("grind ore")
check("the road shows on Ore", RoadUI.frame:IsShown() and GrindingUI.pathRoom > 0)
check("its words", RoadUI.roadHead:GetText() == "YOUR MINING ROAD" and RoadUI.note:GetText() == "Road to max"
    and RoadUI.head:GetText() == "NORTHREND MINING 45 / 75")
check("a tile an expansion", RoadUI.tiles[12] and RoadUI.tiles[12]:IsShown())
check("the one you stand in has the gold edge", RoadUI.tiles[3].active:IsShown() and not RoadUI.tiles[1].active:IsShown())
check("done ones have the check", RoadUI.tiles[1].check:IsShown() and not RoadUI.tiles[3].check:IsShown())
local rows = RoadUI.rows
local lit
for _, row in ipairs(rows) do if row:IsShown() and row.stop.state == "now" then lit = row end end
check("the one you're on has Show the Way", lit and lit.button:IsShown())
check("Set Goal shows", RoadUI.goalButton:IsShown())

local aimed
ns.Arrow.Grind = function(_, camp) aimed = camp return true end
lit.button:GetScript("OnClick")(lit.button, "LeftButton")
check("Show the Way aims the arrow there", aimed and aimed.zone == "Howling Fjord")

local set
ns.Goals.Set = function(_, name, amount)
    set = { name, amount }
    return { item = name, target = amount, have = 0 }
end
ns.GoalsUI.Show = function() end
RoadUI.goalButton:GetScript("OnClick")(RoadUI.goalButton, "LeftButton")
check("Set Goal asks for the item", set and set[1] == "Cobalt Ore" and set[2] >= 20)

RoadUI.tiles[1]:GetScript("OnClick")(RoadUI.tiles[1], "LeftButton")
GrindingUI:Render()
check("a tile opens its expansion", RoadUI.head:GetText() == "CLASSIC MINING 300 / 300"
    and RoadUI.message:IsShown() and RoadUI.message:GetText() == "All done here.")
check("nothing to gather there, no Set Goal", not RoadUI.goalButton:IsShown())

ns.HandleSlash("grind cloth")
check("the mob views have none", not RoadUI.frame:IsShown() and GrindingUI.pathRoom == 0)

professions = { "Skinning" }
ns.Spots.ForgetSkills()
ns.HandleSlash("grind ore")
check("a profession you lack shows nothing", not RoadUI.frame:IsShown())

--------------------------------------------------------------------------------
-- Every window shut (seen in game, 2026-10-24): Retail gives 0 of 0 for
-- each line by its ID until a profession window opens, but the
-- Professions book's numbers (GetProfessionInfo) are there.
--------------------------------------------------------------------------------

local book = {
    { "Herbalism", 65, 300, 182, "Classic Herbalism" },
    { "Skinning", 42, 300, 393, "Classic Skinning" },
}
_G.GetProfessionInfo = function(index)
    local each = book[index]
    if each then return each[1], 0, each[2], each[3], 0, 0, each[4], 0, nil, nil, each[5] end
end
ns.Spots.ForgetSkills()
local names = { [2556] = "Classic Herbalism", [2564] = "Classic Skinning", [2555] = "Outland Herbalism" }
_G.C_TradeSkillUI = {
    GetProfessionInfoBySkillLineID = function(id)
        return { skillLevel = 0, maxSkillLevel = 0, professionName = names[id] or "" }
    end,
}
env.world.zone, env.world.mapID = "Teldrassil", 57
ns.db.gathering.nodes["Teldrassil||Peacebloom"] = { zone = "Teldrassil", node = "Peacebloom", kind = "herb",
    gathers = 29, items = { Peacebloom = { gathers = 29, count = 40, id = 2447 } } }
ns.db.gathering.nodes["Teldrassil||Mageroyal"] = { zone = "Teldrassil", node = "Mageroyal", kind = "herb",
    gathers = 7, items = { Mageroyal = { gathers = 7, count = 9, id = 785 } } }
-- Herbs picked off a Timberling's corpse before it was told apart, and one
-- marked when gathered.
ns.db.tracker = ns.db.tracker or {}
ns.db.tracker.mobs = ns.db.tracker.mobs or {}
ns.db.tracker.mobs.Timberling = { kills = 30 }
ns.db.gathering.nodes["Teldrassil||Timberling"] = { zone = "Teldrassil", node = "Timberling", kind = "herb",
    gathers = 22, items = { Mageroyal = { gathers = 22, count = 30, id = 785 } } }
ns.db.gathering.nodes["Teldrassil||Timberling Trampler"] = { zone = "Teldrassil", node = "Timberling Trampler",
    kind = "herb", creature = true, gathers = 3, items = { ["Broken Vine"] = { gathers = 3, count = 3 } } }
ns.GrindGather.paceVersion = ns.GrindGather.paceVersion + 1

local herbs = Road:Path("herbs", "classic")
check("Classic Herbalism read from the book", herbs.expansions[1].skill == 65 and herbs.expansions[1].most == 300
    and herbs.line.skill == 65, herbs.expansions[1].skill)
check("the others not learned read 0", herbs.expansions[2].skill == 0 and herbs.expansions[11].skill == 0)
check("Midnight shows numbers too", herbs.expansions[12].skill == 0 and herbs.expansions[12].most == 100)
local herbNow = herbs.stops[herbs.current]
check("past Peacebloom at 65", herbs.stops[1].state == "done" and herbNow.node == "Mageroyal"
    and herbNow.from == 50 and herbNow.to == 70, herbNow.node)
local skinRoad = Road:Path("skinning", "classic")
check("Classic Skinning read from the book", skinRoad.line and skinRoad.line.skill == 42)

-- A line the book names by its English word when the client gives no name.
names = {}
book[1][2], book[1][5] = 12, "Khaz Algar Herbalism"
herbs = Road:Path("herbs", "khazalgar")
check("a line by its English word", herbs.expansions[11].skill == 12 and herbs.expansions[1].skill == 65)
book[1][2], book[1][5] = 3, "Midnight Herbalism"
herbs = Road:Path("herbs", "midnight")
check("Midnight from the book before a window names it", herbs.expansions[12].skill == 3
    and herbs.line.skill == 3)

-- The window's own list of a profession's lines.
_G.C_TradeSkillUI.GetChildProfessionInfos = function()
    return { { professionID = 2550, skillLevel = 31, maxSkillLevel = 100, parentProfessionID = 182 } }
end
Road:ReadWindow()
herbs = Road:Path("herbs", "legion")
check("a window's lines are kept", herbs.expansions[7].skill == 31 and herbs.expansions[7].most == 100)
_G.C_TradeSkillUI.GetChildProfessionInfos = nil

-- Corpses are not nodes.
local zones = ns.GrindGather:Zones("herbs", 1, 90)
local listed = {}
for _, zone in ipairs(zones) do
    for _, node in ipairs(zone.nodes) do listed[node.name] = true end
end
check("herb nodes are listed", listed.Peacebloom and listed.Mageroyal)
check("a mob you killed is not a herb", not listed.Timberling)
check("a gather marked off a corpse is not a herb", not listed["Timberling Trampler"])
check("a herb is not a mob", not ns.Gathering:FromCreature(ns.db.gathering.nodes["Teldrassil||Peacebloom"]))

-- A corpse's loot window is told apart from a node's.
local sources = {}
_G.GetNumLootItems = function() return #sources end
_G.GetLootSourceInfo = function(slot) return sources[slot], 1 end
sources = { "Creature-0-1-2-3-3416-0001" }
check("a corpse's window", ns.Gathering.CorpseWindow() == true)
sources = { "GameObject-0-1-2-3-1617-0001" }
check("a node's window", ns.Gathering.CorpseWindow() == false)
_G.GetNumLootItems, _G.GetLootSourceInfo = nil, nil

-- The suites share one Lua: leave the client as it was.
_G.GetProfessions, _G.GetProfessionInfo, _G.C_TradeSkillUI = nil, nil, nil
_G.C_Map.GetMapInfo = nil

suite.done()
