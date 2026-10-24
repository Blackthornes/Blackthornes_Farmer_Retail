-- Blackthornes Farmer -- Logic/RoadToMax.lua
-- Road to max, Retail's Gather to cap (the owner approved the mockup and
-- its words, 2026-10-24): on the Grind tab's Ore, Herbs and Leather views,
-- the whole road from level 1 to endgame. Retail gives each expansion its
-- own Mining, Herbalism and Skinning with its own cap, so the road is the
-- twelve expansions in order, Classic to Midnight, each with your skill in
-- it, and under it the stops for the one picked.
--
-- Retail only: the Retail TOC loads it in place of Logic/GatherToCap.lua,
-- which keeps Classic's 1 to 300 ladder for Forever.
--
-- - Your skill in each expansion's line is the client's
--   (C_TradeSkillUI.GetProfessionInfoBySkillLineID, by the line IDs in
--   EXPANSIONS), kept per character by GUID in `roadToMax[guid].lines`
--   when the client says, so a line it will not read now still shows what
--   it said last. Midnight's line ID is not in the table: it is learned
--   when a profession window opens (`roadToMax.newest[profession]`, the
--   one line newer than every one known).
-- - The expansion lit gold is the one you stand in (by the continent of
--   the map you are on, else the zone's name), else the first one you have
--   started and not finished, else Midnight.
-- - Classic's stops are Forever's ladder (Copper Vein at 1, Tin Vein at 65
--   and on; Skinning by bands of beast levels). The other expansions let
--   you gather their nodes from the start, so their stops are four steps of
--   the cap, each in one of the expansion's zones: the one you are on in
--   the zone where you gathered most there, else the zone you stand in.
-- - "About N more gathers" is your own rate in that line: gathers against
--   the skill points they gave (`roadToMax[guid].pace["Mining|outland"]`),
--   once MIN_SAMPLE gathers are behind it.
--
-- Only your own play is read: your gathers and spots (gathering.nodes,
-- gathering.spots, gathering.pace) and skins; guild and shipped data never
-- reach it. Hidden nodes and items are left out. Nothing runs on a timer:
-- the Grind tab asks when it draws, and the road is laid out again only
-- when something it reads moves (Key).

local _, ns = ...
local L = ns.L

local RoadToMax = ns.NewModule("RoadToMax")

-- Gathers counted before "About N more gathers" shows.
RoadToMax.MIN_SAMPLE = 20
-- A goal asks for at least this many.
RoadToMax.MIN_GOAL = 20
-- Steps on the road of an expansion with no ladder.
RoadToMax.STEPS = 4
-- A profession window sends its list in bursts: read it once they settle.
RoadToMax.SETTLE = 0.5

-- The professions, by the Grind tab's view: the English name, Gathering's
-- node kind, the word a zone stop starts with and the parent skill line.
RoadToMax.VIEWS = {
    ore = { skill = "Mining", kind = "ore" },
    herbs = { skill = "Herbalism", kind = "herb" },
    skinning = { skill = "Skinning" },
}
RoadToMax.PARENTS = { [186] = "Mining", [182] = "Herbalism", [393] = "Skinning" }

-- The expansions, in the order you play them: the cap the client gives
-- when it will not say, the zones (English, in the order you level
-- through them; the first STEPS are the stops), the continents' map IDs,
-- and each profession's skill line ID. Not yet seen in game.
RoadToMax.EXPANSIONS = {
    { key = "classic", cap = 300, continents = { 12, 13 },
        lines = { Mining = 2572, Herbalism = 2556, Skinning = 2564 }, zones = {} },
    { key = "outland", cap = 75, continents = { 101 },
        lines = { Mining = 2571, Herbalism = 2555, Skinning = 2563 },
        zones = { "Hellfire Peninsula", "Zangarmarsh", "Terokkar Forest", "Nagrand",
            "Blade's Edge Mountains", "Netherstorm", "Shadowmoon Valley" } },
    { key = "northrend", cap = 75, continents = { 113 },
        lines = { Mining = 2570, Herbalism = 2554, Skinning = 2562 },
        zones = { "Borean Tundra", "Howling Fjord", "Sholazar Basin", "The Storm Peaks",
            "Dragonblight", "Grizzly Hills", "Zul'Drak", "Icecrown", "Crystalsong Forest" } },
    { key = "cataclysm", cap = 75, continents = { 948 },
        lines = { Mining = 2569, Herbalism = 2553, Skinning = 2561 },
        zones = { "Mount Hyjal", "Deepholm", "Uldum", "Twilight Highlands",
            "Kelp'thar Forest", "Shimmering Expanse", "Abyssal Depths", "Tol Barad Peninsula" } },
    { key = "pandaria", cap = 75, continents = { 424 },
        lines = { Mining = 2568, Herbalism = 2552, Skinning = 2560 },
        zones = { "The Jade Forest", "Valley of the Four Winds", "Kun-Lai Summit", "Townlong Steppes",
            "Krasarang Wilds", "Dread Wastes", "Vale of Eternal Blossoms" } },
    { key = "draenor", cap = 100, continents = { 572 },
        lines = { Mining = 2567, Herbalism = 2551, Skinning = 2559 },
        zones = { "Frostfire Ridge", "Gorgrond", "Talador", "Spires of Arak", "Tanaan Jungle" } },
    { key = "legion", cap = 100, continents = { 619 },
        lines = { Mining = 2566, Herbalism = 2550, Skinning = 2558 },
        zones = { "Azsuna", "Val'sharah", "Highmountain", "Stormheim", "Suramar", "Broken Shore" } },
    { key = "bfa", cap = 175, continents = { 875, 876 },
        lines = { Mining = 2565, Herbalism = 2549, Skinning = 2557 },
        zones = { "Tiragarde Sound", "Drustvar", "Zuldazar", "Nazmir", "Stormsong Valley", "Vol'dun" } },
    { key = "shadowlands", cap = 150, continents = { 1550 },
        lines = { Mining = 2761, Herbalism = 2760, Skinning = 2762 },
        zones = { "Bastion", "Maldraxxus", "Ardenweald", "Revendreth", "The Maw", "Zereth Mortis" } },
    { key = "dragonisles", cap = 100, continents = { 1978 },
        lines = { Mining = 2833, Herbalism = 2832, Skinning = 2834 },
        zones = { "The Waking Shores", "Ohn'ahran Plains", "The Azure Span", "Thaldraszus",
            "The Forbidden Reach", "Zaralek Cavern", "Emerald Dream" } },
    { key = "khazalgar", cap = 100, continents = { 2274 },
        lines = { Mining = 2881, Herbalism = 2877, Skinning = 2882 },
        zones = { "Isle of Dorn", "The Ringing Deeps", "Hallowfall", "Azj-Kahet", "Siren Isle", "Undermine" } },
    { key = "midnight", cap = 100, continents = {}, lines = {},
        zones = { "Eversong Woods", "Zul'Aman", "Harandar", "Voidstorm", "Isle of Quel'Danas",
            "Silvermoon City" } },
}
-- Draenor's Nagrand and Shadowmoon Valley share their names with
-- Outland's, so by name they read as Outland; by the map you stand on they
-- read as Draenor. Kept out of Draenor's list for that.
RoadToMax.DRAENOR_TOO = { "Nagrand", "Shadowmoon Valley" }

-- Classic's ladders, as Forever's Gather to cap has them.
RoadToMax.CLASSIC = {
    Mining = {
        { node = "Copper Vein", item = "Copper Ore", skill = 1 },
        { node = "Tin Vein", item = "Tin Ore", skill = 65 },
        { node = "Iron Deposit", item = "Iron Ore", skill = 125 },
        { node = "Mithril Deposit", item = "Mithril Ore", skill = 175 },
        { node = "Small Thorium Vein", item = "Thorium Ore", skill = 245 },
        { node = "Rich Thorium Vein", item = "Thorium Ore", skill = 275 },
    },
    Herbalism = {
        { node = "Peacebloom", item = "Peacebloom", skill = 1 },
        { node = "Mageroyal", item = "Mageroyal", skill = 50 },
        { node = "Briarthorn", item = "Briarthorn", skill = 70 },
        { node = "Bruiseweed", item = "Bruiseweed", skill = 100 },
        { node = "Kingsblood", item = "Kingsblood", skill = 125 },
        { node = "Liferoot", item = "Liferoot", skill = 150 },
        { node = "Fadeleaf", item = "Fadeleaf", skill = 160 },
        { node = "Goldthorn", item = "Goldthorn", skill = 170 },
        { node = "Khadgar's Whisker", item = "Khadgar's Whisker", skill = 185 },
        { node = "Purple Lotus", item = "Purple Lotus", skill = 210 },
        { node = "Sungrass", item = "Sungrass", skill = 230 },
        { node = "Golden Sansam", item = "Golden Sansam", skill = 260 },
        { node = "Dreamfoil", item = "Dreamfoil", skill = 270 },
        { node = "Mountain Silversage", item = "Mountain Silversage", skill = 280 },
    },
    Skinning = {
        { skill = 1, low = 1, high = 15, item = "Light Leather" },
        { skill = 50, low = 15, high = 20, item = "Light Leather" },
        { skill = 100, low = 20, high = 30, item = "Medium Leather" },
        { skill = 150, low = 30, high = 40, item = "Heavy Leather" },
        { skill = 200, low = 40, high = 50, item = "Thick Leather" },
        { skill = 250, low = 50, high = 60, item = "Rugged Leather" },
    },
}

local function Number(value)
    return ns.Harvest and ns.Harvest.ReadableNumber(value) or tonumber(value)
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function Field(info, key)
    local ok, value = pcall(function() return info[key] end)
    if ok then return value end
    return nil
end

--------------------------------------------------------------------------------
-- Words
--------------------------------------------------------------------------------

--- The expansion's name as players read it.
function RoadToMax.ExpansionLabel(key)
    local words = {
        classic = L["Classic"], outland = L["Outland"], northrend = L["Northrend"],
        cataclysm = L["Cataclysm"], pandaria = L["Pandaria"], draenor = L["Draenor"],
        legion = L["Legion"], bfa = L["Kul Tiras and Zandalar"], shadowlands = L["Shadowlands"],
        dragonisles = L["Dragon Isles"], khazalgar = L["Khaz Algar"], midnight = L["Midnight"],
    }
    return words[key] or key
end

--- The profession's name as players read it.
function RoadToMax.SkillLabel(english)
    local words = { Mining = L["Mining"], Herbalism = L["Herbalism"], Skinning = L["Skinning"] }
    return words[english] or english
end

--------------------------------------------------------------------------------
-- Where things are
--------------------------------------------------------------------------------

local byKey, byZone, byContinent = {}, {}, {}
for index, expansion in ipairs(RoadToMax.EXPANSIONS) do
    expansion.index = index
    byKey[expansion.key] = expansion
    for _, zone in ipairs(expansion.zones) do
        if not byZone[zone] then byZone[zone] = expansion end
    end
    for _, map in ipairs(expansion.continents) do byContinent[map] = expansion end
end
for _, zone in ipairs(RoadToMax.DRAENOR_TOO) do byZone[zone] = byZone[zone] or byKey.outland end

function RoadToMax.Expansion(key) return byKey[key] end

--- The expansion a zone (English name) belongs to, or nil: the lists
--- first, then Forever's zone data, which is Classic's world.
function RoadToMax.ZoneExpansion(zone)
    if type(zone) ~= "string" then return nil end
    zone = ns.Spots.English(zone) or zone
    if byZone[zone] then return byZone[zone] end
    local maps = ns.ZONE_DATA and ns.ZONE_DATA.maps
    if type(maps) == "table" and maps[zone] then return byKey.classic end
    return nil
end

--- The expansion you stand in, or nil when the client will not say. By
--- the zone's name when a list has it (Cataclysm's and Midnight's zones
--- sit on the old continents), else by the continent of the map you are
--- on.
function RoadToMax.Here()
    local zone = ns.Harvest.Readable(Read(GetRealZoneText))
    local named = zone and zone ~= "" and byZone[ns.Spots.English(zone) or zone]

    local continent
    if type(C_Map) == "table" then
        local mapID = Number(Read(C_Map.GetBestMapForUnit, "player"))
        for _ = 1, 8 do
            if not mapID or mapID <= 0 then break end
            if byContinent[mapID] then
                continent = byContinent[mapID]
                break
            end
            local info = type(C_Map.GetMapInfo) == "function" and Read(C_Map.GetMapInfo, mapID)
            if type(info) ~= "table" then break end
            mapID = Number(Field(info, "parentMapID"))
        end
    end

    -- A name shared by two worlds (Nagrand) goes by the map.
    if named and continent and continent ~= named and continent ~= byKey.classic then return continent end
    if named and named ~= byKey.classic then return named end
    return continent or named or nil
