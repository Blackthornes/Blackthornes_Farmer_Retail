-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.48.0", lines = {
        "The Grind tab shows what each camp earns you an hour. A new Best Worth sort puts the best camps on top.",
        "Map markers show only the herbs, ore and fish spots your character can gather. You can turn this off under Markers in Settings.",
        "Item icons have quality rings and counts in the corner.",
        "You can drag the Top 15 window where you want it. Set Default in Settings, on the Kills page, puts it back.",
        "Drop rates on a mob's loot table count your guild's kills too, once you've killed that mob 20 times yourself. Guild sharing has to be on.",
        "You can turn off the beam over your fishing bobber if it hides the bob. It is in Settings, on the Map & goals page, under Sparkles.",
    } },
    { version = "0.47.2", lines = {
        "This is an early build, so you may run into bugs. Please report them on our Discord, in the bug channel, with the Retail and Farmer tags.",
    } },
    { version = "0.47.1", lines = {
        "This is an early build, so you may run into bugs. Please report them on our Discord, in the bug channel, with the Retail and Farmer tags.",
    } },
}
