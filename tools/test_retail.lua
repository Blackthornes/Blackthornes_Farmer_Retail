-- The Retail copy.
--
-- This repo is Farmer for Retail WoW. The Classic and Forever data does not
-- fit Retail, so the TOC leaves it out, and the TOC must never point a tag at
-- the Forever project on CurseForge. Then the addon has to load, log in and
-- answer a search with no shipped data behind it.

local env = dofile(lfs_cwd .. "/tools/testenv.lua")
local suite = env.NewSuite("retail")

local handle = assert(io.open(lfs_cwd .. "/Blackthornes_Farmer.toc", "r"))
local toc = handle:read("*a")
handle:close()

suite.check("the TOC is not Forever's", not toc:find("## Interface: 16001", 1, true))
suite.check("the TOC names a Retail interface", toc:find("## Interface: 12", 1, true) ~= nil)
suite.check("the TOC never names Forever's CurseForge project",
    not toc:find("^## X%-Curse%-Project%-ID:%s*1710618") and not toc:find("\n## X%-Curse%-Project%-ID:%s*1710618"))

-- Data_Harvested.lua is the exception: tools/harvest_import.py writes it
-- from a save and adds it to the TOC, so once it is made from Retail play it
-- belongs there. The copy in the repo now is Forever's and is left out.
for file in pairs(env.FOREVER_DATA) do
    if file ~= "Data/Data_Harvested.lua" then
        local line = file:gsub("/", "\\")
        suite.check("the TOC leaves out " .. file, not toc:find("\n" .. line, 1, true))
    end
end

for file in pairs(env.RETAIL_LEFT_OUT) do
    local line = file:gsub("/", "\\")
    suite.check("the TOC leaves out " .. file, not toc:find("\n" .. line, 1, true))
end

-- Loading as Retail does: no shipped data.
local ns = env.Load({ ui = true, retail = true })
suite.check("no Classic mob names", ns.NPC_NAMES == nil)
suite.check("no Forever mob names", ns.FOREVER_NPC_NAMES == nil)
suite.check("no drop sending", ns.Contribute == nil)
suite.check("no Legacy perks", ns.Legacy == nil)
suite.check("no Guide Me", ns.Travel == nil)
suite.check("no Gather to cap", ns.GatherToCap == nil)

local boot = ns.modules.Bootstrap
local ok, err = pcall(function()
    boot:ADDON_LOADED("ADDON_LOADED", "Blackthornes_Farmer")
    boot:PLAYER_LOGIN()
end)
suite.check("it loads and logs in", ok, err)

local found, results = pcall(function() return ns.Search:Run("copper ore") end)
suite.check("a search answers without shipped data", found, results)

-- What the Retail TOC leaves out must not be missed: Settings opens, every
-- Grind view draws, the arrow check and "/farm share drops" answer.
local opened, why = pcall(function()
    ns.SettingsUI:Show()
    ns.SettingsUI:Refresh()
    ns.SettingsUI:Hide()
end)
suite.check("Settings opens without the left out files", opened, why)

local drew, whyNot = pcall(function()
    ns.UI:ShowTab("grind")
    for _, word in ipairs({ "cloth", "leather", "ore", "herbs", "fish" }) do
        ns.HandleSlash("grind " .. word)
    end
end)
suite.check("every Grind view draws without Gather to cap", drew, whyNot)

local typed, whyTyped = pcall(function()
    ns.HandleSlash("share drops")
    ns.HandleSlash("arrow check")
end)
suite.check("share drops and the arrow check still answer", typed, whyTyped)

suite.done()