end

--------------------------------------------------------------------------------
-- Your skill in each line
--------------------------------------------------------------------------------

--- This account's store, and this character's part of it (nil when the
--- client will not say who is playing).
function RoadToMax:Store()
    local db = ns.db
    if type(db.roadToMax) ~= "table" then db.roadToMax = {} end
    local store = db.roadToMax
    if type(store.newest) ~= "table" then store.newest = {} end
    local guid = ns.Goals and ns.Goals:Owner()
    if not guid then return store, nil end
    local mine = store[guid]
    if type(mine) ~= "table" then
        mine = {}
        store[guid] = mine
    end
    if type(mine.lines) ~= "table" then mine.lines = {} end
    if type(mine.pace) ~= "table" then mine.pace = {} end
    return store, mine
end

--- The skill line ID of `english` in `expansion`, or nil.
function RoadToMax:LineID(english, expansion)
    local id = expansion.lines[english]
    if id then return id end
    if expansion.key == "midnight" then
        local store = self:Store()
        return tonumber(store.newest[english])
    end
    return nil
end

--- What the client says of one skill line: skill, cap and the parent
--- profession's English name, or nil.
function RoadToMax.ReadLine(id)
    local trade = type(C_TradeSkillUI) == "table" and C_TradeSkillUI or nil
    local info = trade and Read(trade.GetProfessionInfoBySkillLineID, id)
    if type(info) ~= "table" then return nil end
    local skill = Number(Field(info, "skillLevel"))
    local most = Number(Field(info, "maxSkillLevel"))
    local parent = RoadToMax.PARENTS[Number(Field(info, "parentProfessionID")) or 0]
    if not skill then return nil end
    return skill, most, parent
