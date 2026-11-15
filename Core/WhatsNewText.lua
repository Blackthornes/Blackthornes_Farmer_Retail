-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "0.49.0", lines = {
        "Loot Beacons put a beam over the body in front of you while it still has loot. You can pick the color and size. Turn it on in Settings, on the Loot page.",
        "Pick a sound for when you find a node. Your character can call out, a peon can say he is ready to work, or you can get a little ping. It starts off.",
        "A new little gold gem on the world map hides all of Farmer's marks with one click, and another click brings them back. Right-click it to choose which marks to hide. Camp swords now only show while the Grind tab is open.",
        "Pick where the quest count sits next to a mob's name: above, below, left or right. It is bigger and brighter too, and it still starts on the right.",
        "In a group, the quest count can show only your own quests. It's a box on the Map & goals page.",
        "A new box in Settings, on the Map & goals page, called My Professions Only under Sparkles. Ticked, only the herbs, ore and fish your character can gather light up. It starts off.",
        "You can pick which TSM price to use, on the Loot page. Gear that binds when worn can have its own TSM price. It starts on the recent price.",
        "There's a session timer for your Kills & Loot panel, with Start, Pause and Stop. You turn it on in the Kills page of Settings.",
        "Rankings can price every drop at what a vendor pays. It's a box on the Rankings tab.",
        "Windows remember where you drag them. A button on the General page puts every window back where it started.",
        "There's a new box that mutes every sound from the Blackthornes add-ons at once. It starts off.",
        "Hover a row in the loot feed to see the item's tooltip.",
    } },
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
}
