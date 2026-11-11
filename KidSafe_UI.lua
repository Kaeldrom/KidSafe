--[[
    KidSafe windows:
      * Setup wizard   - first time KidSafe ever runs on the account (grown-up sets the PIN)
      * "Who plays this character?" - first time each character (new or old) loads KidSafe
      * Parent panel   - /kidsafe, the addon compartment button, or Options > AddOns > KidSafe
]]

local KS = KidSafe
local api = KS.api

local BLUE = "|cff66ccff"
local GREEN = "|cff33ff66"
local ORANGE = "|cffff9933"
local GREY = "|cffaaaaaa"
local RED = "|cffff4444"

---------------------------------------------------------------------------
-- Small widget helpers
---------------------------------------------------------------------------
local function Window(name, w, h, title)
    local ok, f = pcall(CreateFrame, "Frame", name, UIParent, "BasicFrameTemplateWithInset")
    if not ok or not f then
        f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        end
    end
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOP", 0, -5)
    t:SetText(BLUE .. "KidSafe|r  " .. (title or ""))
    f.title = t
    f:Hide()
    tinsert(UISpecialFrames, name) -- Escape closes it
    return f
end

local function Text(parent, template, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    if width then fs:SetWidth(width) end
    return fs
end

local function Button(parent, label, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 120, 24)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function Input(parent, w, isPin)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w or 120, 22)
    e:SetAutoFocus(false)
    e:SetMaxLetters(isPin and 8 or 40)
    if isPin then
        if e.SetNumeric then e:SetNumeric(true) end
        if e.SetPassword then pcall(e.SetPassword, e, true) end
    end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    return e
end

-- A pair (or more) of mutually exclusive tick boxes
local function Choice(parent, options, onChange)
    local group = { buttons = {}, value = nil }
    for i, opt in ipairs(options) do
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        local label = Text(parent, "GameFontHighlight", opt.width or 340)
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(opt.text)
        cb.label = label
        cb.value = opt.value
        cb:SetScript("OnClick", function() group:Set(opt.value); if onChange then onChange(opt.value) end end)
        group.buttons[i] = cb
    end
    function group:Set(v)
        self.value = v
        for _, b in ipairs(self.buttons) do b:SetChecked(b.value == v) end
    end
    return group
end

local function RoleText(role, protected)
    if role == "child" then return GREEN .. "a child's character - protected|r" end
    if role == "adult" then
        if protected then return ORANGE .. "a grown-up's character - LOCKED until the PIN is entered|r" end
        return ORANGE .. "a grown-up's character - KidSafe is off|r"
    end
    return (protected and GREEN .. "not set up yet - protected for now|r" or GREY .. "not set up yet - KidSafe is off for now|r")
end

local function ShortName()
    return (UnitName("player"))
end

