-- The Snackrun tab along the bottom of the Auction House (after Buy / Sell / Auctions) and the panel it shows:
-- a left rail (who we shop for, profile, spec, weapons, level, scan) and the list (sections, rows, cost to fill).
-- Tab pattern after LibAHTab (written fresh, no library): a display-mode tab button, SetDisplayMode({}) to clear
-- Blizzard's panels, and a hooksecurefunc on SetDisplayMode so any Blizzard tab hides ours again.
local ADDON, SR = ...
local T, W = SR.Theme, SR.W
local C = T.C

local RAIL_W, BRAND_H, HEAD_H, FOOT_H, COLS_H = 236, 62, 62, 40, 24
local ROW_H, SEC_H, PAD = 40, 30, 16
-- Column right edges, measured from the list's right side (mockup grid: 30 | name | 40 | 48 | 76 | 44, gap 9).
local COL = { listed = -PAD, lowest = -PAD - 44 - 9, want = -PAD - 44 - 9 - 76 - 9, bags = -PAD - 44 - 9 - 76 - 9 - 48 - 9 }
local NAME_RIGHT = COL.bags - 40 - 9
local TAG_RIGHT = COL.bags - 30 -- tags may use the empty left part of the Bags column (numbers are right-aligned)

local P -- the panel
local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")

--------------------------------------------------------------------------------
-- Buying: hand the item to Blizzard's own Buy tab. No purchase call ever comes from Snackrun.
--------------------------------------------------------------------------------
function SR.FindInBuy(id)
    local name = SR.ItemInfo(id)
    local AHF = AuctionHouseFrame
    if not name or not AHF then return end
    if AHF.BuyTab then AHF.BuyTab:Click() end
    if AHF.SetSearchText and AHF:SetSearchText(name) ~= false and AHF.SearchBar and AHF.SearchBar.StartSearch then
        AHF.SearchBar:StartSearch()
    end
end

--------------------------------------------------------------------------------
-- Small parts
--------------------------------------------------------------------------------
local TAGS = {
    core = { "CORE", C.bone, C.boneLine },
    new = { "NEW", C.accent, C.accentLine },
}

