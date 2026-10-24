-- Blackthornes Farmer -- UI/RoadToMax.lua
-- Road to max, drawn at the top of the Grind tab's list in the Ore, Herbs
-- and Leather views (Logic/RoadToMax.lua works the road out). Retail only:
-- the Retail TOC loads it in place of UI/GatherToCap.lua.
--
-- "YOUR MINING ROAD" over a dark glass tile a expansion, Classic to
-- Midnight, each with your skill and its cap (a check once done, a gold
-- edge on the one you stand in, the one picked lit). A click on a tile
-- opens its stops below: a heading ("NORTHREND MINING 41 / 75", "Road to
-- max"), a thin meter with a segment a stop, then a dark glass row a stop
-- (the last one done, the one you are on with Show the Way, a few after
-- it), the footer and Set Goal.
--
-- Drawn only when the Grind tab draws; the tiles and rows are made once
-- and filled again each draw.

local _, ns = ...
local L = ns.L

local RoadToMaxUI = ns.NewModule("RoadToMaxUI")

local Theme = ns.Theme
local Widgets = ns.Widgets

RoadToMaxUI.HEAD_H = 18
RoadToMaxUI.TILE_H = 30
RoadToMaxUI.COLS = 6
RoadToMaxUI.METER_H = 5
RoadToMaxUI.STOP_H = 34
RoadToMaxUI.NOTE_H = 24
RoadToMaxUI.FOOT_H = 26
-- Stops shown after the one you are on.
RoadToMaxUI.LATER = 3
-- Room left under the block, before the list's headings.
RoadToMaxUI.GAP = 8

local CHECK = [[Interface\RaidFrame\ReadyCheck-Ready]]
local ICON = 22

-- The expansion picked in each view, for the session.
RoadToMaxUI.picked = {}

--- Upper case that keeps German's umlauts upper too.
local function Upper(text)
    return (text:upper():gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"))
end

local function ButtonWidth(text)
    return math.ceil(Theme.TextWidth("small", text or "")) + 24
end

--------------------------------------------------------------------------------
-- Words
--------------------------------------------------------------------------------

--- "YOUR MINING ROAD".
function RoadToMaxUI.RoadText(path)
    local words = { Mining = L["YOUR MINING ROAD"], Herbalism = L["YOUR HERBALISM ROAD"],
        Skinning = L["YOUR SKINNING ROAD"] }
    return words[path.english] or path.english
end

--- "41 / 75" on a tile, "" when nothing says.
function RoadToMaxUI.TileNumbers(each)
    if not each.skill then return "" end
    return L.Format("%d / %d", each.skill, each.most)
end

--- "NORTHREND MINING 41 / 75".
function RoadToMaxUI.HeadingText(path)
    local name = Upper(L.Format("%1$s %2$s", ns.RoadToMax.ExpansionLabel(path.pick),
        ns.RoadToMax.SkillLabel(path.english)))
    if not path.line then return name end
    return L.Format("%s %d / %d", name, path.line.skill, path.line.most)
end

--- A stop's name: "Copper Vein in Elwynn Forest", "Ore in Zul'Aman",
--- "Beasts level 20 to 30".
function RoadToMaxUI.TitleText(path, stop)
    if stop.low then return L.Format("Beasts level %d to %d", stop.low, stop.high) end
    if stop.node then
        if stop.zone then return L.Format("%s in %s", stop.node, ns.Spots.Show(stop.zone)) end
        return stop.node
    end
    local zone = ns.Spots.Show(stop.zone)
    if path.english == "Mining" then return L.Format("Ore in %s", zone) end
    if path.english == "Herbalism" then return L.Format("Herbs in %s", zone) end
    return L.Format("Beasts in %s", zone)
end

--- "now to 50" or "50 to 75".
function RoadToMaxUI.RangeText(stop)
    if stop.state == "now" then return L.Format("now to %d", stop.to) end
    return L.Format("%d to %d", stop.from, stop.to)
end

--- The line under a stop's name.
function RoadToMaxUI.SubText(stop)
    if stop.state == "done" then return "" end
    local parts = {}
    if stop.state == "now" then
        if (stop.spots or 0) > 0 then parts[#parts + 1] = L.Format("You've mapped %d spots here.", stop.spots) end
        if stop.gathers then parts[#parts + 1] = L.Format("About %d more gathers.", stop.gathers) end
    elseif stop.gathered then
        parts[#parts + 1] = L["Most of your gathering is here."]
    end
    return table.concat(parts, " ")
end

--- "2g 40s an hour", or "" when nothing says.
function RoadToMaxUI.WorthText(stop)
    if not stop.perHour then return "" end
    return L.Format("%s an hour", ns.Value.Coins(stop.perHour))
end

--- The line in place of the stops, or nil: a line still to learn, a line
--- finished, or skills the client has not said yet.
function RoadToMaxUI.NoteText(path)
    if path.learn then
        return L.Format("Learn %1$s %2$s at a trainer first.", ns.RoadToMax.ExpansionLabel(path.pick),
            ns.RoadToMax.SkillLabel(path.english))
    end
    if path.line and path.line.skill >= path.line.most and path.line.skill > 0 then
        return L["All done here."]
    end
    if path.unread then
        return L.Format("Open your %s window once to read your skills.", ns.RoadToMax.SkillLabel(path.english))
    end
    return nil
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

--- The block, inside the Grind tab's panel. Hidden until a road shows.
function RoadToMaxUI:Build(panel)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, panel)
    frame:SetPoint("TOPLEFT", 8, -8)
    frame:SetPoint("TOPRIGHT", -8, -8)
    frame:SetHeight(1)
    frame:Hide()
    self.frame = frame

    self.roadHead = Theme.CreateLabel(frame, "small", "text")
    self.roadHead:SetPoint("TOPLEFT", 2, 0)
    self.roadHead:SetHeight(self.HEAD_H)
    self.roadHint = Theme.CreateLabel(frame, "tiny", "muted", "RIGHT")
    self.roadHint:SetPoint("TOPRIGHT", -2, 0)
    self.roadHint:SetHeight(self.HEAD_H)
    self.roadHint:SetText(L["Click an expansion to see its stops."])
    self.tiles = {}

    local head = Theme.CreateLabel(frame, "small", "accent")
    head:SetHeight(self.HEAD_H)
    self.head = head

    local note = Theme.CreateLabel(frame, "tiny", "muted", "RIGHT")
    note:SetHeight(self.HEAD_H)
    note:SetText(L["Road to max"])
    self.note = note

    local meter = CreateFrame("Frame", nil, frame)
    meter:SetHeight(self.METER_H)
    meter.segments = {}
    -- The glow round the stop you are on: a soft gold light, lit through
    -- Theme.LightGradient so it is hidden, never just faded.
    meter.glow = meter:CreateTexture(nil, "BACKGROUND")
    pcall(meter.glow.SetBlendMode, meter.glow, "ADD")
    meter.glow:Hide()
    self.meter = meter

    self.rows = {}

    local message = Theme.CreateLabel(frame, "small", "muted")
    message:SetHeight(self.NOTE_H)
    self.message = message

    local foot = Theme.CreateLabel(frame, "tiny", "muted")
    foot:SetText(L["Gold an hour and gathers left are from your own gathering."])
    self.foot = foot

    local goal = Widgets.CreateButton(frame, L["Set Goal"], function()
        if RoadToMaxUI.current then ns.RoadToMax:SetGoal(RoadToMaxUI.current) end
    end, { width = ButtonWidth(L["Set Goal"]), height = 20 })
    self.goalButton = goal

    return frame
end

function RoadToMaxUI:Tile(index)
    local tile = self.tiles[index]
    if tile then return tile end

    tile = CreateFrame("Button", nil, self.frame)
    tile:SetHeight(self.TILE_H)
    tile.stripe = Theme.Fill(tile, "glass")
    Widgets.RowLight(tile)

    -- The one you stand in: a bright gold edge down its left.
    tile.active = tile:CreateTexture(nil, "OVERLAY", nil, 1)
    tile.active:SetPoint("TOPLEFT")
    tile.active:SetPoint("BOTTOMLEFT")
    tile.active:SetWidth(2)
    tile.active:SetColorTexture(Theme.Unpack("accentHi"))

    tile.name = Theme.CreateLabel(tile, "tiny", "text")
    tile.name:SetPoint("TOPLEFT", 7, -3)
    tile.name:SetPoint("TOPRIGHT", -4, -3)
    tile.check = tile:CreateTexture(nil, "ARTWORK")
    tile.check:SetSize(11, 11)
    tile.check:SetTexture(CHECK)
    tile.check:SetPoint("BOTTOMLEFT", 6, 4)
    tile.numbers = Theme.CreateLabel(tile, "tiny", "muted")

    tile:SetScript("OnClick", function(self)
        if not (self.key and RoadToMaxUI.view) then return end
        RoadToMaxUI.picked[RoadToMaxUI.view] = self.key
        if ns.GrindingUI then ns.GrindingUI:Refresh() end
    end)
    tile:SetScript("OnEnter", function(self) Widgets.SetRowLight(self, 1) end)
    tile:SetScript("OnLeave", function(self) Widgets.SetRowLight(self, 0) end)

    self.tiles[index] = tile
    return tile
end

function RoadToMaxUI:Row(index)
    local row = self.rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, self.frame)
    row:SetHeight(self.STOP_H)
    row:EnableMouse(true)

    row.stripe = Theme.Fill(row, "glass")
    row.line = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    row.line:SetHeight(1)
    row.line:SetColorTexture(Theme.Unpack("border", 0.6))
    Widgets.RowLight(row)

    -- The one you are on: a bright gold edge down its left.
    row.active = row:CreateTexture(nil, "OVERLAY", nil, 1)
    row.active:SetPoint("TOPLEFT")
    row.active:SetPoint("BOTTOMLEFT")
    row.active:SetWidth(2)
    row.active:SetColorTexture(Theme.Unpack("accentHi"))

    row.icon = Theme.CreateItemIcon(row, ICON)
    row.icon:SetPoint("LEFT", 8, 0)
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(14, 14)
    row.check:SetTexture(CHECK)
    row.check:SetPoint("CENTER", row.icon, "CENTER", 0, 0)

    row.title = Theme.CreateLabel(row, "small", "text")
    row.title:SetPoint("TOPLEFT", 8 + ICON + 8, -4)
    row.range = Theme.CreateLabel(row, "tiny", "muted")
    row.range:SetPoint("LEFT", row.title, "RIGHT", 8, 0)
    row.sub = Theme.CreateLabel(row, "tiny", "muted")
    row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)

    row.worth = Theme.CreateLabel(row, "small", "text", "RIGHT")
    row.done = Theme.CreateLabel(row, "small", "good", "RIGHT")
    row.done:SetText(L["Done"])
    row.done:SetPoint("RIGHT", -10, 0)

    row.button = Widgets.CreateButton(row, L["Show the Way"], function()
        ns.RoadToMax:ShowTheWay(row.stop)
    end, { primary = true, width = ButtonWidth(L["Show the Way"]), height = 20 })
    row.button:SetPoint("RIGHT", -8, 0)

    row:SetScript("OnEnter", function(self)
        if self.stop and self.stop.state ~= "now" then Widgets.SetRowLight(self, 1) end
    end)
    row:SetScript("OnLeave", function(self) Widgets.SetRowLight(self, 0) end)

    self.rows[index] = row
    return row
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function RoadToMaxUI:Width()
    local width = self.frame:GetWidth()
    if type(width) ~= "number" or width <= 0 then width = 600 end
    return width
end

--- The tiles, from `top`. Returns the height they take.
function RoadToMaxUI:PaintTiles(path, top)
    local width = self:Width()
    local gap = 2
    local each = (width - gap * (self.COLS - 1)) / self.COLS
    for index, expansion in ipairs(path.expansions) do
        local tile = self:Tile(index)
        local column = (index - 1) % self.COLS
        local line = math.floor((index - 1) / self.COLS)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", column * (each + gap), -(top + line * (self.TILE_H + gap)))
        tile:SetWidth(math.max(1, each))
        tile.key = expansion.key
        local picked = expansion.key == path.pick
        tile.stripe:SetColorTexture(Theme.Unpack(picked and "glassActive"
            or ((index + line) % 2 == 1 and "glass" or "glassAlt")))
        tile.active:SetShown(expansion.now)
        Widgets.SetRowLight(tile, 0)
        tile.name:SetText(ns.RoadToMax.ExpansionLabel(expansion.key))
        tile.name:SetTextColor(Theme.Unpack(picked and "accentHi" or "text"))
        tile.numbers:SetText(RoadToMaxUI.TileNumbers(expansion))
        tile.numbers:SetTextColor(Theme.Unpack(expansion.done and "good" or expansion.now and "accentHi" or "muted"))
        tile.check:SetShown(expansion.done)
        tile.numbers:ClearAllPoints()
        if expansion.done then
            tile.numbers:SetPoint("LEFT", tile.check, "RIGHT", 3, 0)
        else
            tile.numbers:SetPoint("BOTTOMLEFT", 7, 4)
        end
        tile:Show()
    end
    for index = #path.expansions + 1, #self.tiles do self.tiles[index]:Hide() end
    local lines = math.ceil(#path.expansions / self.COLS)
    return lines * self.TILE_H + math.max(0, lines - 1) * gap
end

function RoadToMaxUI:PaintMeter(path)
    local meter = self.meter
    local count = #path.stops
    local width = self:Width()
    local gap = 2
    local each = count > 0 and (width - gap * (count - 1)) / count or width
    meter.glow:Hide()
    for index, stop in ipairs(path.stops) do
        local segment = meter.segments[index]
        if not segment then
            segment = meter:CreateTexture(nil, "ARTWORK")
            meter.segments[index] = segment
        end
        segment:ClearAllPoints()
        segment:SetPoint("TOPLEFT", (index - 1) * (each + gap), 0)
        segment:SetSize(math.max(1, each), self.METER_H)
        local key = stop.state == "done" and "good" or stop.state == "now" and "accentHi" or "glassHover"
        segment:SetColorTexture(Theme.Unpack(key))
        segment:Show()
        if stop.state == "now" then
            meter.glow:ClearAllPoints()
            meter.glow:SetPoint("TOPLEFT", segment, "TOPLEFT", -4, 4)
            meter.glow:SetPoint("BOTTOMRIGHT", segment, "BOTTOMRIGHT", 4, -4)
            Theme.LightGradient(meter.glow, "VERTICAL", "accent", 0.45, 0.45, 1)
            meter.glow:Show()
        end
    end
    for index = count + 1, #meter.segments do meter.segments[index]:Hide() end
end

function RoadToMaxUI:FillRow(row, path, stop, index)
    row.stop = stop
    local state = stop.state
    row.stripe:SetColorTexture(Theme.Unpack(state == "now" and "glassActive"
        or (index % 2 == 1 and "glass" or "glassAlt")))
    row.active:SetShown(state == "now")
    Widgets.SetRowLight(row, 0)

    if state == "done" then
        row.icon:Hide()
        row.check:Show()
    else
        row.check:Hide()
        Theme.SetItemIcon(row.icon, stop.itemID)
    end

    row.title:SetText(RoadToMaxUI.TitleText(path, stop))
    row.title:SetTextColor(Theme.Unpack(state == "now" and "accentHi" or "text"))
    row.range:SetText(RoadToMaxUI.RangeText(stop))
    local sub = RoadToMaxUI.SubText(stop)
    row.sub:SetText(sub)
    row.sub:SetShown(sub ~= "")
    row.title:ClearAllPoints()
    if sub ~= "" then
        row.title:SetPoint("TOPLEFT", 8 + ICON + 8, -4)
    else
        row.title:SetPoint("LEFT", 8 + ICON + 8, 0)
    end

    row.done:SetShown(state == "done")
    -- Show the Way needs a place: a Classic stop you never gathered has none.
    local way = state == "now" and stop.zone ~= nil
    row.button:SetShown(way)
    local worth = state ~= "done" and RoadToMaxUI.WorthText(stop) or ""
    row.worth:SetText(worth)
    row.worth:SetShown(worth ~= "")
    row.worth:ClearAllPoints()
    if way then
        row.worth:SetPoint("RIGHT", row.button, "LEFT", -10, 0)
    else
        row.worth:SetPoint("RIGHT", -10, 0)
    end

    -- The ones done fade back more than the ones still to come.
    local alpha = state == "done" and 0.55 or state == "later" and 0.8 or 1
    for _, region in ipairs({ row.icon, row.check, row.title, row.range, row.sub, row.worth, row.done }) do
        region:SetAlpha(alpha)
    end
end

--- Draw the road for the Grind view `view` ("ore", "herbs", "skinning"),
--- or hide it. Returns the room it takes at the top of the list.
function RoadToMaxUI:Update(view)
    if not self.frame then return 0 end
    local path = view and ns.RoadToMax:Path(view, self.picked[view])
    if not path then
        self.frame:Hide()
        self.current, self.path, self.view = nil, nil, nil
        return 0
    end
    self.view, self.path = view, path

    self.roadHead:SetText(RoadToMaxUI.RoadText(path))
    local top = self.HEAD_H + 2
    top = top + self:PaintTiles(path, top) + 8

    self.head:ClearAllPoints()
    self.head:SetPoint("TOPLEFT", 2, -top)
    self.head:SetText(RoadToMaxUI.HeadingText(path))
    self.note:ClearAllPoints()
    self.note:SetPoint("TOPRIGHT", -2, -top)
    top = top + self.HEAD_H + 2

    local message = RoadToMaxUI.NoteText(path)
    local showStops = not path.learn and #path.stops > 0
        and not (path.line and path.line.skill >= path.line.most and path.line.skill > 0)
    local shown = showStops and ns.RoadToMax.Shown(path, self.LATER) or {}
    self.current = showStops and path.current and path.stops[path.current] or nil

    self.meter:ClearAllPoints()
    self.meter:SetPoint("TOPLEFT", 0, -top)
    self.meter:SetPoint("TOPRIGHT", 0, -top)
    if showStops then
        self:PaintMeter(path)
        self.meter:Show()
        top = top + self.METER_H + 6
    else
        self.meter:Hide()
    end

    if message then
        self.message:ClearAllPoints()
        self.message:SetPoint("TOPLEFT", 8, -top)
        self.message:SetPoint("TOPRIGHT", -8, -top)
        self.message:SetText(message)
        self.message:Show()
        top = top + self.NOTE_H
    else
        self.message:Hide()
    end

    for index, stop in ipairs(shown) do
        local row = self:Row(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(top + (index - 1) * self.STOP_H))
        row:SetPoint("TOPRIGHT", 0, -(top + (index - 1) * self.STOP_H))
        self:FillRow(row, path, stop, index)
        row:Show()
    end
    for index = #shown + 1, #self.rows do self.rows[index]:Hide() end

    local footTop = top + #shown * self.STOP_H + 4
    self.foot:ClearAllPoints()
    self.foot:SetPoint("TOPLEFT", 2, -footTop - 4)
    self.foot:SetShown(#shown > 0)
    self.goalButton:ClearAllPoints()
    self.goalButton:SetPoint("TOPRIGHT", -2, -footTop)
    self.goalButton:SetShown(self.current ~= nil and self.current.item ~= nil)

    local height = footTop + (#shown > 0 and self.FOOT_H - 4 or 0)
    self.frame:SetHeight(height)
    self.frame:Show()
    return height + self.GAP
end