---------------------------------------------------------------------------
-- 1. Setup wizard (first time on the account)
---------------------------------------------------------------------------
local setup = Window("KidSafeSetupFrame", 500, 470, "first-time setup (grown-ups)")
do
    local y = -34
    local intro = Text(setup, "GameFontHighlight", 456)
    intro:SetPoint("TOPLEFT", 22, y)
    intro:SetText("KidSafe blocks whispers, chat channels, strangers' chat, guild invites, trades and duels, " ..
        "and keeps the language filter on for children's characters. Grown-ups' characters are left alone.")

    local h1 = Text(setup, "GameFontNormal")
    h1:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
    h1:SetText("1.  Choose a parent PIN (4 to 8 digits)")
    setup.pin1 = Input(setup, 90, true)
    setup.pin1:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 6, -6)
    local again = Text(setup, "GameFontHighlightSmall")
    again:SetPoint("LEFT", setup.pin1, "RIGHT", 14, 0)
    again:SetText("type it again:")
    setup.pin2 = Input(setup, 90, true)
    setup.pin2:SetPoint("LEFT", again, "RIGHT", 10, 0)

    local h2 = Text(setup, "GameFontNormal")
    h2:SetPoint("TOPLEFT", setup.pin1, "BOTTOMLEFT", -6, -16)
    setup.h2 = h2
    setup.role = Choice(setup, {
        { value = "child", text = "My child" },
        { value = "adult", text = "Me (a grown-up)" },
    })
    setup.role.buttons[1]:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -4)
    setup.role.buttons[2]:SetPoint("TOPLEFT", setup.role.buttons[1], "BOTTOMLEFT", 0, 0)

    local h3 = Text(setup, "GameFontNormal")
    h3:SetPoint("TOPLEFT", setup.role.buttons[2], "BOTTOMLEFT", 0, -12)
    h3:SetText("3.  Whose account is this?")
    setup.mode = Choice(setup, {
        { value = "shared", text = "Mine - my child plays some characters on it.\n" .. GREY ..
            "Each character asks once who plays it. Brand-new level 1 characters are protected straight away.|r", width = 420 },
        { value = "protect", text = "My child's own account.\n" .. GREY ..
            "Every character is protected unless you unlock it with the PIN.|r", width = 420 },
    })
    setup.mode.buttons[1]:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -4)
    setup.mode.buttons[2]:SetPoint("TOPLEFT", setup.mode.buttons[1], "BOTTOMLEFT", 0, -14)

    setup.err = Text(setup, "GameFontHighlight", 456)
    setup.err:SetPoint("BOTTOMLEFT", 22, 48)

    local save = Button(setup, "Save and start", 150, function()
        local p1, p2 = setup.pin1:GetText(), setup.pin2:GetText()
        if not api.ValidPin(p1) then return setup.err:SetText(RED .. "The PIN needs at least 4 digits.|r") end
        if p1 ~= p2 then return setup.err:SetText(RED .. "The two PINs don't match.|r") end
        if not setup.role.value then return setup.err:SetText(RED .. "Choose who plays this character.|r") end
        if not setup.mode.value then return setup.err:SetText(RED .. "Choose whose account this is.|r") end
        local ok, err = api.CompleteSetup(p1, setup.role.value, setup.mode.value)
        if not ok then return setup.err:SetText(RED .. err .. "|r") end
        setup.pin1:SetText(""); setup.pin2:SetText("")
        setup:Hide()
        api.Print("is set up. " .. ShortName() .. " is " .. RoleText(api.GetRole(), api.Protected()) ..
            ". Type /kidsafe any time for parent controls.")
    end)
    save:SetPoint("BOTTOMRIGHT", -20, 16)
    local later = Button(setup, "Not now", 100, function() setup:Hide() end)
    later:SetPoint("RIGHT", save, "LEFT", -8, 0)
    local note = Text(setup, "GameFontDisableSmall", 230)
    note:SetPoint("BOTTOMLEFT", 22, 20)
    note:SetText("Until this is done, KidSafe protects every character.")

    setup:SetScript("OnShow", function()
        setup.h2:SetText("2.  Who plays this character (" .. (ShortName() or "?") .. ")?")
        setup.err:SetText("")
        setup.role:Set(nil)
        setup.mode:Set("shared")
    end)
end