end

--- Your skill and cap in `english` for `expansion`: { skill, most } with
--- skill 0 for a line not learned, or nil when nothing says.
function RoadToMax:Skill(english, expansion)
    local id = self:LineID(english, expansion)
    if not id then return nil end
    local _, mine = self:Store()
    local skill, most, parent = RoadToMax.ReadLine(id)
    if skill and (parent == nil or parent == english) and (skill > 0 or (most or 0) > 0) then
        local cap = most and most > 0 and most or expansion.cap
        if mine then
            local kept = mine.lines[id]
            if type(kept) ~= "table" or kept.skill ~= skill or kept.most ~= cap then
                mine.lines[id] = { skill = skill, most = cap }
                RoadToMax.version = (RoadToMax.version or 0) + 1
            end
        end
        return { skill = skill, most = cap }
    end
    local kept = mine and mine.lines[id]
    if type(kept) == "table" and tonumber(kept.skill) then
        return { skill = tonumber(kept.skill), most = tonumber(kept.most) or expansion.cap }
    end
    if skill then return { skill = 0, most = expansion.cap } end
    return nil
end

--- A profession window is open: note what it says of every line it lists,
--- and learn the newest line's ID (Midnight's).
function RoadToMax:ReadWindow()
    local trade = type(C_TradeSkillUI) == "table" and C_TradeSkillUI or nil
    local ids = trade and Read(trade.GetAllProfessionTradeSkillLines)
    if type(ids) ~= "table" then return end
    local store, mine = self:Store()
    for _, raw in ipairs(ids) do
        local id = Number(raw)
        local skill, most, parent
        if id then skill, most, parent = RoadToMax.ReadLine(id) end
        if skill and parent then
            local known = false
            local highest = 0
            for _, expansion in ipairs(RoadToMax.EXPANSIONS) do
                local line = expansion.lines[parent]
                if line == id then known = true end
                if line and line > highest then highest = line end
            end
            if not known and id > highest and (tonumber(store.newest[parent]) or 0) < id then
                store.newest[parent] = id
                RoadToMax.version = (RoadToMax.version or 0) + 1
            end
            if mine then mine.lines[id] = { skill = skill, most = most and most > 0 and most or nil } end
        end
    end