local function Tag(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(13)
    f.box = T.Box(f, 3, C.window, C.border, "ARTWORK")
    f.text = T.Text(f, "mono", 8.5, C.dim)
    f.text:SetPoint("CENTER", 0, 0)
    function f:Set(text, color, line, fill)
        self.text:SetText(text)
        self.text:SetTextColor(T.RGBA(color))
        self.box:SetBorder(line)
        self.box:SetFill(fill or C.window)
        self:SetWidth(math.ceil(self.text:GetStringWidth()) + 9)
    end
    return f
end

local function Caps(parent, text, size, color)
    local fs = T.Text(parent, "caps", size or 9, color or C.dim)
    fs:SetText(text:upper())
    return fs
end

local function PlayerLine()
    local first, surname = UnitFullName("player")
    local name = first or UnitName("player") or "?"
    if surname and surname ~= "" and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        name = name .. " " .. surname
    end
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local cls = (color and ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255) or "") .. (UnitClass("player") or "") .. "|r"
    return name, cls, SR.PlayerLevel()
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------
local function OpenRowMenu(row)
    local id, prof = row.data.id, SR.char.profile
    local name = SR.ItemInfo(id) or ("Item " .. id)
    local want, set = SR.Want(id)
    local entries = { { header = true, text = name } }
    entries[#entries + 1] = { text = "Find in Buy", onClick = function() SR.FindInBuy(id) end }
    if prof ~= "auto" then
        entries[#entries + 1] = { text = "Remove from " .. prof, onClick = function() SR.SetInProfile(prof, id, false) end }
    end
    local adds = {}
    for _, p in ipairs(SR.ProfileNames()) do
        if p ~= prof and not SR.ProfileHas(p, id) then
            adds[#adds + 1] = { text = "Add to " .. p, right = tostring(SR.ProfileSize(p)), onClick = function() SR.SetInProfile(p, id, true) end }
        end
    end
    entries[#entries + 1] = { sep = true }
    if #adds > 0 then
        entries[#entries + 1] = { header = true, text = "Add to profile" }
        for _, e in ipairs(adds) do entries[#entries + 1] = e end
    else
        entries[#entries + 1] = { text = "New profile with this", onClick = function()
            local p = SR.CreateProfile()
            SR.SetInProfile(p, id, true)
            SR.OpenOptions("profiles", p)
        end }
    end
    if set then
        entries[#entries + 1] = { sep = true }
        entries[#entries + 1] = { text = "Reset Want", right = tostring(SR.DefaultWant(id)), onClick = function() SR.ResetWant(id) end }
    end
    W.OpenMenu(row, entries, { atCursor = true })
end

local function NewRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.stripe = T.Fill(r, C.stripe)
    r.stripe:SetAllPoints()
    r.hover = T.Fill(r, C.hover, "BACKGROUND", 1)
    r.hover:SetAllPoints()
    r.hover:Hide()

    r.iconFrame = CreateFrame("Frame", nil, r)
    r.iconFrame:SetSize(30, 30)
    r.iconFrame:SetPoint("LEFT", PAD, 0)
    r.iconBox = T.Box(r.iconFrame, 5, C.control, C.border, "ARTWORK")
    r.icon = r.iconFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    r.icon:SetPoint("TOPLEFT", 2, -2)
    r.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    r.name = T.Text(r, "semibold", 12.5, C.text)
    r.name:SetPoint("TOPLEFT", r.iconFrame, "TOPRIGHT", 9, -1)
    r.tags = { Tag(r), Tag(r), Tag(r) }
    r.sub = T.Text(r, "medium", 11, C.dim)
    r.sub:SetPoint("BOTTOMLEFT", r.iconFrame, "BOTTOMRIGHT", 9, 1)
    r.sub:SetPoint("RIGHT", r, "RIGHT", NAME_RIGHT, 0)

    r.bags = T.Text(r, "mono", 12, C.quiet)
    r.bags:SetPoint("RIGHT", r, "RIGHT", COL.bags, 0)
    r.bags:SetJustifyH("RIGHT")
    r.want = W.NumberBox(r, 36, function(box, n) SR.SetWant(box.editId or r.data.id, n) end)
    r.want:SetPoint("RIGHT", r, "RIGHT", COL.want, 0)
    r.want:HookScript("OnEditFocusGained", function(box) box.editId = r.data.id; P.editing = box end)
    r.want:HookScript("OnEditFocusLost", function(box)
        if P.editing == box then P.editing = nil end
        if P.dirty then P:Refresh() end
    end)
    r.price = T.Text(r, "mono", 12, C.text)
    r.price:SetPoint("RIGHT", r, "RIGHT", COL.lowest, 0)
    r.price:SetJustifyH("RIGHT")
    r.listed = T.Text(r, "mono", 11, C.dim)
    r.listed:SetPoint("RIGHT", r, "RIGHT", COL.listed, 0)
    r.listed:SetJustifyH("RIGHT")

    r:SetScript("OnEnter", function(self)
        self.hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 8, 0)
        GameTooltip:SetItemByID(self.data.id)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then OpenRowMenu(self) else SR.FindInBuy(self.data.id) end
    end)
    return r
end

local function PaintRow(r, d, striped, prices)
    r.data = d
    r.stripe:SetShown(striped)
    r:SetAlpha(d.dim and 0.42 or 1)
    local name, quality, icon = SR.ItemInfo(d.id)
    r.icon:SetTexture(icon or 134400) -- question mark until the item loads
    local qr, qg, qb = T.Quality(quality)
    r.iconBox:SetBorder({ qr, qg, qb, 0.55 })
    r.name:SetText(name or ("Item " .. d.id))
    r.name:SetTextColor(qr, qg, qb, 1)
    -- Tags after the name; the name gives way (truncates) before the tags do.
    local list = {}
    if d.core then list[#list + 1] = TAGS.core end
    if d.new then list[#list + 1] = TAGS.new end
    if d.at then list[#list + 1] = { "AT " .. d.at, C.amber, C.amberLine } end
    local tagsW = 0
    for i, tag in ipairs(r.tags) do
        local t = list[i]
        tag:SetShown(t ~= nil)
        if t then
            tag:Set(t[1], t[2], t[3])
            tagsW = tagsW + tag:GetWidth() + 5
        end
    end
    -- Tags sit after the name when both fit; otherwise they move to the front of the effect line, which gives way.
    local area = r:GetWidth() - PAD - 30 - 9 + TAG_RIGHT
    local natural = r.name:GetUnboundedStringWidth() + 1
    local inline = natural + tagsW <= area
    r.name:SetWidth(math.max(40, math.min(natural, area)))
    local prev
    for i, tag in ipairs(r.tags) do
        if list[i] then
            tag:ClearAllPoints()
            if prev then
                tag:SetPoint("LEFT", prev, "RIGHT", 5, 0)
            elseif inline then
                tag:SetPoint("LEFT", r.name, "RIGHT", 5, 0)
            else
                tag:SetPoint("BOTTOMLEFT", r.iconFrame, "BOTTOMRIGHT", 9, 1)
            end
            prev = tag
        end
    end
    r.sub:ClearAllPoints()
    r.sub:SetPoint("BOTTOMLEFT", r.iconFrame, "BOTTOMRIGHT", 9 + (inline and 0 or tagsW), 1)
    r.sub:SetPoint("RIGHT", r, "RIGHT", NAME_RIGHT, 0)
    local fx = d.item.fx or ""
    local prefix = d.dim and "outclassed" or d.alt and "alternative"
    r.sub:SetText(prefix and (T.Code(C.quiet) .. prefix .. " ·|r " .. fx) or fx)

    r.bags:SetText(tostring(d.bags))
    local low = not d.dim and d.want > 0 and d.bags < d.want
    r.bags:SetTextColor(T.RGBA(low and C.low or d.bags == 0 and C.disabled or C.quiet))
    r.want:SetValue(d.want, d.wantSet and not d.dim)

    local p = prices[d.id]
    if p and p.p then
        r.price:SetText(T.Money(p.p))
        r.price:SetFont(T.UI.mono, 12, "")
        r.price:SetTextColor(T.RGBA(C.text))
        r.listed:SetText(T.Short(p.q or 0))
    else
        r.price:SetText(p and "not listed" or "—")
        r.price:SetFont(T.UI.mono, 11, "")
        r.price:SetTextColor(T.RGBA(C.disabled))
        r.listed:SetText(p and "0" or "")
    end
end

local function NewSection(parent)
    local s = CreateFrame("Frame", nil, parent)
    s:SetHeight(SEC_H)
    s.no = T.Text(s, "mono", 11, C.accent)
    s.no:SetPoint("BOTTOMLEFT", PAD, 6)
    s.title = Caps(s, "", 10, C.label)
    s.title:SetPoint("LEFT", s.no, "RIGHT", 10, 0)
    s.count = T.Text(s, "mono", 11, C.dim)
    s.count:SetPoint("BOTTOMRIGHT", -PAD, 6)
    s.count:SetJustifyH("RIGHT")
    return s
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------
local Panel = {}

function Panel:Refresh()
    if not self:IsShown() then self.dirty = true return end
    if self.editing then self.dirty = true return end -- never move a Want box while it is being typed in
    self.dirty = false
    local list = SR.BuildList()
    self.list = list
    self:RefreshRail(list)
    self:RefreshList(list)
    self:RefreshFoot(list)
end

function Panel:RefreshRail(list)
    local ctx, c = list.ctx, SR.char
    local name, cls, lvl = PlayerLine()
    self.who:SetText(name)
    self.whoSub:SetText(cls .. "  " .. T.Code(C.quiet) .. lvl .. "|r")
    local overridden = c.spec ~= nil or (ctx.hasWeapons and c.weapons ~= nil) or c.level ~= nil
    self.reset:SetEnabled(overridden)
    self.reset.text:SetTextColor(T.RGBA(overridden and C.quiet or C.disabled))

    local auto = list.profile == "auto"
    if auto then
        self.profile:Set("Auto", "spec + level")
    else
        self.profile:Set(list.profile, SR.ProfileSize(list.profile) .. " picked")
    end
    for _, f in ipairs(self.autoOnly) do f:SetShown(auto) end
    for _, f in ipairs(self.customOnly) do f:SetShown(not auto) end
    -- No Weapons picker for classes without weapon types (warlocks): Spec takes the whole row.
    self.weapons:SetShown(auto and ctx.hasWeapons)
    self.spec:SetWidth(ctx.hasWeapons and self.specHalf or self.specFull)
    if auto then
        self.spec:Set(ctx.spec and ctx.spec.name or "—", ctx.specAuto and "auto" or nil)
        local wl = { blade = "Blade", blunt = "Blunt", both = "Both" }
        self.weapons:Set(wl[ctx.weapons] or "Blade", ctx.weaponsAuto and "auto" or nil)
        self.level:Set(ctx.level, ctx.realLevel, ctx.levelAuto)
    end
end

function Panel:RefreshList(list)
    local content = self.scroll.content
    local width = self.scroll:GetWidth()
    local prices = SR.Prices()
    local filter = self.filter ~= "" and self.filter or nil
    local y, ri, si = 0, 0, 0
    for _, s in ipairs(list.sections) do
        local shown = {}
        for _, d in ipairs(s.rows) do
            local nm = filter and (SR.ItemInfo(d.id) or ""):lower()
            if not filter or nm:find(filter, 1, true) then shown[#shown + 1] = d end
        end
        if #shown > 0 then
            si = si + 1
            local sec = self.sections[si] or NewSection(content)
            self.sections[si] = sec
            sec:ClearAllPoints()
            sec:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            sec:SetWidth(width)
            sec.no:SetText(("%02d"):format(s.sec.index))
            sec.title:SetText(s.sec.name:upper())
            local live = 0
            for _, d in ipairs(shown) do if not d.dim then live = live + 1 end end
            sec.count:SetText(tostring(live))
            sec:Show()
            y = y + SEC_H
            for i, d in ipairs(shown) do
                ri = ri + 1
                local row = self.rows[ri] or NewRow(content)
                self.rows[ri] = row
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                row:SetWidth(width)
                PaintRow(row, d, i % 2 == 0, prices)
                row:Show()
                y = y + ROW_H
            end
        end
    end
    for i = ri + 1, #self.rows do self.rows[i]:Hide() end
    for i = si + 1, #self.sections do self.sections[i]:Hide() end
    self.scroll:SetContentHeight(y + 10)

    -- Empty states
    local empty
    if ri == 0 then
        if filter then empty = "Nothing matches that filter."
        elseif list.profile ~= "auto" then empty = "This profile is empty. Right-click items on Auto, or pick them in Edit profile."
        elseif not list.ctx.supported then empty = "Snackrun only knows rogues, warriors and warlocks so far. Custom profiles work for anyone."
        else empty = "Nothing to buy at this level." end
    end
    self.empty:SetText(empty or "")
    self.empty:SetShown(empty ~= nil)

    -- Header
    local ctx = list.ctx
    if list.profile == "auto" then
        self.title:SetText("Auto")
        local who = ("level %d %s%s"):format(ctx.level, ctx.spec and (ctx.spec.name .. " ") or "", (UnitClass("player") or ""):lower())
        local sub = ("%s%d items|r for a %s"):format(T.Code(C.label), list.count, who)
        if list.unlock > 0 then sub = sub .. (" · %d above your level"):format(list.unlock) end
        self.subtitle:SetText(sub)
    else
        self.title:SetText(list.profile)
        self.subtitle:SetText(("%s%d items|r, hand-picked"):format(T.Code(C.label), list.count))
    end
end

function Panel:RefreshFoot(list)
    local total, unknown = SR.CostToFill(list)
    self.total:SetText(T.Money(total) or "0c")
    local newest
    local prices = SR.Prices()
    for _, s in ipairs(list.sections) do
        for _, d in ipairs(s.rows) do
            local p = prices[d.id]
            if p and (not newest or p.t > newest) then newest = p.t end
        end
    end
    local scanned = newest and ("scanned " .. T.Ago(newest)) or "not scanned yet"
    if unknown > 0 and newest then scanned = scanned .. (" · %d without a price"):format(unknown) end
    self.scanned:SetText(scanned)
    self.scanBtn.count:SetText(tostring(#SR.ScanIDs(list)))
end

function Panel:OnScan(done, total, running)
    self.prog:SetShown(running)
    self.scanBtn:SetText(running and "Stop scan" or "Scan list")
    self.scanBtn.count:SetShown(not running)
    if running then
        self.progText:SetText(("Scanning %d / %d"):format(done, total))
        self.progFill:SetWidth(math.max(1, (self.prog:GetWidth()) * (total > 0 and done / total or 0)))
    end
end

--------------------------------------------------------------------------------
-- The level card: value box, slider, a green marker at your real level, ticks 1 / 20 / 40 / 60.
--------------------------------------------------------------------------------
local function LevelCard(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 72)
    T.Box(f, 7, C.control, C.border)
    local key = Caps(f, "Level", 8.5)
    key:SetPoint("TOPLEFT", 10, -10)
    -- Plain text like the pickers' tag: a box sized at build time measured the font before it loaded (8px wide).
    f.auto = T.Text(f, "mono", 8.5, C.dim)
    f.auto:SetPoint("LEFT", key, "RIGHT", 6, 0)
    f.auto:SetText("auto")
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(38, 22)
    box:SetPoint("TOPRIGHT", -10, -6)
    T.Box(box, 4, C.field, C.border)
    f.value = T.Text(box, "mono", 12.5, C.text)
    f.value:SetPoint("CENTER")
    f.value:SetJustifyH("CENTER")

    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 10, -32)
    s:SetPoint("TOPRIGHT", -10, -32)
    s:SetHeight(16)
    s:SetMinMaxValues(1, SR.MAX_LEVEL)
    s:SetValueStep(1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local rail = s:CreateTexture(nil, "BACKGROUND")
    rail:SetColorTexture(T.RGBA(C.track))
    rail:SetHeight(4)
    rail:SetPoint("LEFT", 7, 0)
    rail:SetPoint("RIGHT", -7, 0)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(T.CIRCLE, nil, nil, "TRILINEAR")
    thumb:SetSize(14, 14)
    thumb:SetVertexColor(T.RGBA(C.bone))
    s:SetThumbTexture(thumb)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(T.RGBA(C.bone))
    fill:SetHeight(4)
    fill:SetPoint("LEFT", rail, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    -- Your level: a green tick above the rail with "you 52".
    local you = s:CreateTexture(nil, "OVERLAY", nil, 1)
    you:SetColorTexture(T.RGBA(C.accent))
    you:SetSize(T.Px(f), 12)
    -- "you 13" sits beside the value box; on the rail it ran into the fill.
    local youText = T.Text(f, "mono", 9.5, C.accent)
    youText:SetPoint("RIGHT", box, "LEFT", -8, 0)
    youText:SetJustifyH("RIGHT")
    local ticks = {}
    for _, lv in ipairs({ 1, 20, 40, 60 }) do
        local t = T.Text(f, "mono", 8.5, C.disabled)
        t:SetText(tostring(lv))
        ticks[#ticks + 1] = { t, lv }
    end
    local function X(lv)
        local w = s:GetWidth() - 14
        return 7 + w * (lv - 1) / (SR.MAX_LEVEL - 1)
    end
    local function Place()
        for _, t in ipairs(ticks) do
            t[1]:ClearAllPoints()
            t[1]:SetPoint("TOP", s, "TOPLEFT", X(t[2]), -19)
        end
        if f.real then
            you:ClearAllPoints()
            you:SetPoint("CENTER", s, "LEFT", X(f.real), 0)
        end
    end
    s:SetScript("OnSizeChanged", Place)
    s:SetScript("OnValueChanged", function(_, v, user)
        v = math.floor(v + 0.5)
        f.value:SetText(tostring(v))
        if user then f.pending = v end
    end)
    -- Commit on release so the list rebuilds once per drag, not per pixel.
    s:SetScript("OnMouseUp", function()
        if not f.pending then return end
        local v = f.pending
        f.pending = nil
        SR.char.level = v ~= SR.RoundUp5(SR.PlayerLevel()) and v or nil
        SR.Notify("list")
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(_, d)
        local v = math.max(1, math.min(SR.MAX_LEVEL, (SR.char.level or SR.RoundUp5(SR.PlayerLevel())) + (d > 0 and 1 or -1)))
        SR.char.level = v ~= SR.RoundUp5(SR.PlayerLevel()) and v or nil
        SR.Notify("list")
    end)
    function f:Set(level, real, isAuto)
        self.real = real
        s:SetValue(level)
        self.value:SetText(tostring(level))
        self.auto:SetShown(isAuto)
        youText:SetText("you " .. real)
        Place()
    end
    return f
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------
local function Build(AHF)
    P = CreateFrame("Frame", "SnackrunPanel", AHF)
    for k, v in pairs(Panel) do P[k] = v end
    SR.panel = P
    P:SetPoint("TOPLEFT", AHF, "TOPLEFT", 6, -26)
    P:SetPoint("BOTTOMRIGHT", AHF, "BOTTOMRIGHT", -6, 28)
    P:SetFrameLevel(AHF:GetFrameLevel() + 2)
    P:EnableMouse(true)
    P.rows, P.sections, P.filter = {}, {}, ""
    T.Box(P, 8, C.window, C.border)

    ----------------------------------------------------------------------- rail
    local rail = CreateFrame("Frame", nil, P)
    rail:SetPoint("TOPLEFT", 1, -1)
    rail:SetPoint("BOTTOMLEFT", 1, 1)
    rail:SetWidth(RAIL_W)
    T.Fill(rail, C.sidebar)
    T.Line(rail, "RIGHT", C.line)

    local brand = CreateFrame("Frame", nil, rail)
    brand:SetPoint("TOPLEFT")
    brand:SetPoint("TOPRIGHT")
    brand:SetHeight(BRAND_H)
    brand:SetClipsChildren(true)
    T.Line(brand, "BOTTOM", C.line)
    W.Brand(brand, RAIL_W, BRAND_H, 48, 18, version and ("v" .. version) or nil) -- logo clears the AH portrait

    local x, inner = 14, RAIL_W - 28
    local y = -(BRAND_H + 12)
    local eyebrow = Caps(rail, "Shopping for", 9)
    eyebrow:SetPoint("TOPLEFT", x, y)
    P.reset = CreateFrame("Button", nil, rail)
    P.reset:SetSize(90, 14)
    P.reset:SetPoint("TOPRIGHT", -x, y + 2)
    P.reset.text = Caps(P.reset, "Reset to me", 9, C.quiet)
    P.reset.text:SetPoint("RIGHT")
    P.reset.text:SetJustifyH("RIGHT")
    P.reset:SetScript("OnClick", SR.ResetToMe)
    P.reset:SetScript("OnEnter", function(self) self.text:SetTextColor(T.RGBA(C.accent)); W.Tip(self, "Back to your own spec, weapons and level.") end)
    P.reset:SetScript("OnLeave", function(self) self.text:SetTextColor(T.RGBA(C.quiet)); GameTooltip:Hide() end)
    y = y - 18
    P.who = T.Text(rail, "bold", 13, C.text)
    P.who:SetPoint("TOPLEFT", x, y)
    P.who:SetWidth(inner)
    P.whoSub = T.Text(rail, "semibold", 11.5, C.quiet)
    P.whoSub:SetPoint("TOPLEFT", x, y - 17)
    y = y - 40

    P.profile = W.Picker(rail, "Profile", inner)
    P.profile:SetPoint("TOPLEFT", x, y)
    P.profile.tip = "Auto builds the list from your spec and level. Your own profiles show exactly what you picked."
    P.profile:SetScript("OnClick", function(self)
        local cur = SR.char.profile
        local e = { { text = "Auto", right = "spec + level", checked = cur == "auto", onClick = function() SR.SetProfile("auto") end } }
        for _, n in ipairs(SR.ProfileNames()) do
            e[#e + 1] = { text = n, right = tostring(SR.ProfileSize(n)), checked = cur == n, onClick = function() SR.SetProfile(n) end }
        end
        e[#e + 1] = { sep = true }
        e[#e + 1] = { text = "Edit profiles…", onClick = function() SR.OpenOptions("profiles") end }
        W.OpenMenu(self, e, { width = inner })
    end)
    y = y - 52

    P.autoOnly, P.customOnly = {}, {}
    local half = (inner - 6) / 2
    P.spec = W.Picker(rail, "Spec", half)
    P.specHalf, P.specFull = half, inner
    P.spec:SetPoint("TOPLEFT", x, y)
    P.spec.tip = "Your talent tree with the most points. Pick another to shop for it."
    P.spec:SetScript("OnClick", function(self)
        local ctx = SR.Context()
        local e = {}
        for _, s in ipairs(ctx.cls and ctx.cls.specs or {}) do
            e[#e + 1] = { text = s.name, right = s.key == ctx.specDetected and "talents" or nil, checked = ctx.spec == s,
                onClick = function() SR.char.spec = s.key ~= ctx.specDetected and s.key or nil; SR.Notify("list") end }
        end
        if #e > 0 then W.OpenMenu(self, e, { width = inner }) end
    end)
    P.weapons = W.Picker(rail, "Weapons", half)
    P.weapons:SetPoint("TOPLEFT", P.spec, "TOPRIGHT", 6, 0)
    P.weapons.tip = "Blades take sharpening stones, maces and fists take weightstones. Read from your gear."
    P.weapons:SetScript("OnClick", function(self)
        local ctx, gear = SR.Context(), SR.DetectWeapons()
        local e = {}
        for _, w in ipairs({ { "blade", "Blade" }, { "blunt", "Blunt" }, { "both", "Both" } }) do
            e[#e + 1] = { text = w[2], right = w[1] == gear and "gear" or nil, checked = ctx.weapons == w[1],
                onClick = function() SR.char.weapons = w[1] ~= gear and w[1] or nil; SR.Notify("list") end }
        end
        W.OpenMenu(self, e, { width = inner })
    end)
    P.level = LevelCard(rail, inner)
    P.level:SetPoint("TOPLEFT", x, y - 52)
    for _, f in ipairs({ P.spec, P.weapons, P.level }) do P.autoOnly[#P.autoOnly + 1] = f end

    -- Custom profiles: a note in place of spec / weapons / level, and the way into the editor.
    local note = CreateFrame("Frame", nil, rail)
    note:SetSize(inner, 58)
    note:SetPoint("TOPLEFT", x, y)
    T.Box(note, 7, C.inset, C.border)
    local nt = T.Text(note, "medium", 11.5, C.quiet)
    nt:SetPoint("TOPLEFT", 12, -10)
    nt:SetPoint("RIGHT", -12, 0)
    nt:SetWordWrap(true)
    nt:SetSpacing(3)
    nt:SetText(T.Code(C.label) .. "Hand-picked list.|r Spec, weapons and level don't apply here.")
    local edit = W.Button(rail, "Edit profile…", { width = inner, height = 30, onClick = function() SR.OpenOptions("profiles", SR.char.profile) end })
    edit:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -10)
    P.customOnly = { note, edit }

    -- Rail foot: scan
    local foot = CreateFrame("Frame", nil, rail)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(84)
    T.Line(foot, "TOP", C.line)
    P.scanBtn = W.Button(foot, "Scan list", { width = inner, height = 34, style = "strong", icon = "Scan",
        tip = "Look up the lowest price of every item on the list, one search at a time.",
        onClick = function()
            if SR.scan.running then SR.StopScan() else SR.StartScan(SR.ScanIDs(P.list or SR.BuildList())) end
        end })
    P.scanBtn:SetPoint("TOPLEFT", x, -12)
    P.scanBtn.count = T.Text(P.scanBtn, "mono", 11, C.quiet)
    P.scanBtn.count:SetPoint("RIGHT", -12, 0)
    P.prog = CreateFrame("Frame", nil, foot)
    P.prog:SetPoint("TOPLEFT", P.scanBtn, "BOTTOMLEFT", 0, -10)
    P.prog:SetSize(inner, 20)
    P.progText = T.Text(P.prog, "medium", 10.5, C.quiet)
    P.progText:SetPoint("TOPLEFT")
    local bar = T.Fill(P.prog, C.track, "ARTWORK")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(3)
    P.progFill = T.Fill(P.prog, C.bone, "ARTWORK", 1)
    P.progFill:SetPoint("BOTTOMLEFT")
    P.progFill:SetHeight(3)
    P.prog:Hide()

    ----------------------------------------------------------------------- main
    local main = CreateFrame("Frame", nil, P)
    main:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
    main:SetPoint("BOTTOMRIGHT", -1, 1)

    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    T.Fill(head, C.header)
    T.Line(head, "BOTTOM", C.line)
    P.title = T.Text(head, "heavy", 16, C.text)
    P.title:SetPoint("TOPLEFT", PAD, -14)
    P.subtitle = T.Text(head, "medium", 11.5, C.quiet)
    P.subtitle:SetPoint("TOPLEFT", P.title, "BOTTOMLEFT", 0, -4)
    P.subtitle:SetPoint("RIGHT", head, "RIGHT", -180, 0)
    local search = W.Field(head, 150, "Filter", "Search", function(text)
        P.filter = strtrim(text):lower()
        P:Refresh()
    end)
    search:SetPoint("RIGHT", -PAD, 0)

    local cols = CreateFrame("Frame", nil, main)
    cols:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    cols:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
    cols:SetHeight(COLS_H)
    T.Line(cols, "BOTTOM", C.line)
    local function Col(text, right, left)
        local fs = Caps(cols, text, 8.5)
        if left then fs:SetPoint("LEFT", left, 0) else fs:SetPoint("RIGHT", cols, "RIGHT", right, 0); fs:SetJustifyH("RIGHT") end
    end
    Col("Item", nil, PAD + 39)
    Col("Bags", COL.bags)
    Col("Want", COL.want)
    Col("Lowest", COL.lowest)
    Col("Listed", COL.listed)

    local mfoot = CreateFrame("Frame", nil, main)
    mfoot:SetPoint("BOTTOMLEFT")
    mfoot:SetPoint("BOTTOMRIGHT")
    mfoot:SetHeight(FOOT_H)
    T.Fill(mfoot, C.header)
    T.Line(mfoot, "TOP", C.line)
    P.scanned = T.Text(mfoot, "mono", 10.5, C.dim)
    P.scanned:SetPoint("LEFT", PAD, 0)
    P.total = T.Text(mfoot, "mono", 14, C.text)
    P.total:SetPoint("RIGHT", -PAD, 0)
    P.total:SetJustifyH("RIGHT")
    local tl = Caps(mfoot, "To fill list", 8.5)
    tl:SetPoint("RIGHT", P.total, "LEFT", -10, 0)

    P.scroll = W.Scroll(main)
    P.scroll:SetPoint("TOPLEFT", cols, "BOTTOMLEFT", 0, 0)
    P.scroll:SetPoint("BOTTOMRIGHT", mfoot, "TOPRIGHT", 0, 0)
    P.empty = T.Text(main, "medium", 12.5, C.dim)
    P.empty:SetPoint("TOP", P.scroll, "TOP", 0, -40)
    P.empty:SetWidth(360)
    P.empty:SetWordWrap(true)
    P.empty:SetJustifyH("CENTER")

    P:SetScript("OnShow", function(self)
        SR.PauseScan(false)
        self:Refresh()
    end)
    P:SetScript("OnHide", function()
        SR.PauseScan(true)
        W.CloseMenu()
    end)
    P:Hide()
    return P
end

--------------------------------------------------------------------------------
-- The tab
--------------------------------------------------------------------------------
local tab, selecting, AnchorTab

local function LibTabs()
    local lib = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibAHTab-1-0", true)
    local state = lib and lib.internalState
    return state and state.Tabs or {}
end

local function Select()
    local AHF = AuctionHouseFrame
    selecting = true
    AHF:SetDisplayMode({}) -- hides every Blizzard panel
    selecting = false
    AHF.displayMode = nil
    for _, t in ipairs(AHF.Tabs or {}) do PanelTemplates_DeselectTab(t) end
    -- Other addons' LibAHTab tabs pass {} too, so their hook leaves their panel up: put it away ourselves.
    for _, t in ipairs(LibTabs()) do
        if t.frameRef then t.frameRef:Hide() end
        PanelTemplates_DeselectTab(t)
    end
    PanelTemplates_SelectTab(tab)
    if AHF.SetTitle then AHF:SetTitle("Snackrun") end
    P:Show()
end

-- Does `region` hang off `target` through its anchors (directly or down the chain)? Anchoring target to such a
-- region is the "Cannot anchor to a region dependent on it" error.
local function DependsOn(region, target, depth)
    if region == target then return true end
    if (depth or 0) > 40 or not region.GetNumPoints then return false end
    for i = 1, region:GetNumPoints() do
        local _, rel = region:GetPoint(i)
        if rel and DependsOn(rel, target, (depth or 0) + 1) then return true end
    end
    return false
end

-- The last tab along the bottom that does not hang off ours: another addon's LibAHTab tab if there is one, else
-- Blizzard's last. LibAHTab chains its row onto AuctionHouseFrame.Tabs[#Tabs], so ours must never be in that array
-- (see CreateTab) and must never anchor to anything chained behind it.
local function LastTab(AHF)
    local candidates = {}
    for _, t in ipairs(AHF.Tabs) do if t ~= tab then candidates[#candidates + 1] = t end end
    for _, t in ipairs(LibTabs()) do candidates[#candidates + 1] = t end
    for i = #candidates, 1, -1 do
        local t = candidates[i]
        if t:IsShown() and not DependsOn(t, tab) then return t end
    end
    return AHF.Tabs[1]
end

-- Re-run on every AH open: another addon may add its tabs after ours exists.
AnchorTab = function()
    if not tab then return end
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", LastTab(AuctionHouseFrame), "TOPRIGHT", 3, 0) -- Forever uses the mainline tab spacing
end

local function CreateTab()
    local AHF = AuctionHouseFrame
    if tab or not AHF or not AHF.Tabs then return end
    Build(AHF)
    -- The tab template carries parentArray="Tabs": parented straight to the AH it would join AuctionHouseFrame.Tabs,
    -- other addons would chain their tabs onto it, and anchoring after them loops. A holder keeps it out.
    local holder = CreateFrame("Frame", nil, AHF)
    holder:SetSize(1, 1)
    holder:SetPoint("BOTTOMLEFT")
    tab = CreateFrame("Button", "SnackrunAHTab", holder, "AuctionHouseFrameDisplayModeTabTemplate")
    tab:SetText("Snackrun")
    PanelTemplates_TabResize(tab, 20, nil, 70)
    PanelTemplates_DeselectTab(tab)
    tab:SetScript("OnClick", Select)
    AnchorTab()
    AHF:HookScript("OnShow", AnchorTab)
    -- Any display mode change we did not make (a Blizzard tab, or another addon's tab, which passes {} like we
    -- do) means someone else owns the frame now.
    hooksecurefunc(AHF, "SetDisplayMode", function()
        if selecting then return end
        P:Hide()
        PanelTemplates_DeselectTab(tab)
    end)
    SR.tab = tab
end

SR.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_AuctionHouseUI" then CreateTab() end
end)
SR.On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then CreateTab() end
end)
SR.On("AUCTION_HOUSE_SHOW", function()
    CreateTab()
    C_Timer.After(0, AnchorTab)
end)

--------------------------------------------------------------------------------
-- Redraw triggers
--------------------------------------------------------------------------------
local function Dirty() if P then P:Refresh() end end
for _, what in ipairs({ "list", "want", "names", "prices", "profiles" }) do SR.Listen(what, Dirty) end
SR.Listen("scan", function(...) if P then P:OnScan(...) end end)
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED" }) do
    SR.On(e, Dirty)
end