---------------------------------------------------------------------------
-- 2. "Who plays this character?" (each character that hasn't been set up)
---------------------------------------------------------------------------
local ask = Window("KidSafeWhoPlaysFrame", 420, 230, "")
do
    ask.q = Text(ask, "GameFontNormalLarge", 380)
    ask.q:SetPoint("TOPLEFT", 20, -36)
    ask.sub = Text(ask, "GameFontHighlight", 380)
    ask.sub:SetPoint("TOPLEFT", ask.q, "BOTTOMLEFT", 0, -8)

    local child = Button(ask, "My child - protect it", 170, function()
        api.SetRole("child")
        ask:Hide()
        api.Print(GREEN .. ShortName() .. " is protected.|r Have fun and stay safe!")
    end)
    child:SetPoint("TOPLEFT", ask.sub, "BOTTOMLEFT", 0, -16)

    local adultLabel = Text(ask, "GameFontHighlightSmall")
    adultLabel:SetPoint("TOPLEFT", child, "BOTTOMLEFT", 0, -14)
    adultLabel:SetText("A grown-up's character? Enter the PIN:")
    ask.pin = Input(ask, 80, true)
    ask.pin:SetPoint("LEFT", adultLabel, "RIGHT", 10, 0)
    local adult = Button(ask, "It's mine", 90, nil)
    adult:SetPoint("LEFT", ask.pin, "RIGHT", 8, 0)
    ask.err = Text(ask, "GameFontHighlightSmall", 380)
    ask.err:SetPoint("TOPLEFT", adultLabel, "BOTTOMLEFT", 0, -10)
    local function claim()
        local ok, err = api.ClaimAdult(ask.pin:GetText())
        ask.pin:SetText("")
        if not ok then return ask.err:SetText(RED .. err .. "|r") end
        ask:Hide()
        api.Print(ORANGE .. ShortName() .. " is a grown-up's character|r - KidSafe is off here.")
    end
    adult:SetScript("OnClick", claim)
    ask.pin:SetScript("OnEnterPressed", claim)

    ask:SetScript("OnShow", function()
        ask.q:SetText("Who plays " .. (ShortName() or "this character") .. "?")
        ask.sub:SetText(api.Protected()
            and "KidSafe is protecting this character until a grown-up says otherwise."
            or "KidSafe is off on this character for now.")
        ask.err:SetText("")
    end)
end

---------------------------------------------------------------------------
-- 2b. Grown-up's character: PIN box at every login
---------------------------------------------------------------------------
local gate = Window("KidSafeUnlockFrame", 400, 190, "")
do
    gate.q = Text(gate, "GameFontNormalLarge", 360)
    gate.q:SetPoint("TOPLEFT", 20, -36)
    local sub = Text(gate, "GameFontHighlight", 360)
    sub:SetPoint("TOPLEFT", gate.q, "BOTTOMLEFT", 0, -8)
    sub:SetText("KidSafe is on until the parent PIN is entered.")
    local lbl = Text(gate, "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -18)
    lbl:SetText("PIN:")
    gate.pin = Input(gate, 90, true)
    gate.pin:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
    gate.err = Text(gate, "GameFontHighlightSmall", 360)
    gate.err:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -14)
    local function go()
        local ok, err = api.UnlockAdult(gate.pin:GetText())
        gate.pin:SetText("")
        if not ok then return gate.err:SetText(RED .. err .. "|r") end
        gate:Hide()
        api.Print(ORANGE .. "unlocked.|r Welcome back! (It locks again when you log out or go AFK.)")
    end
    local b = Button(gate, "Unlock", 90, go)
    b:SetPoint("LEFT", gate.pin, "RIGHT", 8, 0)
    gate.pin:SetScript("OnEnterPressed", go)
    local no = Button(gate, "Keep it locked", 120, function() gate:Hide() end)
    no:SetPoint("BOTTOMRIGHT", -16, 14)
    gate:SetScript("OnShow", function()
        gate.q:SetText((ShortName() or "This") .. " is a grown-up's character")
        gate.err:SetText("")
        gate.pin:SetFocus()
    end)
end

---------------------------------------------------------------------------
-- 3. Parent panel
---------------------------------------------------------------------------
local panel = Window("KidSafeParentFrame", 520, 600, "parent controls")
local locked, unlocked
do
    -- locked view
    locked = CreateFrame("Frame", nil, panel)
    locked:SetAllPoints()
    local lt = Text(locked, "GameFontNormalLarge", 460)
    lt:SetPoint("TOP", 0, -50)
    lt:SetJustifyH("CENTER")
    locked.status = lt
    local lp = Text(locked, "GameFontHighlight")
    lp:SetPoint("TOP", lt, "BOTTOM", -60, -30)
    lp:SetText("Parent PIN:")
    locked.pin = Input(locked, 90, true)
    locked.pin:SetPoint("LEFT", lp, "RIGHT", 10, 0)
    locked.err = Text(locked, "GameFontHighlight", 460)
    locked.err:SetJustifyH("CENTER")
    locked.err:SetPoint("TOP", lt, "BOTTOM", 0, -70)
    local function doUnlock()
        local ok, err = api.Unlock(locked.pin:GetText())
        locked.pin:SetText("")
        if not ok then return locked.err:SetText(RED .. err .. "|r") end
        KS.OnStateChanged()
    end
    local ub = Button(locked, "Unlock", 90, doUnlock)
    ub:SetPoint("LEFT", locked.pin, "RIGHT", 8, 0)
    locked.pin:SetScript("OnEnterPressed", doUnlock)
    local tip = Text(locked, "GameFontHighlight", 440)
    tip:SetPoint("TOP", locked.err, "BOTTOM", 0, -30)
    tip:SetJustifyH("CENTER")
    tip:SetText("Never share your PIN with your child.\n\n" .. GREY ..
        "Forgot it? Close the game and delete WTF\\Account\\<account>\\SavedVariables\\KidSafe.lua|r")

    -- unlocked view
    unlocked = CreateFrame("Frame", nil, panel)
    unlocked:SetAllPoints()
    local x = 20

    local h = Text(unlocked, "GameFontNormal")
    h:SetPoint("TOPLEFT", x, -34)
    h:SetText("This character")
    unlocked.charStatus = Text(unlocked, "GameFontHighlight", 470)
    unlocked.charStatus:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
    local bChild = Button(unlocked, "Child - protect", 140, function() api.SetRole("child"); panel:Hide() end)
    bChild:SetPoint("TOPLEFT", unlocked.charStatus, "BOTTOMLEFT", 0, -6)
    local bAdult = Button(unlocked, "Grown-up - KidSafe off", 170, function() api.SetRole("adult"); KS.OnStateChanged() end)
    bAdult:SetPoint("LEFT", bChild, "RIGHT", 8, 0)

    local h2 = Text(unlocked, "GameFontNormal")
    h2:SetPoint("TOPLEFT", bChild, "BOTTOMLEFT", 0, -14)
    h2:SetText("Other characters")
    unlocked.chars = Text(unlocked, "GameFontHighlightSmall", 470)
    unlocked.chars:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -4)
    unlocked.chars:SetSpacing(2)
    local pl = Text(unlocked, "GameFontHighlightSmall")
    pl:SetPoint("TOPLEFT", unlocked.chars, "BOTTOMLEFT", 0, -8)
    pl:SetText("Protect a character you're not logged in to:")
    unlocked.protName = Input(unlocked, 130)
    unlocked.protName:SetPoint("LEFT", pl, "RIGHT", 10, 0)
    local pb = Button(unlocked, "Protect", 80, function()
        local ok, err = api.ProtectByName(unlocked.protName:GetText())
        unlocked.protName:SetText("")
        if not ok then api.Print(err) end
        KS.OnStateChanged()
    end)
    pb:SetPoint("LEFT", unlocked.protName, "RIGHT", 6, 0)
    unlocked.mode = Choice(unlocked, {
        { value = "shared", text = "Characters not set up yet: left alone (new level 1 characters protected)", width = 440 },
        { value = "protect", text = "Characters not set up yet: protected", width = 440 },
    }, function(v) api.SetNewChars(v); KS.OnStateChanged() end)
    unlocked.mode.buttons[1]:SetPoint("TOPLEFT", pl, "BOTTOMLEFT", -4, -8)
    unlocked.mode.buttons[2]:SetPoint("TOPLEFT", unlocked.mode.buttons[1], "BOTTOMLEFT", 0, 2)

    local h3 = Text(unlocked, "GameFontNormal")
    h3:SetPoint("TOPLEFT", unlocked.mode.buttons[2], "BOTTOMLEFT", 4, -10)
    h3:SetText("Trusted people " .. GREY .. "(can whisper, invite, trade and duel your child)|r")
    unlocked.trusted = Text(unlocked, "GameFontHighlightSmall", 470)
    unlocked.trusted:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -4)
    unlocked.trustName = Input(unlocked, 130)
    unlocked.trustName:SetPoint("TOPLEFT", unlocked.trusted, "BOTTOMLEFT", 6, -6)
    local tAdd = Button(unlocked, "Add", 60, function()
        api.Trust(unlocked.trustName:GetText(), true); unlocked.trustName:SetText(""); KS.OnStateChanged()
    end)
    tAdd:SetPoint("LEFT", unlocked.trustName, "RIGHT", 6, 0)
    local tDel = Button(unlocked, "Remove", 70, function()
        api.Trust(unlocked.trustName:GetText(), false); unlocked.trustName:SetText(""); KS.OnStateChanged()
    end)
    tDel:SetPoint("LEFT", tAdd, "RIGHT", 4, 0)

    local h4 = Text(unlocked, "GameFontNormal")
    h4:SetPoint("TOPLEFT", unlocked.trustName, "BOTTOMLEFT", -6, -14)
    h4:SetText("Break reminder every")
    unlocked.brk = Input(unlocked, 40)
    unlocked.brk:SetNumeric(true)
    unlocked.brk:SetPoint("LEFT", h4, "RIGHT", 10, 0)
    local bl = Text(unlocked, "GameFontHighlight")
    bl:SetPoint("LEFT", unlocked.brk, "RIGHT", 6, 0)
    bl:SetText("minutes (0 = off)")
    local bs = Button(unlocked, "Set", 50, function() api.SetBreak(unlocked.brk:GetText()); KS.OnStateChanged() end)
    bs:SetPoint("LEFT", bl, "RIGHT", 8, 0)

    local h5 = Text(unlocked, "GameFontNormal")
    h5:SetPoint("TOPLEFT", h4, "BOTTOMLEFT", 0, -16)
    h5:SetText("Change PIN")
    unlocked.newPin = Input(unlocked, 90, true)
    unlocked.newPin:SetPoint("LEFT", h5, "RIGHT", 12, 0)
    local np = Button(unlocked, "Save", 60, function()
        local ok, err = api.SetPin(unlocked.newPin:GetText())
        unlocked.newPin:SetText("")
        api.Print(ok and "PIN changed." or err)
    end)
    np:SetPoint("LEFT", unlocked.newPin, "RIGHT", 6, 0)

    local h6 = Text(unlocked, "GameFontNormal")
    h6:SetPoint("TOPLEFT", h5, "BOTTOMLEFT", 0, -18)
    h6:SetText("Grown-ups' characters")
    local function Tick(label, getter, setter, anchor)
        local cb = CreateFrame("CheckButton", nil, unlocked, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        local t = Text(unlocked, "GameFontHighlight", 440)
        t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        t:SetText(label)
        cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false); KS.OnStateChanged() end)
        cb.get = getter
        return cb
    end
    unlocked.adultPin = Tick("Ask for the PIN every time one logs in " .. GREY .. "(recommended)|r",
        api.GetAdultPin, api.SetAdultPin, h6)
    unlocked.afk = Tick("Lock it again when I go AFK", api.GetLockOnAFK, api.SetLockOnAFK, unlocked.adultPin)
    unlocked.lockNow = Button(unlocked, "Lock this character now", 190, function()
        api.LockCharacter(); panel:Hide()
        api.Print("this character is locked. Enter the PIN to unlock it again.")
    end)
    unlocked.lockNow:SetPoint("TOPLEFT", unlocked.afk, "BOTTOMLEFT", 2, -6)

    local logB = Button(unlocked, "What was blocked", 150, function() KS.ShowLog() end)
    logB:SetPoint("BOTTOMLEFT", 18, 16)
    local lockB = Button(unlocked, "Lock and close", 140, function() panel:Hide() end)
    lockB:SetPoint("BOTTOMRIGHT", -18, 16)
    local hint = Text(unlocked, "GameFontDisableSmall", 160)
    hint:SetPoint("BOTTOM", 0, 20)
    hint:SetJustifyH("CENTER")
    hint:SetText("Closing this window locks KidSafe again.")

    panel:SetScript("OnHide", function()
        -- never leave a child's character unlocked by accident
        if api.IsUnlocked() then api.Lock() end
        if KS.logFrame then KS.logFrame:Hide() end
    end)
    panel:SetScript("OnShow", function() KS.OnStateChanged() end)
