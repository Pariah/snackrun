-- The options window (Ledger style, like Tallymark's): sidebar with brand and nav, ruled header, page body, footer.
-- Pages: General (what Snackrun does, slash commands) and Profiles (this character's hand-picked lists: New, Rename,
-- Start from Auto, Delete; the catalog with a checkbox and Want per item). Everything saves as you click.
-- SR.OpenOptions(page, profileName) opens it; /snack too.
local ADDON, SR = ...
local T, W = SR.Theme, SR.W
local C = T.C

local WIN_W, WIN_H, SIDE_W, HEAD_H, FOOT_H = 1000, 640, 210, 96, 52
local PAD = 28
local ROW_H, SEC_H = 38, 30
-- Catalog columns, right edges from the row's right side (mockup: 22 | 28 | name | 54 | 64, gap 12).
local COL_WANT, COL_LVL = -PAD, -PAD - 64 - 12

local O -- the window
local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")

local PAGES = {
    { key = "general", name = "General", icon = "General" },
    { key = "profiles", name = "Profiles", icon = "Profiles" },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function ToonName()
    local first, surname = UnitFullName("player")
    local name = first or UnitName("player") or "?"
    if surname and surname ~= "" and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then name = name .. " " .. surname end
    local _, class = UnitClass("player")
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, name) or name
end

-- A button that asks twice: the first click arms it ("Sure?"), the second within 4 seconds acts.
local function Confirm(button, label, armed, fn)
    button:SetScript("OnClick", function(self)
        if self.armed then
            self.armed = nil
            self:SetText(label)
            fn()
        else
            self.armed = true
            self:SetText(armed)
            C_Timer.After(4, function() if self.armed then self.armed = nil; self:SetText(label) end end)
        end
    end)
end

-- Items the player's class could ever see in Auto (any spec, any level, either weapon).
local function ClassItems()
    local class = SR.PlayerClass()
    local cls = SR.CLASSES[class]
    local set = {}
    if not cls then return set end
    for _, spec in ipairs(cls.specs) do
        local wants = SR.Wants({ spec = spec, cls = cls })
        for id, item in pairs(SR.ITEMS) do
            if SR.Match(item, wants) ~= nil and (not item.class or item.class[class]) then set[id] = true end
        end
    end
    return set
end

--------------------------------------------------------------------------------
-- Profiles page
--------------------------------------------------------------------------------
local Profiles = {}

local function Chip(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(32)
    b.box = T.Box(b, 7, C.control, C.border)
    b.text = T.Text(b, "bold", 12.5, C.quiet)
    b.text:SetPoint("LEFT", 14, 0)
    b.count = T.Text(b, "mono", 10.5, C.dim)
    b.count:SetPoint("LEFT", b.text, "RIGHT", 8, 0)
    function b:Set(text, count, on, add)
        self.text:SetText(text)
        self.count:SetText(count or "")
        local w = self.text:GetStringWidth() + (count and (self.count:GetStringWidth() + 8) or 0) + 28
        self:SetWidth(math.ceil(w))
        self.on = on
        self.box:SetFill(on and { 0.17, 0.2, 0.14, 1 } or add and C.window or C.control) -- accent wash, opaque
        self.box:SetBorder(on and C.accentLine or C.border)
        self.text:SetTextColor(T.RGBA(on and C.text or C.quiet))
    end
    b:SetScript("OnEnter", function(self) if not self.on then self.box:SetBorder(C.borderHover) end end)
    b:SetScript("OnLeave", function(self) if not self.on then self.box:SetBorder(C.border) end end)
    return b
end

local function CatRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r:EnableMouse(true)
    r.stripe = T.Fill(r, C.stripe)
    r.stripe:SetAllPoints()
    r.check = W.Check(r, function(_, on)
        if O.sel then SR.SetInProfile(O.sel, r.id, on) end
    end)
    r.check:SetPoint("LEFT", PAD + 3, 0)
    r.iconFrame = CreateFrame("Frame", nil, r)
    r.iconFrame:SetSize(26, 26)
    r.iconFrame:SetPoint("LEFT", PAD + 22 + 12, 0)
    r.iconBox = T.Box(r.iconFrame, 5, C.control, C.border, "ARTWORK")
    r.icon = r.iconFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    r.icon:SetPoint("TOPLEFT", 2, -2)
    r.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = T.Text(r, "semibold", 13, C.text)
    r.name:SetPoint("LEFT", r.iconFrame, "RIGHT", 12, 0)
    r.fx = T.Text(r, "medium", 11, C.dim)
    r.fx:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.fx:SetPoint("RIGHT", r, "RIGHT", COL_LVL - 54 - 12, 0)
    r.lvl = T.Text(r, "mono", 11.5, C.quiet)
    r.lvl:SetPoint("RIGHT", r, "RIGHT", COL_LVL, 0)
    r.lvl:SetJustifyH("RIGHT")
    r.want = W.NumberBox(r, 44, function(box, n) SR.SetWant(box.editId or r.id, n) end)
    r.want:SetPoint("RIGHT", r, "RIGHT", COL_WANT, 0)
    r.want:HookScript("OnEditFocusGained", function(box) box.editId = r.id; O.editing = box end)
    r.want:HookScript("OnEditFocusLost", function(box)
        if O.editing == box then O.editing = nil end
        if O.dirty then O:Rebuild() end
    end)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 4, 0)
        GameTooltip:SetItemByID(self.id)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and O.sel then SR.SetInProfile(O.sel, self.id, not SR.ProfileHas(O.sel, self.id)) end
    end)
    return r
