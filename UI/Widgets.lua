-- Snackrun's small widget kit, Ledger style. Green only marks focus, the current choice and changed values.
--   W.Button(parent, text, o)        o: width, height, style ("default" | "ghost" | "strong"), icon, onClick, tip
--   W.OpenMenu(anchor, entries, o)   popup menu; entries { text, right, onClick, checked, header, sep, disabled }
--   W.Picker(parent, key, w)         the rail's two-line dropdown control (small caps key + value + chevron)
--   W.NumberBox(parent, w, onCommit) the Want box; :SetValue(n, changed) paints a green edge when changed
--   W.Check(parent, onClick)         a square checkbox; :SetOn(bool)
--   W.Field(parent, w, placeholder, icon, onChange)   a text box (search)
--   W.Segmented(parent, options, get, set)            pill group; options { {key, text} }
--   W.Scroll(parent)                 scroll frame; .content is the child to fill, :SetContentHeight(h)
--   W.Brand(frame, w, h, logoX, size, ver)   ruled-paper brand block: double margin, hairlines, ghost vial, logo
local _, SR = ...
local T = SR.Theme
local C = T.C

local W = {}
SR.W = W

function W.Tip(owner, text, anchor)
    if not text then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    if type(text) == "function" then text(GameTooltip) else GameTooltip:SetText(text, 1, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

--------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------
function W.Button(parent, text, o)
    o = o or {}
    local style = o.style or "default"
    local ghost, strong = style == "ghost", style == "strong"
    local rest = ghost and C.quiet or C.text
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(o.height or 30)
    b.label = T.Text(b, ghost and "semibold" or "bold", 12.5, rest)
    b.label:SetText(text or "")
    if o.icon then b.icon = T.Icon(b, o.icon, 14, rest) end
    local function Fit()
        local tw = b.label:GetStringWidth()
        if not o.width then b:SetWidth(math.ceil(tw + (o.icon and 22 or 0) + (strong and 40 or 26))) end
        b.label:ClearAllPoints()
        if b.icon then
            b.icon:ClearAllPoints()
            b.icon:SetPoint("CENTER", b, "CENTER", -(tw + 8) / 2, 0)
            b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
        else
            b.label:SetPoint("CENTER")
        end
    end
    if o.width then b:SetWidth(o.width) end
    Fit()
    b:HookScript("OnShow", function() Fit(); C_Timer.After(0, Fit) end)
    b.Fit = Fit
    local box, wash
    if ghost then
        box = T.Box(b, 6, C.window, C.border)
        wash = T.Round(b, 5, C.hover, "BORDER")
        wash:SetShown(false)
    else
        box = T.Box(b, 6, C.control, strong and C.borderHover or C.border)
    end
    function b:SetText(t) self.label:SetText(t or ""); Fit() end
    function b:SetEnabledLook(on)
        self:SetEnabled(on)
        self.label:SetTextColor(T.RGBA(on and rest or C.disabled))
        if self.icon then self.icon:SetVertexColor(T.RGBA(on and rest or C.disabled)) end
    end
    b:SetScript("OnEnter", function(self)
        if wash then wash:SetShown(true) else box:SetFill(C.controlHover) end
        box:SetBorder(strong and C.accent or C.borderHover)
        self.label:SetTextColor(T.RGBA(C.text))
        if self.icon then self.icon:SetVertexColor(T.RGBA(strong and C.accent or C.text)) end
        W.Tip(self, o.tip)
    end)
    b:SetScript("OnLeave", function(self)
        if wash then wash:SetShown(false) else box:SetFill(C.control) end
        box:SetBorder(strong and C.borderHover or C.border)
        if self:IsEnabled() then
            self.label:SetTextColor(T.RGBA(rest))
            if self.icon then self.icon:SetVertexColor(T.RGBA(rest)) end
        end
        HideTip()
    end)
    b:SetScript("OnClick", function(self, button) if o.onClick then o.onClick(self, button) end end)
    return b
end

--------------------------------------------------------------------------------
-- Popup menu: one shared frame and a screen-wide catcher that closes it on any outside click.
--------------------------------------------------------------------------------
local menu, catcher
local MENU_ROW, MENU_W = 28, 214

function W.CloseMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
end

local function MenuFrame()
    if menu then return menu end
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", W.CloseMenu)
    menu = CreateFrame("Frame", nil, catcher)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 5)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    T.Box(menu, 8, C.menu, C.borderHover)
    menu.rows = {}
    return menu