end

--------------------------------------------------------------------------------
-- Your own rate
--------------------------------------------------------------------------------

--- One gather (or skin) in `english` where you stand: counted against the
--- line of that expansion, with any points the line went up since the
--- last one.
function RoadToMax:Gathered(english, zone)
    local expansion = RoadToMax.Here() or RoadToMax.ZoneExpansion(zone)
    if not expansion then return end
    local _, mine = self:Store()
    if not mine then return end
    local now = self:Skill(english, expansion)
    local key = english .. "|" .. expansion.key
    local pace = mine.pace[key]
    if type(pace) ~= "table" then
        pace = { gathers = 0, points = 0 }
        mine.pace[key] = pace
    end
    pace.gathers = (tonumber(pace.gathers) or 0) + 1
    if now then
        local last = tonumber(pace.last)
        if last and now.skill > last then pace.points = (tonumber(pace.points) or 0) + (now.skill - last) end
        pace.last = now.skill
    end
    RoadToMax.version = (RoadToMax.version or 0) + 1
end

--- About how many gathers take you `points` further in `english` in
--- `expansion`, at your own rate; nil until MIN_SAMPLE are behind it.
function RoadToMax:GathersFor(english, expansion, points)
    local _, mine = self:Store()
    local pace = mine and mine.pace[english .. "|" .. expansion.key]
    if type(pace) ~= "table" then return nil end
    local gathers, gained = tonumber(pace.gathers) or 0, tonumber(pace.points) or 0
    if gathers < RoadToMax.MIN_SAMPLE or gained <= 0 or points <= 0 then return nil end
    return math.ceil(points * gathers / gained - 1e-9)
