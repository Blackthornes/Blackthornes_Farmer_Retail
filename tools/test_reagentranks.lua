-- Reagents with quality ranks (Retail).
--
-- What matters (the 2026-10-28 bug pass; Trent said fix it): since
-- Dragonflight an ore, herb or leather comes in ranks that share one name
-- but have their own item IDs and prices. Farmer keeps items by name, so it
-- took the first rank it saw for every price and a goal counted only that
-- rank in the bags. Now each rank seen is kept with how often it was looted;
-- a goal counts every rank, a price weighs each rank by your loot, a bag
-- stack keeps its own rank's price, and an item without ranks is as before.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("reagentranks")
local check = suite.check

local ns = env.Load({ retail = true })
local Tracker, Value, Goals = ns.Tracker, ns.Value, ns.Goals

local R1, R2, PLAIN = 210930, 210931, 2770
local ranks = { [R1] = 1, [R2] = 2 }
local asked = 0
_G.C_TradeSkillUI = {
    GetItemReagentQualityByItemInfo = function(id)
        asked = asked + 1
        return ranks[id]
    end,
}

-- Loot each slot once, as a loot window shows it.
local function Loot(slots)
    env.world.loot = slots
    for slot, item in ipairs(slots) do Tracker:NoteLook(slot, item.name, nil) end
end

Loot({ { name = "Bismuth", id = R1 }, { name = "Copper Ore", id = PLAIN } })
check("one rank is no group yet", Tracker:RanksOf("Bismuth") == nil)
check("the first ID is kept as before", Tracker:LookOf("Bismuth").id == R1)
Loot({ { name = "Bismuth", id = R2 } })
Loot({ { name = "Bismuth", id = R1 } })
local seen = Tracker:RanksOf("Bismuth")
check("both ranks with their loot counts", seen and seen[R1] == 2 and seen[R2] == 1)
check("an item without ranks keeps none", Tracker:LookOf("Copper Ore").ranks == nil)
local before = asked
Loot({ { name = "Copper Ore", id = PLAIN } })
check("an item without ranks is asked about once", asked == before, asked - before)

-- Prices: rank 1 at 100, rank 2 at 400; copper ore 50.
local prices = { [R1] = 100, [R2] = 400, [PLAIN] = 50 }
Value.OnePrice = function(_, id) if prices[id] then return prices[id], "auction" end end
-- (100 * 2 + 400 * 1) / 3 = 200.
check("a rank is priced with its ranks, by your loot", Value:UnitPrice(R1) == 200 and Value:UnitPrice(R2) == 200,
    Value:UnitPrice(R1))
check("a bag stack keeps its own rank's price", Value:UnitPrice(R2, true) == 400)
check("an item without ranks is as before", Value:UnitPrice(PLAIN) == 50)
check("by name too", Value:WorthOf("Bismuth") == 200, Value:WorthOf("Bismuth"))
prices[R2] = nil
check("a rank with no price is left out", Value:UnitPrice(R1) == 100)
prices[R2] = 400

-- Goals count every rank in the bags.
local bags = { [R1] = 7, [R2] = 5, [PLAIN] = 3 }
local item0 = _G.C_Item
_G.C_Item = setmetatable({ GetItemCount = function(id) return bags[id] or 0 end }, { __index = item0 })
check("a goal counts every rank", Goals:Have("Bismuth") == 12, Goals:Have("Bismuth"))
check("asked by one rank's ID, still every rank", Goals:Have("Bismuth", R2) == 12)
check("an item without ranks counts as before", Goals:Have("Copper Ore") == 3)
_G.C_Item = item0

-- The suites share one Lua: leave the client as it was.
_G.C_TradeSkillUI = nil

suite.done()