end

function Profiles.Build(page)
    local p = {}
    page.state = p
    local body = page

    -- Row 1: chips (left), actions (right)
    p.chips, p.chipBar = {}, CreateFrame("Frame", nil, body)
    p.chipBar:SetPoint("TOPLEFT", PAD, -18)
    p.chipBar:SetPoint("TOPRIGHT", -PAD, -18)
    p.chipBar:SetHeight(32)
    p.newChip = Chip(p.chipBar)
    p.newChip:SetScript("OnClick", function()
        local name = SR.CreateProfile()
        O.sel = name
        O:Rebuild()
        Profiles.StartRename(page)
    end)
    p.delete = W.Button(p.chipBar, "Delete", { style = "ghost", height = 28 })
    p.delete.label:SetTextColor(T.RGBA(C.low))
    p.delete:SetPoint("RIGHT", 0, 0)
    Confirm(p.delete, "Delete", "Sure? Delete", function()
        if O.sel then SR.DeleteProfile(O.sel); O.sel = nil; O:Rebuild() end
    end)
    p.delete:HookScript("OnLeave", function(self) self.label:SetTextColor(T.RGBA(C.low)) end)
    p.fromAuto = W.Button(p.chipBar, "Start from Auto", { style = "ghost", height = 28,
        tip = "Adds everything Auto lists for you right now. It never removes anything.",
        onClick = function() if O.sel then SR.FillFromAuto(O.sel) end end })
    p.fromAuto:SetPoint("RIGHT", p.delete, "LEFT", -8, 0)
    p.rename = W.Button(p.chipBar, "Rename", { style = "ghost", height = 28, onClick = function() Profiles.StartRename(page) end })
    p.rename:SetPoint("RIGHT", p.fromAuto, "LEFT", -8, 0)
    p.renameBox = W.Field(p.chipBar, 220, "Profile name")
    p.renameBox:SetPoint("RIGHT", p.rename, "LEFT", -8, 0)
    p.renameBox:Hide()
    p.renameBox:SetScript("OnEnterPressed", function(self)
        local new = strtrim(self:GetText() or "")
        if O.sel and new ~= "" and new ~= O.sel and SR.RenameProfile(O.sel, new) then O.sel = new end
        self:ClearFocus()
    end)
    p.renameBox:HookScript("OnEditFocusLost", function(self) self:Hide(); O:Rebuild() end)

    -- Row 2: search, segments, count
    local tools = CreateFrame("Frame", nil, body)
    tools:SetPoint("TOPLEFT", PAD, -66)
    tools:SetPoint("TOPRIGHT", -PAD, -66)
    tools:SetHeight(40)
    T.Line(tools, "BOTTOM", C.line)
    p.filter, p.view = "", "all"
    p.search = W.Field(tools, 240, "Search catalog", "Search", function(text)
        p.filter = strtrim(text):lower()
        Profiles.Fill(page)
    end)
    p.search:SetPoint("TOPLEFT", 0, 0)
    local _, classFile = UnitClass("player")
    local className = (UnitClass("player")) or "Class"
    p.seg = W.Segmented(tools, { { "all", "All" }, { "picked", "Picked" }, { "class", className } },
        function() return p.view end, function(v) p.view = v; Profiles.Fill(page) end)
    p.seg:SetPoint("LEFT", p.search, "RIGHT", 10, 0)
    p.cnt = T.Text(tools, "mono", 11, C.dim)
    p.cnt:SetPoint("RIGHT", 0, 6)
    p.cnt:SetJustifyH("RIGHT")
    p.classFile = classFile

    -- Column labels
    local cols = CreateFrame("Frame", nil, body)
    cols:SetPoint("TOPLEFT", 0, -106)
    cols:SetPoint("TOPRIGHT", 0, -106)
    cols:SetHeight(24)
    local function Col(text, right, left)
        local fs = T.Text(cols, "caps", 8.5, C.dim)
        fs:SetText(text:upper())
        if left then fs:SetPoint("LEFT", left, 0) else fs:SetPoint("RIGHT", cols, "RIGHT", right, 0); fs:SetJustifyH("RIGHT") end
    end
    Col("Item", nil, PAD + 22 + 12 + 26 + 12)
    Col("Level", COL_LVL)
    Col("Want", COL_WANT)

    p.scroll = W.Scroll(body)
    p.scroll:SetPoint("TOPLEFT", cols, "BOTTOMLEFT")
    p.scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    p.rows, p.secs = {}, {}
    p.empty = T.Text(body, "medium", 12.5, C.dim)
    p.empty:SetPoint("TOP", p.scroll, "TOP", 0, -40)
    p.empty:SetWidth(420)
    p.empty:SetWordWrap(true)
    p.empty:SetJustifyH("CENTER")
