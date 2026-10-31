-- Beacons on Retail nodes.
--
-- What matters: Retail ships no herb or ore list, so a herb or vein the
-- player never gathered is told by the game's own tooltip naming Herbalism
-- or Mining, in the client's own words (the Professions book's name too); a
-- game object whose tooltip names neither, a creature, or a hidden node gets
-- nothing; the check says what the tooltip gave.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("retailsparkle")

local ns = env.Load({ ui = true, retail = true })
local NodeSparkle = ns.NodeSparkle

_G.C_CVar = { GetCVar = function() return "3" end, SetCVar = function() return true end }
_G.InCombatLockdown = function() return false end

local facing = {}
local plate = CreateFrame("Frame")
local realName, realGuid = _G.UnitName, _G.UnitGUID
_G.UnitName = function(unit)
    if unit == "softinteract" then return facing.name end
    return realName(unit)
end
_G.UnitGUID = function(unit)
    if unit == "softinteract" then return facing.guid end
    return realGuid(unit)
end
_G.C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        if unit == "softinteract" and facing.guid then return plate end
        return nil
    end,
}
local tipLines
_G.C_TooltipInfo = { GetUnit = function(unit)
    if unit == "softinteract" and tipLines then return { lines = tipLines } end
    return nil
end }

local serial = 0
local function Face(name, lines, guid)
    serial = serial + 1
    facing = { name = name, guid = guid or ("GameObject-0-1-2-3-414000-0000" .. serial) }
    tipLines = lines
    return NodeSparkle:SafeRefresh()
end

suite.check("no shipped node list on Retail", not NodeSparkle:IsNode("Mycobloom"))
suite.check("a herb never gathered and no tooltip gets nothing", Face("Mycobloom", nil) == "notnode")
suite.check("a herb whose tooltip names Herbalism shows",
    Face("Mycobloom", { { leftText = "Mycobloom" }, { leftText = "Herbalism" } }) == "shown")
suite.check("and the beacon is up", NodeSparkle.frame and NodeSparkle.frame:IsShown())
suite.check("an expansion's skill name counts",
    Face("Bismuth", { { leftText = "Bismuth" }, { leftText = "Khaz Algar Mining" } }) == "shown")
suite.check("so does Requires Mining",
    Face("Rich Bismuth", { { leftText = "Rich Bismuth" }, { leftText = "Requires Mining" } }) == "shown")
suite.check("a mailbox does not",
    Face("Mailbox", { { leftText = "Mailbox" } }) == "notnode")
suite.check("the name line alone never counts",
    Face("Mining Cart", { { leftText = "Mining Cart" } }) == "notnode")
suite.check("a creature does not",
    Face("Mining Golem", { { leftText = "Mining Golem" }, { leftText = "Mining" } },
        "Creature-0-1-2-3-6-0000000001") == "nothing")

ns.DB:Hide("source", "Mycobloom")
suite.check("a hidden node does not",
    Face("Mycobloom", { { leftText = "Mycobloom" }, { leftText = "Herbalism" } }) == "notnode")
ns.DB:Unhide("source", "Mycobloom")

-- A German client: the Professions book names the skill.
_G.GetProfessions = function() return 1, nil end
_G.GetProfessionInfo = function(index)
    if index == 1 then return "Kräuterkunde", 0, 50, 100, 0, 0, 182 end
end
suite.check("the book's name counts (German)",
    Face("Mykoblüte", { { leftText = "Mykoblüte" }, { leftText = "Khaz Algar-Kräuterkunde" } }) == "shown")
suite.check("a node shows gold with Sparkle Colors on", NodeSparkle:ColorFor("node", "Mykoblüte") == NodeSparkle.GOLD)
_G.GetProfessions, _G.GetProfessionInfo = nil, nil

Face("Mycobloom", { { leftText = "Mycobloom" }, { leftText = "Herbalism" } })
ns.HandleSlash("sparkle check")
local said = false
for _, line in ipairs(ns.db.lastProbe and ns.db.lastProbe.lines or {}) do
    if line:find("tooltip names a gathering skill: yes", 1, true) then said = true end
end
suite.check("the check says what the tooltip gave", said)

suite.done()