end

local function MenuRow(i)
    local it = menu.rows[i]
    if it then return it end
    it = CreateFrame("Button", nil, menu)
    it.hl = T.Round(it, 5, C.accentSoft)
    it.hl:SetShown(false)
    it.check = T.Icon(it, "Check", 12, C.accent)
    it.check:SetPoint("LEFT", 9, 0)
    it.text = T.Text(it, "semibold", 12.5, C.label)
    it.right = T.Text(it, "mono", 10.5, C.dim)
    it.right:SetPoint("RIGHT", -9, 0)
    it.right:SetJustifyH("RIGHT")
    it.rule = it:CreateTexture(nil, "ARTWORK")
    it.rule:SetColorTexture(T.RGBA(C.line))
    it.rule:SetHeight(T.Px(it))
    it.rule:SetPoint("LEFT", 2, 0)
    it.rule:SetPoint("RIGHT", -2, 0)
    it:SetScript("OnEnter", function(self)
        if self.active then self.hl:SetShown(true); self.text:SetTextColor(T.RGBA(C.text)) end
    end)
    it:SetScript("OnLeave", function(self)
        self.hl:SetShown(false)
        if self.active then self.text:SetTextColor(T.RGBA(C.label)) end
    end)
    it:SetScript("OnClick", function(self)
        if not self.active then return end
        local fn = self.onClick
        W.CloseMenu()
        if fn then fn() end
    end)
    menu.rows[i] = it
    return it
end

-- o.atCursor: open at the mouse (right-click menus); else below the anchor, left edges aligned.
function W.OpenMenu(anchor, entries, o)
    o = o or {}
    MenuFrame()
    local y, width = -5, o.width or MENU_W
    for i, e in ipairs(entries) do
        local it = MenuRow(i)
        local h = e.sep and 9 or e.header and 24 or MENU_ROW
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, y)
        it:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -5, y)
        it:SetHeight(h)
        y = y - h
        it.rule:SetShown(e.sep == true)
        it.text:SetShown(not e.sep)
        it.right:SetText(e.right or "")
        it.right:SetShown(e.right ~= nil and not e.sep)
        it.check:SetShown(e.checked == true)
        it.active = not (e.sep or e.header or e.disabled)
        it.onClick = e.onClick
        it.hl:SetShown(false)
        it.text:ClearAllPoints()
        if e.header then
            it.text:SetFont(T.UI.caps, 9, "")
            it.text:SetTextColor(T.RGBA(C.dim))
            it.text:SetPoint("LEFT", 9, -2)
            it.text:SetText((e.text or ""):upper())
        else
            it.text:SetFont(T.UI.semibold, 12.5, "")
            it.text:SetTextColor(T.RGBA(e.disabled and C.disabled or C.label))
            it.text:SetPoint("LEFT", 26, 0)
            it.text:SetPoint("RIGHT", it.right, "LEFT", -6, 0)
            it.text:SetText(e.text or "")
        end
        it:Show()
    end
    for i = #entries + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(width, -y + 5)
    menu:ClearAllPoints()
    if o.atCursor then
        local x, cy = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 2, cy / s - 2)
    else
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    end
    catcher:Show()
    menu:Show()
end

--------------------------------------------------------------------------------
-- The rail's picker: a 42px control with a small caps key over the value, chevron on the right.
--------------------------------------------------------------------------------
function W.Picker(parent, key, width)
    local p = CreateFrame("Button", nil, parent)
    p:SetSize(width, 42)
    p.box = T.Box(p, 7, C.control, C.border)
    p.key = T.Text(p, "caps", 8.5, C.dim)
    p.key:SetPoint("TOPLEFT", 10, -7)
    p.key:SetText(key:upper())
    p.tag = T.Text(p, "mono", 8.5, C.dim)
    p.tag:SetPoint("LEFT", p.key, "RIGHT", 6, 0)
    p.value = T.Text(p, "bold", 12.5, C.text)
    p.value:SetPoint("BOTTOMLEFT", 10, 7)
    p.value:SetPoint("RIGHT", p, "RIGHT", -26, 0)
    p.chev = T.Icon(p, "ChevronDown", 12, C.quiet)
    p.chev:SetPoint("RIGHT", -10, 0)
    function p:Set(value, tag)
        self.value:SetText(value or "")
        self.tag:SetText(tag or "")
    end
    p:SetScript("OnEnter", function(self)
        self.box:SetFill(C.controlHover)
        self.box:SetBorder(C.borderHover)
        W.Tip(self, self.tip)
    end)
    p:SetScript("OnLeave", function(self)
        self.box:SetFill(C.control)
        self.box:SetBorder(C.border)
        HideTip()
    end)
    return p