end

function Profiles.StartRename(page)
    local p = page.state
    if not O.sel then return end
    p.renameBox:Show()
    p.renameBox:SetText(O.sel)
    p.renameBox:SetFocus()
    p.renameBox:HighlightText()
end

function Profiles.Refresh(page)
    local p = page.state
    local names = SR.ProfileNames()
    if O.sel and not SR.char.profiles[O.sel] then O.sel = nil end
    O.sel = O.sel or (SR.char.profile ~= "auto" and SR.char.profile) or names[1]
    local x = 0
    for i, n in ipairs(names) do
        local chip = p.chips[i] or Chip(p.chipBar)
        p.chips[i] = chip
        chip:Set(n, tostring(SR.ProfileSize(n)), n == O.sel)
        chip:ClearAllPoints()
        chip:SetPoint("LEFT", p.chipBar, "LEFT", x, 0)
        chip:SetScript("OnClick", function() O.sel = n; O:Rebuild() end)
        chip:Show()
        x = x + chip:GetWidth() + 8
    end
    for i = #names + 1, #p.chips do p.chips[i]:Hide() end
    p.newChip:Set("+ New", nil, false, true)
    p.newChip:ClearAllPoints()
    p.newChip:SetPoint("LEFT", p.chipBar, "LEFT", x, 0)
    local has = O.sel ~= nil
    for _, b in ipairs({ p.rename, p.fromAuto, p.delete }) do b:SetShown(has) end
    Profiles.Fill(page)
end