end

--------------------------------------------------------------------------------
-- What you gathered where
--------------------------------------------------------------------------------

local function ZoneOfMap(mapID)
    local zone = ns.Spots.MAP_ZONES[mapID]
    if zone then return zone end
    local info = type(C_Map) == "table" and Read(C_Map.GetMapInfo, mapID)
    local name = type(info) == "table" and ns.Harvest.Readable(Field(info, "name")) or nil
    return name and (ns.Spots.English(name) or name) or nil
end

--- Your gathering of `kind` by zone: { [zone] = { gathers, nodes =
--- { [node] = gathers }, items = { [name] = { count, id } }, spots =
--- { [node] = { list } } } }.
local function OwnGathering(kind)
    local found = {}
    local gathering = ns.db and type(ns.db.gathering) == "table" and ns.db.gathering or {}
    local function Zone(zone)
        local entry = found[zone]
        if not entry then
            entry = { gathers = 0, nodes = {}, items = {}, spots = {}, spotCount = 0 }
            found[zone] = entry
        end
        return entry
    end
    for _, node in pairs(type(gathering.nodes) == "table" and gathering.nodes or {}) do
        if type(node) == "table" and type(node.zone) == "string" and type(node.node) == "string"
            and node.kind == kind and not ns.DB:HidesSource(node.node) then
            local zone = ns.Spots.English(node.zone) or node.zone
            local entry = Zone(zone)
            local gathers = tonumber(node.gathers) or 0
            entry.gathers = entry.gathers + gathers
            entry.nodes[node.node] = (entry.nodes[node.node] or 0) + gathers
            for name, item in pairs(type(node.items) == "table" and node.items or {}) do
                if type(item) == "table" and not ns.DB:IsHiddenItem(name) then
                    local kept = entry.items[name] or { count = 0 }
                    kept.count = kept.count + (tonumber(item.count) or 0)
                    kept.id = kept.id or tonumber(item.id)
                    entry.items[name] = kept
                end
            end
        end
    end
    for _, spot in ipairs(type(gathering.spots) == "table" and gathering.spots or {}) do
        if type(spot) == "table" and type(spot.node) == "string" and (spot.kind == nil or spot.kind == kind) then
            local zone = ZoneOfMap(spot.map)
            if zone then
                local entry = Zone(zone)
                local list = entry.spots[spot.node] or {}
                if tonumber(spot.x) and tonumber(spot.y) then
                    list[#list + 1] = { spot.x * 100, spot.y * 100, map = spot.map }
                end
                entry.spots[spot.node] = list
                entry.spotCount = entry.spotCount + 1
            end
        end
    end
    return found
end

--- Your skins by zone: { [zone] = { gathers, items } }, from the record of
--- each skinned mob's zone (Harvest's records name it).
local function OwnSkins()
    local found = {}
    local log = ns.db and type(ns.db.skinLog) == "table" and ns.db.skinLog or {}
    local zones = {}
    for _, record in pairs(ns.Harvest and ns.Harvest.records or {}) do
        if type(record) == "table" and record.mob and record.zone then
            local seen = zones[record.mob]
            if not seen or (tonumber(record.corpses) or 0) > seen.corpses then
                zones[record.mob] = { zone = record.zone, corpses = tonumber(record.corpses) or 0 }
            end
        end
    end
    for mob, entry in pairs(log) do
        local where = zones[mob]
        if type(entry) == "table" and where and not ns.DB:HidesSource(mob) then
            local zone = ns.Spots.English(where.zone) or where.zone
            local kept = found[zone] or { gathers = 0, items = {}, nodes = {}, spots = {}, spotCount = 0 }
            kept.gathers = kept.gathers + (tonumber(entry.skins) or 0)
            kept.nodes[mob] = (kept.nodes[mob] or 0) + (tonumber(entry.skins) or 0)
            for name, count in pairs(type(entry.items) == "table" and entry.items or {}) do
                if not ns.DB:IsHiddenItem(name) then
                    local item = kept.items[name] or { count = 0 }
                    item.count = item.count + (tonumber(count) or 0)
                    kept.items[name] = item
                end
            end
            found[zone] = kept
        end
    end
    return found
