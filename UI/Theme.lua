-- Snackrun's look: the Ledger tokens (warm charcoal, hairline rules, Manrope + IBM Plex Mono) with its own accent,
-- poison green #9EDB52, used only on the logo, section numbers, focus, active and changed values.
-- Media/ holds Snackrun's own copies: Manrope and IBM Plex Mono (SIL OFL, licences beside them, Plex unmodified),
-- Tabler outline icons (MIT) rasterised to white TGAs, the vial logo and a disc for rounded corners.
local _, SR = ...

local T = {}
SR.Theme = T

local MEDIA = "Interface\\AddOns\\Snackrun\\Media\\"
T.MEDIA = MEDIA
T.CIRCLE = MEDIA .. "Textures\\Circle32"
T.VIAL = MEDIA .. "Textures\\Vial64"
T.VIAL_BIG = MEDIA .. "Textures\\Vial256"

local function Hex(h, a)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end
T.Hex = Hex

T.C = {
    sidebar = Hex("0F0F0E"), inset = Hex("121110"), window = Hex("151413"), header = Hex("171615"),
    card = Hex("1A1918"), field = Hex("1B1A18"), control = Hex("201F1D"), controlHover = Hex("292725"),
    text = Hex("ECE8E1"), label = Hex("E2DDD4"), quiet = Hex("A39E95"), dim = Hex("8A857B"), disabled = Hex("6B665E"),
    bone = Hex("D9D2C3"), track = Hex("34322F"), menu = Hex("0F0F0E"),
    line = { 1, 1, 1, 0.07 }, border = { 1, 1, 1, 0.10 }, borderHover = { 1, 1, 1, 0.18 },
    stripe = { 1, 1, 1, 0.022 }, hover = { 1, 1, 1, 0.05 },
    accent = Hex("9EDB52"), accentSoft = Hex("9EDB52", 0.10), accentLine = Hex("9EDB52", 0.45),
    amber = Hex("E8B86A"), amberLine = Hex("E8B86A", 0.40), boneLine = Hex("D9D2C3", 0.35), low = Hex("E07A5F"),
    gold = Hex("E8C35A"), silver = Hex("BFC3CC"), copper = Hex("D08A52"),
}

function T.RGBA(c, a) return c[1], c[2], c[3], a or c[4] or 1 end

-- "|cffRRGGBB" for a token.
function T.Code(c)
    return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

T.UI = {
    medium = MEDIA .. "Fonts\\Manrope-Medium.ttf",
    semibold = MEDIA .. "Fonts\\Manrope-SemiBold.ttf",
    bold = MEDIA .. "Fonts\\Manrope-Bold.ttf",
    heavy = MEDIA .. "Fonts\\Manrope-ExtraBold.ttf",
    caps = MEDIA .. "Fonts\\Manrope-BoldTracked.ttf", -- letter-spaced, for small all-caps labels
    mono = MEDIA .. "Fonts\\IBMPlexMono-Medium.ttf",
}

