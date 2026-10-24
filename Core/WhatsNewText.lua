-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.46.0", lines = {
        "This is an early build, so you may run into bugs. Please report them on our Discord, in the bug channel, with the Retail and Farmer tags.",
        "Farmer counts every kill and drop you loot, so a mob's worth comes from your own play. Looting a whole pack at once counts every corpse.",
        "Rankings lists mobs by what a kill is worth. If you use TradeSkillMaster or Auctionator, drops are priced from their auction prices.",
        "Search any item, zone or mob to see where you found it. Set a goal and a gold arrow leads you there.",
        "The Stats tab turns your farming into charts: gold an hour, where your gold came from and your best mobs.",
        "The Open button opens clams, sacks and lockboxes, and Farmer counts what comes out.",
        "Herbs, ore and fishing spots are marked on your map and minimap.",
    } },
    { version = "0.45.0", lines = {
        "You can set a kill goal, for any mob or one mob. It shows first in your Goals panel, and a summary opens when you finish. Start one with Set another in the Goals panel.",
        "The Ore, Herbs and Leather views on the Grind tab show your way from your skill to 300.",
        "With Tradeskills, Goblin Gold's hover card shows this week's kills and what their loot was worth.",
    } },
    { version = "0.44.0", lines = {
        "Loot Feed shows what you loot in a small list, with the coin and what it's all worth. It's off until you tick it on the Loot page of Settings.",
        "The trash can in your bags now puts a red glow round the item it picked. It's on the Loot page, under Trash Can When Full.",
    } },
}