end

--- The item you got most of in `entry`, with its ID, or nil.
local function MainItem(entry)
    local best, bestCount, bestID
    for name, item in pairs(entry and entry.items or {}) do
        if not best or item.count > bestCount or (item.count == bestCount and name < best) then
            best, bestCount, bestID = name, item.count, item.id
        end
    end
    return best, bestID
end

--- What an hour in `zone` is worth from your own gathering of `entry`'s
--- nodes there, once GrindGather.MIN_SECONDS are behind it; nil before.
local function HourWorth(zone, entry, onlyNode)
    local pace = ns.db and type(ns.db.gathering) == "table" and type(ns.db.gathering.pace) == "table"
        and ns.db.gathering.pace or {}
    -- Retail ships no item data, so the IDs come from your own records.
    local ids = {}
    for name, item in pairs(entry and entry.items or {}) do ids[name] = item.id end
    local seconds, copper, priced = 0, 0, false
    for node in pairs(entry and entry.nodes or {}) do
        if not onlyNode or node == onlyNode then
            local kept = pace[ns.GrindGather.Key(zone, node)]
            if type(kept) == "table" and tonumber(kept.seconds) then
                seconds = seconds + kept.seconds
                local worth, any = ns.GrindGather.Worth(kept.items, ids)
                copper = copper + worth
                priced = priced or any
            end
        end
    end
    if seconds < ns.GrindGather.MIN_SECONDS or not priced then return nil end
    return math.floor(copper * 3600 / seconds + 0.5)
end