end

function KS.OnStateChanged()
    if not panel:IsShown() then return end
    local role, prot = api.GetRole(), api.Protected()
    if not api.IsUnlocked() then
        locked:Show(); unlocked:Hide()
        locked.err:SetText("")
        locked.status:SetText((ShortName() or "") .. " is " .. RoleText(role, prot))
        return
    end
    locked:Hide(); unlocked:Show()
    unlocked.charStatus:SetText((ShortName() or "") .. " is " .. RoleText(role, role ~= "adult" or prot) ..
        (role ~= "adult" and ("\n" .. ORANGE .. "Unlocked: protection is paused until you close this window.|r") or ""))
    local lines = {}
    for _, c in ipairs(api.CharList()) do
        if c.key ~= api.CharKey() then
            lines[#lines + 1] = (c.role == "child" and GREEN .. "child|r  " or ORANGE .. "grown-up|r  ") .. c.name
        end
    end
    unlocked.chars:SetText(#lines > 0 and table.concat(lines, "\n") or GREY .. "No other characters set up yet. Each one asks the first time it logs in.|r")
    local t = api.TrustedList()
    unlocked.trusted:SetText(#t > 0 and table.concat(t, ", ") or GREY .. "Nobody yet - add your own characters here.|r")
    unlocked.mode:Set(api.GetNewChars())
    unlocked.adultPin:SetChecked(api.GetAdultPin())
    unlocked.afk:SetChecked(api.GetLockOnAFK())
    if role == "adult" then unlocked.lockNow:Show() else unlocked.lockNow:Hide() end
    unlocked.brk:SetText(tostring(api.GetBreak()))
end

---------------------------------------------------------------------------
-- Blocked-items log window
---------------------------------------------------------------------------
function KS.ShowLog()
    if not KS.logFrame then
        local f = Window("KidSafeLogFrame", 560, 360, "what was blocked")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        local m = CreateFrame("ScrollingMessageFrame", nil, f)
        m:SetPoint("TOPLEFT", 14, -32)
        m:SetPoint("BOTTOMRIGHT", -14, 46)
        m:SetFontObject(GameFontHighlightSmall)
        m:SetJustifyH("LEFT")
        m:SetFading(false)
        m:SetMaxLines(400)
        m:EnableMouseWheel(true)
        m:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
        f.msgs = m
        local clear = Button(f, "Clear log", 100, function()
            if api.ClearLog() then m:Clear() end
        end)
        clear:SetPoint("BOTTOMLEFT", 14, 14)
        local note = Text(f, "GameFontDisableSmall", 380)
        note:SetPoint("LEFT", clear, "RIGHT", 12, 0)
        note:SetText("Scroll with the mouse wheel. Newest at the bottom.")
        KS.logFrame = f
    end
    local f = KS.logFrame
    f.msgs:Clear()
    local log = api.GetLog()
    if #log == 0 then f.msgs:AddMessage(GREY .. "Nothing has been blocked yet.|r") end
    for _, e in ipairs(log) do
        f.msgs:AddMessage(string.format("%s%s|r  [%s]  |cffffd100%s|r: %s", GREY, date("%d/%m %H:%M", e.t), e.k, e.w, e.m))
    end
    f.msgs:ScrollToBottom()
    f:Show()
end

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------
function KS.OpenPanel()
    if not api.HasPin() then return setup:Show() end
    if InCombatLockdown and InCombatLockdown() then
        return api.Print("you can open parent controls after combat.")
    end
    panel:Show()
end

function KS.ShowFirstRun(which)
    if InCombatLockdown and InCombatLockdown() then
        -- try again when combat ends
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); KS.ShowFirstRun(which) end)
        return
    end
    if which == "setup" then setup:Show()
    elseif which == "adultlock" then gate:Show()
    else ask:Show() end
end

-- Addon compartment (the little button by the minimap) and Options page button
function KidSafe_OpenPanel() KS.OpenPanel() end