-- A flat font string in one of the T.UI faces. Left-aligned, single line, no shadow.
function T.Text(parent, face, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(T.UI[face] or T.UI.medium, size, "")
    fs:SetTextColor(T.RGBA(color or T.C.text))
    fs:SetShadowOffset(0, 0)
    fs:SetWordWrap(false)
    fs:SetJustifyH("LEFT")
    return fs
end

function T.Px(frame)
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(1, frame:GetEffectiveScale(), 1)
    end
    return 1
end

function T.Icon(parent, name, size, color, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(MEDIA .. "Icons\\" .. name, nil, nil, "TRILINEAR")
    t:SetSize(size, size)
    t:SetVertexColor(T.RGBA(color or T.C.quiet))
    return t
end

function T.Fill(frame, c, layer, sub)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    tex:SetColorTexture(T.RGBA(c))
    return tex
end

-- A 1-pixel rule along one edge of a frame.
function T.Line(frame, edge, c, layer)
    local tex = frame:CreateTexture(nil, layer or "BORDER")
    tex:SetColorTexture(T.RGBA(c or T.C.line))
    local px = T.Px(frame)
    if edge == "TOP" or edge == "BOTTOM" then
        tex:SetPoint(edge .. "LEFT")
        tex:SetPoint(edge .. "RIGHT")
        tex:SetHeight(px)
    else
        tex:SetPoint("TOP" .. edge)
        tex:SetPoint("BOTTOM" .. edge)
        tex:SetWidth(px)
    end
    return tex
end

--------------------------------------------------------------------------------
-- Rounded rectangles: four corners cut from the disc plus three bands, never overlapping (translucent colours stay
-- even). T.Box adds a 1-pixel border: the border shape, then an opaque fill one pixel inside it.
--------------------------------------------------------------------------------
local Shape = {}
Shape.__index = Shape
function Shape:SetColor(r, g, b, a)
    for _, t in ipairs(self.round) do t:SetVertexColor(r, g, b, a or 1) end
    for _, t in ipairs(self.flat) do t:SetColorTexture(r, g, b, a or 1) end
end
function Shape:SetShown(on)
    for _, t in ipairs(self.round) do t:SetShown(on) end
    for _, t in ipairs(self.flat) do t:SetShown(on) end
end

local CORNERS = {
    { "TOPLEFT", 1, -1, 0, 0.5, 0, 0.5 },
    { "TOPRIGHT", -1, -1, 0.5, 1, 0, 0.5 },
    { "BOTTOMLEFT", 1, 1, 0, 0.5, 0.5, 1 },
    { "BOTTOMRIGHT", -1, 1, 0.5, 1, 0.5, 1 },
}

function T.Round(parent, radius, color, layer, sub, inset)
    inset, layer, sub = inset or 0, layer or "BACKGROUND", sub or 0
    local r = radius
    local s = setmetatable({ round = {}, flat = {} }, Shape)
    for _, c in ipairs(CORNERS) do
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetSize(r, r)
        t:SetPoint(c[1], parent, c[1], c[2] * inset, c[3] * inset)
        t:SetTexture(T.CIRCLE, nil, nil, "TRILINEAR")
        t:SetTexCoord(c[4], c[5], c[6], c[7])
        s.round[#s.round + 1] = t
    end
    local function Band(p1, x1, y1, p2, x2, y2)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetPoint("TOPLEFT", parent, p1, x1, y1)
        t:SetPoint("BOTTOMRIGHT", parent, p2, x2, y2)
        s.flat[#s.flat + 1] = t
    end
    Band("TOPLEFT", inset + r, -inset, "BOTTOMRIGHT", -inset - r, inset)
    Band("TOPLEFT", inset, -inset - r, "BOTTOMLEFT", inset + r, inset + r)
    Band("TOPRIGHT", -inset - r, -inset - r, "BOTTOMRIGHT", -inset, inset + r)
    s:SetColor(T.RGBA(color))
    return s
end

local Box = {}
Box.__index = Box
function Box:SetFill(c) self.fill:SetColor(T.RGBA(c)) end
function Box:SetBorder(c) self.edge:SetColor(T.RGBA(c)) end
function Box:SetShown(on) self.fill:SetShown(on); self.edge:SetShown(on) end

function T.Box(parent, radius, fill, border, layer, sub)
    local px = T.Px(parent)
    sub = sub or 0
    return setmetatable({
        edge = T.Round(parent, radius, border or T.C.border, layer, sub, 0),
        fill = T.Round(parent, math.max(radius - px, 1), fill, layer, sub + 1, px),
    }, Box)
end

--------------------------------------------------------------------------------
-- Money: "14g 20s 5c" in gold / silver / copper, zero parts left out. nil -> nil.
--------------------------------------------------------------------------------
function T.Money(copper)
    if not copper then return nil end
    copper = math.floor(copper + 0.5)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = T.Code(T.C.gold) .. g .. "g|r" end
    if s > 0 then out[#out + 1] = T.Code(T.C.silver) .. s .. "s|r" end
    if c > 0 or #out == 0 then out[#out + 1] = T.Code(T.C.copper) .. c .. "c|r" end
    -- Big sums drop the copper, it is noise next to gold.
    if g >= 10 and #out == 3 then out[3] = nil end
    return table.concat(out, " ")
end

-- 1234 -> "1.2k"
function T.Short(n)
    if n >= 10000 then return ("%dk"):format(math.floor(n / 1000)) end
    if n >= 1000 then return ("%.1fk"):format(n / 1000) end
    return tostring(n)
end

-- "2m ago", "3h ago", "4d ago"
function T.Ago(t)
    local d = math.max(0, time() - t)
    if d < 60 then return "just now" end
    if d < 3600 then return math.floor(d / 60) .. "m ago" end
    if d < 86400 then return math.floor(d / 3600) .. "h ago" end
    return math.floor(d / 86400) .. "d ago"
end

-- Item quality colours (common white, uncommon green, rare blue...).
function T.Quality(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    if c and c.r then return c.r, c.g, c.b end
    return 0.9, 0.9, 0.9
end