local function AllSpots(entry, onlyNode)
    local list = {}
    for node, spots in pairs(entry and entry.spots or {}) do
        if not onlyNode or node == onlyNode then
            for _, coords in ipairs(spots) do list[#list + 1] = coords end
        end
    end
    return list
end

--------------------------------------------------------------------------------
-- The stops
--------------------------------------------------------------------------------

--- Classic's stops for Mining or Herbalism: Forever's ladder, each in the
--- zone where you gathered that node most (none when you never did).
local function ClassicNodeStops(english, own)
    local stops = {}
    for _, step in ipairs(RoadToMax.CLASSIC[english]) do
        if not ns.DB:HidesSource(step.node) and not ns.DB:IsHiddenItem(step.item) then
            local zone, most
            for name, entry in pairs(own) do
                local count = entry.nodes[step.node]
                if count and (not most or count > most or (count == most and name < zone)) then
                    zone, most = name, count
                end
            end
            local entry = zone and own[zone]
            local spots = AllSpots(entry, step.node)
            local id = entry and entry.items[step.item] and entry.items[step.item].id
            stops[#stops + 1] = {
                node = step.node, item = step.item, itemID = id, from = step.skill, zone = zone,
                gathered = most ~= nil, spots = #spots, spotList = spots,
                perHour = zone and HourWorth(zone, entry, step.node) or nil,
            }
        end
    end
    return stops
end

--- Classic's stops for Skinning: bands of beast levels.
local function ClassicSkinStops()
    local stops = {}
    for _, step in ipairs(RoadToMax.CLASSIC.Skinning) do
        if not ns.DB:IsHiddenItem(step.item) then
            stops[#stops + 1] = { low = step.low, high = step.high, item = step.item, from = step.skill,
                spots = 0, spotList = {} }
        end
    end
    return stops
end

--- An expansion's stops: STEPS steps of its cap, each in one of its zones.
local function ZoneStops(expansion, most)
    local stops = {}
    local step = most / RoadToMax.STEPS
    for index = 1, RoadToMax.STEPS do
        local zone = expansion.zones[index]
        if not zone then break end
        stops[index] = { zone = zone, from = math.floor((index - 1) * step + 0.5) }
    end
    return stops
end

local function Fill(stop, own)
    local entry = stop.zone and own[stop.zone]
    stop.gathered = entry ~= nil and entry.gathers > 0
    local spots = AllSpots(entry)
    stop.spots, stop.spotList = #spots, spots
    stop.item, stop.itemID = MainItem(entry)
    stop.perHour = stop.zone and HourWorth(stop.zone, entry) or nil
end

--- What moves the road: your skills, the zone, your gathering, the hide
--- list.
function RoadToMax:Key(view, pick, here)
    local gathering = ns.db and type(ns.db.gathering) == "table" and ns.db.gathering or {}
    local spots = type(gathering.spots) == "table" and #gathering.spots or 0
    return table.concat({ view, pick or "", here or "", spots, ns.GrindGather.paceVersion or 0,
        RoadToMax.version or 0, ns.DB.hiddenVersion or 0 }, ":")
end

--- The road for the Grind tab's view `view` ("ore", "herbs", "skinning")
--- with `pick` (an expansion's key) open, or the one you are on:
--- { english, expansions, now (the key lit gold), pick, line, stops,
--- current } or nil when you lack the profession. Each expansion is
--- { key, skill, most, done, now }, skill nil when nothing says; each stop
--- { node or zone or low/high, from, to, item, itemID, spots, spotList,
--- perHour, gathered, state ("done", "now", "later"), gathers (now only) }.
--- `line` is the picked expansion's { skill, most }, or nil; `learn` says
--- that line is still to learn.
function RoadToMax:Path(view, pick)
    local spec = RoadToMax.VIEWS[view or ""]
    if not spec then return nil end
    local skills = ns.Spots.Skills()
    if type(skills) == "table" and skills[spec.skill] == nil then return nil end

    local hereExp = RoadToMax.Here()
    local hereZone = ns.Harvest.Readable(Read(GetRealZoneText))
    hereZone = hereZone and hereZone ~= "" and (ns.Spots.English(hereZone) or hereZone) or nil

    -- Every line is read each draw, so the key follows the skills.
    local expansions, anyRead = {}, false
    for index, expansion in ipairs(RoadToMax.EXPANSIONS) do
        local read = self:Skill(spec.skill, expansion)
        anyRead = anyRead or read ~= nil
        expansions[index] = {
            key = expansion.key,
            skill = read and read.skill or nil,
            most = read and read.most or expansion.cap,
            done = read ~= nil and read.skill >= (read.most or expansion.cap) and read.skill > 0,
        }
    end

    local now = hereExp and hereExp.key
    if not now then
        for _, each in ipairs(expansions) do
            if each.skill and each.skill > 0 and not each.done then
                now = each.key
                break
            end
        end
    end
    now = now or "midnight"
    for _, each in ipairs(expansions) do each.now = each.key == now end
    pick = pick and byKey[pick] and pick or now

    local key = self:Key(view, pick, hereZone)
    self.kept = self.kept or {}
    local kept = self.kept[view]
    if kept and kept.key == key then return kept.path end

    local expansion = byKey[pick]
    local line = expansions[expansion.index]
    local most = line.most or expansion.cap
    local own = spec.kind and OwnGathering(spec.kind) or OwnSkins()

    local stops
    if pick == "classic" then
        stops = spec.kind and ClassicNodeStops(spec.skill, own) or ClassicSkinStops()
    else
        stops = ZoneStops(expansion, most)
    end

    local skill = line.skill or 0
    local current
    for index, stop in ipairs(stops) do
        stop.to = stops[index + 1] and stops[index + 1].from or most
        if stop.to <= stop.from then stop.to = stop.from + 1 end
        if line.skill and stop.to <= skill then
            stop.state = "done"
        elseif not current then
            stop.state = "now"
            current = index
        else
            stop.state = "later"
        end
    end

    -- The stop you are on goes where you gathered most in this expansion,
    -- else where you stand, when that is one of its zones.
    if current and pick ~= "classic" then
        local best, bestCount
        for _, zone in ipairs(expansion.zones) do
            local entry = own[zone]
            if entry and entry.gathers > 0 and (not best or entry.gathers > bestCount) then
                best, bestCount = zone, entry.gathers
            end
        end
        if not best and hereZone and byZone[hereZone] == expansion then best = hereZone end
        if best then stops[current].zone = best end
    end
    if pick ~= "classic" or not spec.kind then
        for _, stop in ipairs(stops) do
            if stop.zone then Fill(stop, own) end
        end
    end
    if current then
        local stop = stops[current]
        stop.gathers = RoadToMax:GathersFor(spec.skill, expansion, stop.to - math.max(skill, stop.from))
    end

    local path = {
        english = spec.skill, kind = spec.kind, expansions = expansions, now = now, pick = pick,
        line = line.skill and { skill = line.skill, most = most } or nil,
        learn = line.skill == 0 and pick ~= now,
        unread = not anyRead,
        stops = stops, current = current,
    }
    self.kept[view] = { key = key, path = path }
    return path
end

--- The stops a road shows: the last one done, the one you are on and up
--- to `later` after it.
function RoadToMax.Shown(path, later)
    local shown = {}
    if not path then return shown end
    local lastDone
    for index, stop in ipairs(path.stops) do
        if stop.state == "done" then lastDone = index end
    end
    if lastDone then shown[#shown + 1] = path.stops[lastDone] end
    local count = 0
    for _, stop in ipairs(path.stops) do
        if stop.state == "now" then shown[#shown + 1] = stop end
        if stop.state == "later" and count < (later or 3) then
            shown[#shown + 1] = stop
            count = count + 1
        end
    end
    return shown
end

--------------------------------------------------------------------------------
-- What a click does
--------------------------------------------------------------------------------

--- Point the arrow at a stop: your spots there.
function RoadToMax:ShowTheWay(stop)
    if not (stop and stop.zone) then return false end
    local name = stop.node or stop.zone
    local camp = ns.GrindGather.NodeCamp({ name = name, zone = stop.zone, spotList = stop.spotList })
    camp.label = name
    ns.Arrow:Grind(camp)
    ns.Print(stop.node and L.Format("%s in %s", ns.Util.Colored("accent", stop.node), ns.Spots.Show(stop.zone))
        or ns.Util.Colored("accent", ns.Spots.Show(stop.zone)))
    return true
end

--- Make a goal for the stop's item: what you have and as many more as the
--- stop's gathers, at least MIN_GOAL; then open the goals panel.
function RoadToMax:SetGoal(stop)
    if not (stop and stop.item) then return nil end
    local ok, have = pcall(ns.Goals.Have, ns.Goals, stop.item, stop.itemID)
    have = ok and tonumber(have) or 0
    local more = math.max(RoadToMax.MIN_GOAL, stop.gathers or 0)
    local goal, why = ns.Goals:Set(stop.item, have + more)
    if not goal then
        if why then ns.Print(why) end
        return nil, why
    end
    ns.Print(L.Format("goal set: %s %s. You have %d, %d to go.",
        ns.Util.Colored("good", tostring(goal.target)), ns.Util.ColorItemOr("accent", goal.item),
        goal.have or 0, math.max(0, goal.target - (goal.have or 0))))
    if ns.GoalsUI and ns.GoalsUI.Show then ns.GoalsUI:Show() end
    return goal
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

-- Each gather and skin is counted toward your rate. Gathering:Record and
-- GrindGather:NoteSkin are wrapped, not changed, so the shared files stay
-- as Forever has them.
local SKILL_OF_KIND = { ore = "Mining", herb = "Herbalism" }
if ns.Gathering and type(ns.Gathering.Record) == "function" then
    local record = ns.Gathering.Record
    ns.Gathering.Record = function(self, zone, location, node, kind, ...)
        local results = { record(self, zone, location, node, kind, ...) }
        local english = SKILL_OF_KIND[kind]
        if english then pcall(RoadToMax.Gathered, RoadToMax, english, zone) end
        return unpack(results)
    end
end
if ns.GrindGather and type(ns.GrindGather.NoteSkin) == "function" then
    local note = ns.GrindGather.NoteSkin
    ns.GrindGather.NoteSkin = function(self, mob, guid, ...)
        local before = self.skinned and guid and self.skinned[guid]
        local results = { note(self, mob, guid, ...) }
        if not before and type(mob) == "string" and mob ~= "" and not ns.db.harvestPaused then
            pcall(RoadToMax.Gathered, RoadToMax, "Skinning", nil)
        end
        return unpack(results)
    end
end

function RoadToMax:OnEnable()
    local function Soon()
        if self.waiting then return end
        self.waiting = true
        local function Go()
            self.waiting = false
            pcall(self.ReadWindow, self)
        end
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(RoadToMax.SETTLE, Go)
        else
            Go()
        end
    end
    ns.RegisterEvent(self, "TRADE_SKILL_SHOW", Soon)
    ns.RegisterEvent(self, "TRADE_SKILL_LIST_UPDATE", Soon)
    ns.RegisterEvent(self, "SKILL_LINES_CHANGED", function() RoadToMax.version = (RoadToMax.version or 0) + 1 end)
end