end

--------------------------------------------------------------------------------
-- Number box (Want)
--------------------------------------------------------------------------------
function W.NumberBox(parent, width, onCommit)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, 22)
    e:SetAutoFocus(false)
    e:SetNumeric(true)
    e:SetMaxLetters(4)
    e:SetJustifyH("CENTER")
    e:SetFont(T.UI.mono, 11.5, "")
    e:SetTextColor(T.RGBA(C.text))
    e:SetShadowOffset(0, 0)
    e:SetTextInsets(2, 2, 0, 0)
    e.box = T.Box(e, 4, C.field, C.border)
    e.changed = false
    function e:Paint()
        if self:HasFocus() then self.box:SetBorder(C.accent)
        elseif self.changed then self.box:SetBorder(C.accentLine)
        else self.box:SetBorder(C.border) end
    end
    function e:SetValue(n, changed)
        self.changed = changed and true or false
        self.last = tostring(n or "")
        if not self:HasFocus() then self:SetText(self.last) end
        self:Paint()
    end
    local function Commit(self)
        local n = tonumber(self:GetText())
        if n and onCommit then onCommit(self, n) end
    end
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText(); self:Paint() end)
    e:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self.escaped then self.escaped = nil; self:SetText(self.last or "") else Commit(self) end
        self:Paint()
    end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self.escaped = true; self:ClearFocus() end)
    e:SetScript("OnTabPressed", function(self) self:ClearFocus() end)
    return e
end

--------------------------------------------------------------------------------
-- Checkbox
--------------------------------------------------------------------------------
function W.Check(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    b.box = T.Box(b, 4, C.field, C.borderHover)
    b.mark = T.Icon(b, "Check", 12, C.window)
    b.mark:SetPoint("CENTER")
    function b:SetOn(on)
        self.on = on and true or false
        self.box:SetFill(on and C.bone or C.field)
        self.box:SetBorder(on and C.bone or C.borderHover)
        self.mark:SetShown(self.on)
    end
    b:SetScript("OnClick", function(self) if onClick then onClick(self, not self.on) end end)
    b:SetOn(false)
    return b
end

--------------------------------------------------------------------------------
-- Text field
--------------------------------------------------------------------------------
function W.Field(parent, width, placeholder, icon, onChange)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, 28)
    e:SetAutoFocus(false)
    e:SetMaxLetters(60)
    e:SetFont(T.UI.medium, 12, "")
    e:SetTextColor(T.RGBA(C.text))
    e:SetShadowOffset(0, 0)
    local box = T.Box(e, 6, C.field, { 1, 1, 1, 0.08 })
    local x = 10
    if icon then
        local i = T.Icon(e, icon, 13, C.dim)
        i:SetPoint("LEFT", 9, 0)
        x = 28
    end
    e:SetTextInsets(x, 8, 0, 0)
    local ph = T.Text(e, "medium", 12, C.dim)
    ph:SetPoint("LEFT", x, 0)
    ph:SetText(placeholder or "")
    e:SetScript("OnTextChanged", function(self, user)
        ph:SetShown((self:GetText() or "") == "")
        if user and onChange then onChange(self:GetText() or "") end
    end)
    e:SetScript("OnEditFocusGained", function() box:SetBorder(C.accentLine) end)
    e:SetScript("OnEditFocusLost", function() box:SetBorder({ 1, 1, 1, 0.08 }) end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        if onChange then onChange("") end
        self:ClearFocus()
    end)
    return e
end

