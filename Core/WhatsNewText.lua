-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.47.0", lines = {
        "This is an early build, so you may run into bugs. Please report them on our Discord, in the bug channel, with the Retail and Farmer tags.",
        "The Ore, Herbs and Leather views on the Grind tab show your whole road from level 1 to the max, one expansion at a time, from Classic to Midnight. Your skill shows in each one, and Farmer tells you about how many more gathers you need.",
        "Map pins show the icon of the item that spot gave you most. A pin stays grey until the spot has grown back.",
        "Fishing spots are marked on your map too.",
        "Nodes that are close together join into one pin. On the world map, pins that sit on top of each other join into one pin with a count.",
        "The gold arrow moves on to the next spot when you reach a node that isn't up yet.",
    } },
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
}