function Profiles.Fill(page)
    local p = page.state
    local content = p.scroll.content
    local width = p.scroll:GetWidth()
    if width <= 0 then width = WIN_W - SIDE_W - 2 end
    local classSet = p.view == "class" and ClassItems() or nil
    local bySec, total, picked = {}, 0, 0
    for id, item in pairs(SR.ITEMS) do
        total = total + 1
        local isPicked = O.sel and SR.ProfileHas(O.sel, id)
        if isPicked then picked = picked + 1 end
        local ok = true
        if p.view == "picked" then ok = isPicked
        elseif classSet then ok = classSet[id] == true end
        if ok and p.filter ~= "" then
            local name = SR.ItemInfo(id) or ""
            ok = name:lower():find(p.filter, 1, true) ~= nil or (item.fx or ""):lower():find(p.filter, 1, true) ~= nil
        end
        if ok then
            bySec[item.sec] = bySec[item.sec] or {}
            table.insert(bySec[item.sec], id)
        end
    end
    p.cnt:SetText(("%d picked · %d in catalog"):format(picked, total))
    local y, ri, si = 0, 0, 0
    for _, s in ipairs(SR.SECTIONS) do
        local ids = bySec[s.key]
        if ids then
            table.sort(ids, function(a, b)
                local la, lb = SR.ITEMS[a].lvl or 1, SR.ITEMS[b].lvl or 1
                if la ~= lb then return la < lb end
                return (SR.ItemInfo(a) or tostring(a)) < (SR.ItemInfo(b) or tostring(b))
            end)
            si = si + 1
            local sec = p.secs[si]
            if not sec then
                sec = CreateFrame("Frame", nil, content)
                sec:SetHeight(SEC_H)
                sec.no = T.Text(sec, "mono", 11, C.accent)
                sec.no:SetPoint("BOTTOMLEFT", PAD, 6)
                sec.title = T.Text(sec, "caps", 10, C.label)
                sec.title:SetPoint("LEFT", sec.no, "RIGHT", 10, 0)
                sec.count = T.Text(sec, "mono", 11, C.dim)
                sec.count:SetPoint("BOTTOMRIGHT", -PAD, 6)
                sec.count:SetJustifyH("RIGHT")
                p.secs[si] = sec
            end
            local secPicked = 0
            for _, id in ipairs(ids) do if O.sel and SR.ProfileHas(O.sel, id) then secPicked = secPicked + 1 end end
            sec:ClearAllPoints()
            sec:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            sec:SetWidth(width)
            sec.no:SetText(("%02d"):format(s.index))
            sec.title:SetText(s.name:upper())
            sec.count:SetText(("%d / %d"):format(secPicked, #ids))
            sec:Show()
            y = y + SEC_H
            for i, id in ipairs(ids) do
                ri = ri + 1
                local r = p.rows[ri] or CatRow(content)
                p.rows[ri] = r
                r.id = id
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                r:SetWidth(width)
                r.stripe:SetShown(i % 2 == 0)
                local item = SR.ITEMS[id]
                local name, quality, icon = SR.ItemInfo(id)
                local on = O.sel and SR.ProfileHas(O.sel, id) or false
                r.check:SetShown(O.sel ~= nil)
                r.check:SetOn(on)
                r.icon:SetTexture(icon or 134400)
                local qr, qg, qb = T.Quality(quality)
                r.iconBox:SetBorder({ qr, qg, qb, 0.55 })
                r.name:SetText(name or ("Item " .. id))
                r.name:SetTextColor(qr, qg, qb, 1)
                local room = width - (PAD + 22 + 12 + 26 + 12) + (COL_LVL - 54 - 12) - 120
                r.name:SetWidth(math.max(60, math.min(r.name:GetUnboundedStringWidth() + 1, room)))
                r.fx:SetText(item.fx or "")
                local faded = O.sel ~= nil and not on
                r.name:SetAlpha(faded and 0.5 or 1)
                r.icon:SetAlpha(faded and 0.5 or 1)
                r.lvl:SetAlpha(faded and 0.5 or 1)
                r.lvl:SetText(tostring(item.lvl or 1))
                local want, set = SR.Want(id)
                r.want:SetValue(want, set)
                r.want:SetTextColor(T.RGBA(set and C.text or C.dim))
                r:Show()
                y = y + ROW_H
            end
        end
    end
    for i = ri + 1, #p.rows do p.rows[i]:Hide() end
    for i = si + 1, #p.secs do p.secs[i]:Hide() end
    p.scroll:SetContentHeight(y + 10)
    local empty
    if ri == 0 then empty = p.view == "picked" and "Nothing picked yet. Tick items under All." or "Nothing matches." end
    if not O.sel and ri > 0 then empty = nil end
    p.empty:SetText(empty or "")
    p.empty:SetShown(empty ~= nil)
end

-- Footer action: every Want on this page back to its default (two clicks).
function Profiles.Reset()
    for id in pairs(SR.char.wants) do SR.char.wants[id] = nil end
    SR.Notify("want")
end

--------------------------------------------------------------------------------
-- General page
--------------------------------------------------------------------------------
local General = {}
function General.Build(page)
    local fs = T.Text(page, "medium", 13, C.quiet)
    fs:SetPoint("TOPLEFT", PAD, -24)
    fs:SetWidth(WIN_W - SIDE_W - PAD * 2)
    fs:SetWordWrap(true)
    fs:SetSpacing(5)
    local L = T.Code(C.label)
    fs:SetText(L .. "Snackrun|r lives in the Auction House, on its own tab next to Buy, Sell and Auctions. "
        .. "It lists the consumables your class, spec and level should carry, prices them with one scan, and hands a "
        .. "clicked item to Blizzard's Buy tab.\n\n"
        .. L .. "Auto|r builds the list from your talents (the tree with the most points), your weapons and the level "
        .. "slider. " .. L .. "Profiles|r are your own lists for this character; pick one in the Auction House and it "
        .. "replaces Auto.\n\n"
        .. L .. "Want|r starts at a default. Change it and it is saved for this character and item, in every profile.\n\n"
        .. L .. "/snack|r opens this window. " .. L .. "/snack profiles|r opens the profile editor.")
end
function General.Refresh() end

local BUILDERS = { general = General, profiles = Profiles }
local HEADS = {
    general = { "Snackrun", function() return "Consumables for " .. ToonName() .. ", one tab in the Auction House." end },
    profiles = { "Profiles", function() return "Hand-picked lists for " .. ToonName() .. ". Pick one in the Auction House to replace Auto." end },
}

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local function Build()
    O = CreateFrame("Frame", "SnackrunOptions", UIParent)
    O:SetSize(WIN_W, WIN_H)
    O:SetPoint("CENTER")
    O:SetFrameStrata("DIALOG")
    O:SetToplevel(true)
    O:SetClampedToScreen(true)
    O:EnableMouse(true)
    O:SetMovable(true)
    O:RegisterForDrag("LeftButton")
    O:SetScript("OnDragStart", O.StartMoving)
    O:SetScript("OnDragStop", O.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SnackrunOptions")
    T.Box(O, 10, C.window, C.border)
    -- Shrink to fit small screens.
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if sw > 0 and sh > 0 then O:SetScale(math.min(1, (sw - 40) / WIN_W, (sh - 40) / WIN_H)) end

    -- Sidebar
    local side = CreateFrame("Frame", nil, O)
    side:SetPoint("TOPLEFT", 1, -1)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDE_W)
    T.Fill(side, C.sidebar)
    T.Line(side, "RIGHT", C.line)
    local brand = CreateFrame("Frame", nil, side)
    brand:SetPoint("TOPLEFT")
    brand:SetPoint("TOPRIGHT")
    brand:SetHeight(HEAD_H)
    brand:SetClipsChildren(true)
    T.Line(brand, "BOTTOM", C.line)
    W.Brand(brand, SIDE_W, HEAD_H, 26, 18, version and ("v" .. version) or nil)
    local group = T.Text(side, "caps", 9.5, C.dim)
    group:SetPoint("TOPLEFT", 24, -(HEAD_H + 22))
    group:SetText("SNACKRUN")
    O.nav = {}
    for i, pg in ipairs(PAGES) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(SIDE_W - 24, 34)
        b:SetPoint("TOPLEFT", 12, -(HEAD_H + 40 + (i - 1) * 36))
        b.bg = T.Round(b, 6, C.accentSoft)
        b.hover = T.Round(b, 6, C.hover, "BACKGROUND", 2)
        b.hover:SetShown(false)
        b.icon = T.Icon(b, pg.icon, 16, C.dim)
        b.icon:SetPoint("LEFT", 12, 0)
        b.text = T.Text(b, "semibold", 13, C.quiet)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 12, 0)
        b.text:SetText(pg.name)
        b.key = pg.key
        b:SetScript("OnClick", function() O:Show(); O:Open(pg.key) end)
        b:SetScript("OnEnter", function(self) if O.page ~= self.key then self.hover:SetShown(true) end end)
        b:SetScript("OnLeave", function(self) self.hover:SetShown(false) end)
        O.nav[i] = b
    end
    local sfoot = CreateFrame("Frame", nil, side)
    sfoot:SetPoint("BOTTOMLEFT")
    sfoot:SetPoint("BOTTOMRIGHT")
    sfoot:SetHeight(FOOT_H)
    T.Line(sfoot, "TOP", C.line)
    local v = T.Text(sfoot, "mono", 11, C.dim)
    v:SetPoint("LEFT", 18, 0)
    v:SetText(version and ("v" .. version) or "")
    local slash = T.Text(sfoot, "mono", 11, C.dim)
    slash:SetPoint("RIGHT", -18, 0)
    slash:SetText("/snack")

    -- Header: ruled paper with a double green margin
    local head = CreateFrame("Frame", nil, O)
    head:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(HEAD_H)
    head:SetClipsChildren(true)
    T.Fill(head, C.header)
    T.Line(head, "BOTTOM", C.line)
    for _, x in ipairs({ 14, 16 }) do
        local t = head:CreateTexture(nil, "BORDER")
        t:SetColorTexture(T.RGBA(C.accent, 0.30))
        t:SetWidth(T.Px(head))
        t:SetPoint("TOPLEFT", x, 0)
        t:SetPoint("BOTTOMLEFT", x, 0)
    end
    for _, y in ipairs({ 21, 43, 65, 87 }) do
        local t = head:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.035)
        t:SetHeight(T.Px(head))
        t:SetPoint("TOPLEFT", 30, -y)
        t:SetPoint("TOPRIGHT", 0, -y)
    end
    O.eyebrow = T.Text(head, "mono", 10.5, C.dim)
    O.eyebrow:SetPoint("TOPLEFT", 34, -18)
    O.title = T.Text(head, "heavy", 22, C.text)
    O.title:SetPoint("TOPLEFT", O.eyebrow, "BOTTOMLEFT", 0, -6)
    O.subtitle = T.Text(head, "medium", 12.5, C.quiet)
    O.subtitle:SetPoint("TOPLEFT", O.title, "BOTTOMLEFT", 0, -5)
    local close = CreateFrame("Button", nil, head)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -12, -10)
    close.icon = T.Icon(close, "Close", 16, C.quiet)
    close.icon:SetPoint("CENTER")
    close:SetScript("OnClick", function() O:Hide() end)
    close:SetScript("OnEnter", function(self) self.icon:SetVertexColor(T.RGBA(C.accent)) end)
    close:SetScript("OnLeave", function(self) self.icon:SetVertexColor(T.RGBA(C.quiet)) end)

    -- Footer
    local foot = CreateFrame("Frame", nil, O)
    foot:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(FOOT_H)
    T.Fill(foot, C.header)
    T.Line(foot, "TOP", C.line)
    local hint = T.Text(foot, "medium", 12, C.dim)
    hint:SetPoint("LEFT", PAD, 0)
    hint:SetText("Changes save as you click.")
    O.resetPage = W.Button(foot, "Reset page", { style = "ghost", height = 28,
        tip = "Every Want number back to its default, for this character." })
    O.resetPage:SetPoint("RIGHT", -PAD, 0)
    Confirm(O.resetPage, "Reset page", "Sure? Reset", Profiles.Reset)

    -- Pages
    O.pages = {}
    for _, pg in ipairs(PAGES) do
        local f = CreateFrame("Frame", nil, O)
        f:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
        f:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
        f:Hide()
        BUILDERS[pg.key].Build(f)
        O.pages[pg.key] = f
    end

    function O:Rebuild()
        if not self:IsShown() then return end
        if self.editing then self.dirty = true return end
        self.dirty = false
        local key = self.page
        local idx
        for i, pg in ipairs(PAGES) do
            local on = pg.key == key
            if on then idx = i end
            local b = self.nav[i]
            b.bg:SetShown(on)
            b.text:SetTextColor(T.RGBA(on and C.text or C.quiet))
            b.icon:SetVertexColor(T.RGBA(on and C.accent or C.dim))
            self.pages[pg.key]:SetShown(on)
        end
        local h = HEADS[key]
        self.eyebrow:SetText(("%s%02d|r · Settings"):format(T.Code(C.accent), idx))
        self.title:SetText(h[1])
        self.subtitle:SetText(h[2]())
        self.resetPage:SetShown(key == "profiles")
        BUILDERS[key].Refresh(self.pages[key])
    end

    function O:Open(key)
        self.page = BUILDERS[key] and key or "general"
        self:Rebuild()
    end

    O:SetScript("OnShow", function(self) self:Rebuild() end)
    O:SetScript("OnHide", function() W.CloseMenu() end)
    for _, what in ipairs({ "profiles", "want", "names", "list" }) do
        SR.Listen(what, function() if O:IsShown() then O:Rebuild() end end)
    end
    O:Hide()
    SR.optionsWindow = O
end

function SR.OpenOptions(page, profile)
    if not O then Build() end
    if profile and SR.char.profiles[profile] then O.sel = profile end
    O.page = page and BUILDERS[page] and page or O.page or "general"
    O:Show()
    O:Raise()
    O:Rebuild()
end