--------------------------------------------------------------------------------
-- Segmented pills
--------------------------------------------------------------------------------
function W.Segmented(parent, options, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(28)
    T.Box(f, 6, C.field, C.border)
    f.buttons = {}
    local x = 3
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b.key = opt[1]
        b.bg = T.Round(b, 5, C.accentSoft)
        b.text = T.Text(b, "bold", 11.5, C.quiet)
        b.text:SetPoint("CENTER")
        b.text:SetText(opt[2])
        local w = math.ceil(b.text:GetStringWidth()) + 22
        b:SetSize(math.max(w, 44), 22)
        b:SetPoint("LEFT", f, "LEFT", x, 0)
        x = x + b:GetWidth() + 2
        b:SetScript("OnClick", function(self) set(self.key); f:Refresh() end)
        f.buttons[i] = b
    end
    f:SetWidth(x + 1)
    function f:Refresh()
        local cur = get()
        for _, b in ipairs(self.buttons) do
            local on = b.key == cur
            b.bg:SetShown(on)
            b.text:SetTextColor(T.RGBA(on and C.text or C.quiet))
        end
    end
    f:Refresh()
    return f
end

--------------------------------------------------------------------------------
-- Scroll area with a thin thumb. Wheel scrolls 3 rows' worth.
--------------------------------------------------------------------------------
function W.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf.content = content
    local bar = CreateFrame("Frame", nil, sf)
    bar:SetPoint("TOPRIGHT", -3, -3)
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    bar:SetWidth(4)
    -- The thumb shape lives on its own frame so it can move.
    local thumbFrame = CreateFrame("Frame", nil, bar)
    thumbFrame:SetWidth(4)
    local shape = T.Round(thumbFrame, 2, C.track, "OVERLAY")
    sf.contentHeight = 0
    local function Layout()
        local h, view = sf.contentHeight, sf:GetHeight()
        content:SetWidth(sf:GetWidth())
        local range = math.max(0, h - view)
        if sf:GetVerticalScroll() > range then sf:SetVerticalScroll(range) end
        local show = range > 0 and view > 0
        shape:SetShown(show)
        thumbFrame:SetShown(show)
        if show then
            local th = math.max(24, view * view / h)
            local pos = (view - 6 - th) * (sf:GetVerticalScroll() / range)
            thumbFrame:SetHeight(th)
            thumbFrame:ClearAllPoints()
            thumbFrame:SetPoint("TOP", bar, "TOP", 0, -pos)
        end
    end
    function sf:SetContentHeight(h)
        self.contentHeight = h
        content:SetHeight(math.max(h, 1))
        Layout()
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, self.contentHeight - self:GetHeight())
        self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 120)))
        Layout()
    end)
    sf:SetScript("OnSizeChanged", Layout)
    return sf
end

--------------------------------------------------------------------------------
-- Brand block: double green margin rule, two hairlines from 30% across, the ghost vial in the corner, logo + word.
--------------------------------------------------------------------------------
function W.Brand(frame, width, h, logoX, wordSize, version)
    local function V(x)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(T.RGBA(C.accent, 0.30))
        t:SetWidth(T.Px(frame))
        t:SetPoint("TOPLEFT", x, 0)
        t:SetPoint("BOTTOMLEFT", x, 0)
    end
    V(12); V(14)
    for _, y in ipairs({ 20, 41 }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetHeight(T.Px(frame))
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.035))
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", width * 0.3, -y)
        t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
    end
    local ghost = frame:CreateTexture(nil, "BORDER")
    ghost:SetTexture(T.VIAL_BIG, nil, nil, "TRILINEAR")
    ghost:SetSize(h * 1.55, h * 1.55)
    ghost:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 16, 18)
    ghost:SetVertexColor(T.RGBA(C.accent, 0.07))
    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T.VIAL, nil, nil, "TRILINEAR")
    logo:SetSize(24, 24)
    logo:SetPoint("LEFT", frame, "LEFT", logoX, 0)
    logo:SetVertexColor(T.RGBA(C.accent))
    local word = T.Text(frame, "heavy", wordSize or 18, C.text)
    word:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    word:SetText("Snackrun")
    local ver = T.Text(frame, "mono", 10, C.dim)
    ver:SetPoint("BOTTOMLEFT", word, "BOTTOMRIGHT", 8, 2)
    ver:SetText(version or "")
    return logo, word
end
