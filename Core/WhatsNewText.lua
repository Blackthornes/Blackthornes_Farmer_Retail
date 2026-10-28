-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.47.2", lines = {
        "This is an early build, so you may run into bugs. Please report them on our Discord, in the bug channel, with the Retail and Farmer tags.",
    } },
    { version = "0.47.1", lines = {
        "This is an early build, so you may run into bugs. Please report them on our Discord, in the bug channel, with the Retail and Farmer tags.",
    } },
    { version = "0.47.0", lines = {
        "This is an early build, so you may run into bugs. Please report them on our Discord, in the bug channel, with the Retail and Farmer tags.",
        "The Ore, Herbs and Leather views on the Grind tab show your whole road from level 1 to the max, one expansion at a time, from Classic to Midnight. Your skill shows in each one, and Farmer tells you about how many more gathers you need.",
        "Map pins show the icon of the item that spot gave you most. A pin stays grey until the spot has grown back.",
        "Fishing spots are marked on your map too.",
        "Nodes that are close together join into one pin. On the world map, pins that sit on top of each other join into one pin with a count.",
        "The gold arrow moves on to the next spot when you reach a node that isn't up yet.",
    } },
}
