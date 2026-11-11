--[[
    KidSafe - a kid-friendly lock-down for WoW Forever (interface 16001, modern 12.x client)

    Always on (no in-game setting can turn these off):
      * Whispers and Battle.net whispers blocked (in and out) - except from Game Masters and trusted names
      * All public chat channels left and hidden (General, Trade, LFG, custom), channel invites declined
      * /say, /yell and /emote from strangers hidden; the kid can't /say, /yell, /whisper or use channels
      * Guild invites, guild charters, community invites, friend requests, duels and pet duels declined
      * Group invites from strangers declined (Dungeon Finder still works)
      * Trades with strangers cancelled, "Block Trades" forced on
      * Language filter (profanityFilter) forced on, plus extra word and "contact me" filtering of group chat
      * The kid is warned and stopped from typing personal info (phone numbers, e-mail, address, passwords...)
      * Speech bubbles from strangers off, guild names over heads hidden, blood/violence reduced
      * In-game AddOns list, /run, /script and /console are locked so it can't be switched off from inside the game
      * Break reminder every hour (adjustable)
      * Everything that gets blocked is logged so a parent can review it

    Parent controls (need the PIN):  type  /kidsafe  for help.
]]

local ADDON = ...
local KS = CreateFrame("Frame", "KidSafeFrame")
KidSafe = KS

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local PREFIX = "|cff66ccffKidSafe|r: "
local parentMode = false        -- session only, never saved: a /reload or relog locks again
local LOG_MAX = 300

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local function Readable(v)
    -- Midnight-era clients can hand addons "secret" values during combat/encounters.
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    if canaccessvalue and not canaccessvalue(v) then return false end
    return true
end

local function SafeCall(fn, ...)
    if type(fn) == "function" then
        return pcall(fn, ...)
    end
    return false
end

local function HidePopup(which)
    if StaticPopup_Hide then pcall(StaticPopup_Hide, which) end
end

-- Who plays this character: "child", "adult", or nil (nobody has said yet).
-- Until PLAYER_LOGIN has worked it out we always protect.
local charRole = nil
local loggedIn = false
-- Grown-up characters start LOCKED every login and need the PIN (unless the parent turned that off),
-- so a child who logs in to a parent's character is still protected.
local adultUnlocked = false
local RELOAD_GRACE = 600   -- a /reload within 10 minutes of being unlocked keeps it unlocked

local function CharKey()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    if not name then name = UnitName("player") end
    if realm == "" then realm = nil end
    realm = realm or (GetRealmName and GetRealmName()) or ""
    return (name or "?") .. "-" .. realm:gsub("%s", "")
end

local function Protected()
    if parentMode then return false end
    if not loggedIn then return true end
    if charRole == "child" then return true end
    if charRole == "adult" then
        if KidSafeDB and KidSafeDB.adultPin == false then return false end
        return not adultUnlocked
    end
    -- A character nobody has set up yet. On a shared (grown-up's) account it's left alone;
    -- on a child's own account, or before setup is finished, it's protected.
    return not (KidSafeDB and KidSafeDB.pinHash and KidSafeDB.newChars == "shared")
end

-- Friendly message to the kid, throttled per key so it never spams
local lastNotice = {}
local function Notice(key, msg, seconds)
    local now = GetTime()
    if lastNotice[key] and now - lastNotice[key] < (seconds or 30) then return end
    lastNotice[key] = now
    Print(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 0.4, 0.8, 1.0, 1.0)
    end
end

local function Log(kind, who, text)
    if not KidSafeDB then return end
    local entry = {
        t = time(),
        k = kind,
        w = Readable(who) and tostring(who) or "?",
        m = Readable(text) and tostring(text) or "[hidden by the game]",
    }
    local log = KidSafeDB.log
    log[#log + 1] = entry
    while #log > LOG_MAX do table.remove(log, 1) end
end

local function HashPin(pin)
    -- Not cryptography; it just stops the PIN being readable in plain text.
    local h = 5381
    local s = "KidSafe#" .. tostring(pin) .. "#salt"
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
end

---------------------------------------------------------------------------
-- Trusted people (parent, siblings, real-life friends) - managed with the PIN
---------------------------------------------------------------------------
local function NormName(name)
    if not Readable(name) or name == "" then return nil end
    name = tostring(name)
    local short = Ambiguate and Ambiguate(name, "none") or name
    short = short:gsub("%-.*$", "")
    return short:lower()
end

local function IsTrusted(name)
    local n = NormName(name)
    return n ~= nil and KidSafeDB and KidSafeDB.trusted[n] == true
end

local function IsSelf(name, guid)
    if Readable(guid) and guid == UnitGUID("player") then return true end
    local n = NormName(name)
    return n ~= nil and n == NormName(UnitName("player"))
end

local function InMyGroup(name, guid)
    if Readable(guid) and IsGUIDInGroup then
        local ok, res = pcall(IsGUIDInGroup, guid)
        if ok and res then return true end
    end
    if Readable(name) then
        local short = Ambiguate and Ambiguate(name, "none") or name
        if UnitInParty(short) or UnitInRaid(short) then return true end
    end
    return false
end

local function IsKnown(name, guid)
    return IsSelf(name, guid) or IsTrusted(name) or InMyGroup(name, guid)
end

---------------------------------------------------------------------------
-- Word / contact filters (on top of the game's own language filter)
---------------------------------------------------------------------------
local BAD_WORDS = {
    "fuck", "fucking", "fucker", "fck", "fuk", "shit", "shitty", "bitch", "bastard", "cunt", "dick",
    "dickhead", "cock", "pussy", "slut", "whore", "wanker", "twat", "prick", "bollocks", "arse",
    "arsehole", "asshole", "ass", "piss", "pissed", "damn", "crap", "retard", "retarded", "fag",
    "faggot", "nigger", "nigga", "kys", "stfu", "wtf", "porn", "sex", "sexy", "nude", "nudes",
    "boobs", "tits", "penis", "vagina", "rape", "milf", "horny", "dildo",
}

-- Messages trying to move the kid off the game, or asking personal questions, are hidden completely
local GROOMING = {
    "discord", "snapchat", "snap me", "my snap", "instagram", "tiktok", "whatsapp", "telegram",
    "kik", "facebook", "skype", "steam friend", "my insta", "ur insta", "your insta", "add me", "dm me", "message me", "msg me", "pm me",
    "whisper me", "/w me", "how old", "your age", "ur age", "are you a girl", "are you a boy",
    "where do you live", "where u live", "what school", "which school", "your address", "your number",
    "your phone", "send a pic", "send pic", "send me a pic", "photo of you", "webcam", "cam",
    "your password", "free gold", "free mount", "gift card", "giftcard", "account code", "verify your account",
    "keep it secret", "our secret", "don't tell", "dont tell", "http", "www.", ".com", ".gg", ".net",
    ".org", ".co.uk", ".ly", ".io",
}

-- Things the kid shouldn't type to anyone
local PERSONAL = {
    "my address", "i live", "i live at", "my house", "my school", "my phone", "my number", "phone number",
    "my password", "password is", "my email", "my e-mail", "my real name", "my mum's", "my mom's",
    "my dad's", "postcode", "zip code", "discord", "snapchat", "instagram", "tiktok", "whatsapp",
}

-- Turns a phrase into a pattern that only matches whole words ("add me" won't hit "add melee")
local patternCache = {}
local function PhrasePattern(phrase)
    local p = patternCache[phrase]
    if p then return p end
    p = phrase:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    if phrase:find("^%w") then p = "%f[%w]" .. p end
    if phrase:find("%w$") then p = p .. "%f[%W]" end
    patternCache[phrase] = p
    return p
end

local function ContainsAny(text, list)
    local lower = text:lower()
    for _, w in ipairs(list) do
        if lower:find(PhrasePattern(w)) then return w end
    end
    return nil
end

local function Censor(msg)
    local lower = msg:lower()
    local changed = false
    for _, w in ipairs(BAD_WORDS) do
        local pattern = "%f[%a]" .. w .. "%f[%A]"
        local s, e = lower:find(pattern)
        while s do
            local stars = string.rep("*", e - s + 1)
            msg = msg:sub(1, s - 1) .. stars .. msg:sub(e + 1)
            lower = lower:sub(1, s - 1) .. stars .. lower:sub(e + 1)
            changed = true
            s, e = lower:find(pattern, e + 1)
        end
    end
    return msg, changed
end

local function LooksPersonal(text)
    if not Readable(text) then return nil end
    local lower = text:lower()
    if lower:gsub("[%s%-%.%(%)]", ""):find("%d%d%d%d%d%d%d") then return "a phone number" end
    if lower:find("[%w%._%-]+@[%w%-]+%.%a") then return "an e-mail address" end
    local w = ContainsAny(lower, PERSONAL)
    if w then return "\"" .. w .. "\"" end
    return nil
end

---------------------------------------------------------------------------
-- Forced settings (CVars). Re-applied whenever anything changes them.
---------------------------------------------------------------------------
local FORCED_CVARS = {
    profanityFilter          = "1", -- mature language filter
    spamFilter               = "1",
    blockTrades              = "1",
    blockChannelInvites      = "1",
    chatBubbles              = "0", -- no speech bubbles from strangers saying things
    chatBubblesParty         = "1", -- ...but keep group bubbles
    UnitNamePlayerGuild      = "0", -- guild names over heads can be rude
    UnitNameGuildTitle       = "0",
    violenceLevel            = "0", -- least blood
    showToastBroadcast       = "0", -- Battle.net broadcast pop-ups
    showToastFriendRequest   = "0",
    autoAcceptQuickJoinRequests = "0",
}

local applying = false
local function GetCV(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name)
end
local function SetCV(name, value)
    if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, value) end
    return pcall(SetCVar, name, value)
end

local function ApplyCVars(announce)
    if not Protected() or applying then return end
    applying = true
    KidSafeDB.origCVars = KidSafeDB.origCVars or {}
    for name, want in pairs(CopyTable and CopyTable(FORCED_CVARS) or FORCED_CVARS) do
        local cur = GetCV(name)
        if cur ~= nil and cur ~= want then
            if KidSafeDB.origCVars[name] == nil then KidSafeDB.origCVars[name] = cur end
            SetCV(name, want)
            if GetCV(name) ~= want then
                FORCED_CVARS[name] = nil -- this client won't take that value; stop fighting it
                KidSafeDB.origCVars[name] = nil
            elseif announce then
                Notice("cvar" .. name, "that setting is locked by a grown-up, so it's been put back.", 10)
            end
        end
    end
    if SetAutoDeclineGuildInvites then SafeCall(SetAutoDeclineGuildInvites, true) end
    applying = false
end

local function RestoreCVars()
    for name, val in pairs(KidSafeDB.origCVars or {}) do
        SetCV(name, val)
    end
    if SetAutoDeclineGuildInvites then SafeCall(SetAutoDeclineGuildInvites, false) end
    KidSafeDB.origCVars = {}
end

---------------------------------------------------------------------------
-- Chat filters
---------------------------------------------------------------------------
local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter

-- Always hidden (unless the sender is trusted / a GM)
local BLOCK_ALWAYS = {
    CHAT_MSG_WHISPER = "whisper", CHAT_MSG_WHISPER_INFORM = "whisper-out",
    CHAT_MSG_BN_WHISPER = "bnet-whisper", CHAT_MSG_BN_WHISPER_INFORM = "bnet-whisper-out",
    CHAT_MSG_CHANNEL = "channel", CHAT_MSG_COMMUNITIES_CHANNEL = "community",
    CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild",
    CHAT_MSG_BN_INLINE_TOAST_BROADCAST = "bnet-broadcast", CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM = "bnet-broadcast",
    CHAT_MSG_AFK = "afk-reply", CHAT_MSG_DND = "dnd-reply",
    CHAT_MSG_CHANNEL_JOIN = "channel-notice", CHAT_MSG_CHANNEL_LEAVE = "channel-notice",
    CHAT_MSG_CHANNEL_NOTICE = "channel-notice", CHAT_MSG_CHANNEL_NOTICE_USER = "channel-notice",
}
local QUIET = { ["channel-notice"] = true, ["channel"] = true, ["community"] = true, ["bnet-broadcast"] = true }

-- Hidden only when they come from strangers
local BLOCK_STRANGERS = {
    CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell", CHAT_MSG_EMOTE = "emote", CHAT_MSG_TEXT_EMOTE = "emote",
}

-- Allowed (group chat) but cleaned
local CLEAN = {
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
}

local function IsStaff(flags)
    return Readable(flags) and (flags == "GM" or flags == "DEV")
end

local seenLine = {}
local function FirstTime(lineID)
    -- chat filters run once per chat window; only log/notify once per message
    if not Readable(lineID) then return true end
    if seenLine[lineID] then return false end
    seenLine[lineID] = true
    return true
end

local function FilterAlways(self, event, msg, author, a3, a4, a5, flags, a7, a8, a9, a10, lineID, guid, ...)
    if not Protected() then return false end
    if IsStaff(flags) then return false end
    local kind = BLOCK_ALWAYS[event]
    -- Whispers to/from trusted people are fine
    if (kind == "whisper" or kind == "whisper-out") and IsTrusted(author) then return false end
    if not FirstTime(lineID) then return true end
    if kind == "whisper" or kind == "bnet-whisper" then
        Log(kind, author, msg)
        Notice("whisper", "a private message from someone was hidden to keep you safe.", 60)
    elseif kind == "guild" or kind == "afk-reply" or kind == "dnd-reply" then
        Log(kind, author, msg)
    elseif not QUIET[kind] then
        Log(kind, author, msg)
    end
    return true
end

local function FilterStrangers(self, event, msg, author, a3, a4, a5, flags, a7, a8, a9, a10, lineID, guid, ...)
    if not Protected() then return false end
    if IsStaff(flags) or IsKnown(author, guid) then return false end
    return true
end

local function FilterClean(self, event, msg, author, ...)
    if not Protected() or not Readable(msg) then return false end
    local flags = select(4, ...)
    if IsStaff(flags) or IsSelf(author, select(10, ...)) then return false end
    local hit = ContainsAny(msg, GROOMING)
    if hit then
        if FirstTime(select(9, ...)) then
            Log("hidden-group-msg", author, msg)
            Notice("groom", "a message was hidden because it asked for private stuff or tried to get you off the game. Never share private info!", 30)
        end
        return true
    end
    local cleaned, changed = Censor(msg)
    if changed then return false, cleaned, author, ... end
    return false
end

local function SetupChatFilters()
    if not AddFilter then return end
    for ev in pairs(BLOCK_ALWAYS) do AddFilter(ev, FilterAlways) end
    for ev in pairs(BLOCK_STRANGERS) do AddFilter(ev, FilterStrangers) end
    for _, ev in ipairs(CLEAN) do AddFilter(ev, FilterClean) end
end

---------------------------------------------------------------------------
-- Leave every public chat channel (General, Trade, LocalDefense, LFG, custom...)
---------------------------------------------------------------------------
local leavePending = false
local function LeaveAllChannels()
    if not Protected() then return end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local name = list[i + 1]
        if type(name) == "string" and name ~= "" then
            SafeCall(LeaveChannelByName, name)
        end
    end
end
local function QueueLeave()
    if leavePending then return end
    leavePending = true
    C_Timer.After(1, function() leavePending = false; LeaveAllChannels() end)
end

---------------------------------------------------------------------------
-- Social requests (invites, trades, duels, ...)
---------------------------------------------------------------------------
local handlers = {}

handlers.GUILD_INVITE_REQUEST = function(inviter, guildName)
    SafeCall(DeclineGuild)
    if GuildInviteFrame then GuildInviteFrame:Hide() end
    HidePopup("GUILD_INVITE")
    Log("guild-invite", inviter, guildName)
    Notice("guild", "a guild invite was turned down for you.", 20)
end

handlers.PETITION_SHOW = function()
    SafeCall(ClosePetition)
    Log("guild-charter", "?", "guild charter signature request")
    Notice("petition", "guild charter signing is turned off.", 20)
end

handlers.CLUB_INVITATION_ADDED_FOR_SELF = function(invitation)
    if C_Club and C_Club.DeclineInvitation and type(invitation) == "table" and invitation.club then
        SafeCall(C_Club.DeclineInvitation, invitation.club.clubId)
    end
    Log("community-invite", "?", invitation and invitation.club and invitation.club.name)
end

handlers.CHANNEL_INVITE_REQUEST = function(channel, inviter)
    SafeCall(DeclineChannelInvite, channel)
    HidePopup("CHAT_CHANNEL_INVITE")
    Log("channel-invite", inviter, channel)
end

handlers.BN_FRIEND_INVITE_ADDED = function()
    if not (BNGetNumFriendInvites and C_BattleNet and C_BattleNet.GetFriendInviteInfo) then return end
    for i = BNGetNumFriendInvites(), 1, -1 do
        local ok, info = pcall(C_BattleNet.GetFriendInviteInfo, i)
        if ok and info and info.inviteID then
            SafeCall(BNDeclineFriendInvite, info.inviteID)
            Log("friend-request", info.accountName, "Battle.net friend request")
        end
    end
    Notice("bnfriend", "a friend request from someone was turned down.", 20)
end

handlers.DUEL_REQUESTED = function(challenger)
    if IsTrusted(challenger) then return end
    SafeCall(CancelDuel)
    HidePopup("DUEL_REQUESTED")
    Log("duel", challenger, "duel request")
end

handlers.PET_BATTLE_PVP_DUEL_REQUESTED = function(challenger)
    if IsTrusted(challenger) then return end
    if C_PetBattles and C_PetBattles.CancelPVPDuel then SafeCall(C_PetBattles.CancelPVPDuel) end
    HidePopup("PET_BATTLE_PVP_DUEL_REQUESTED")
    Log("pet-duel", challenger, "pet battle duel request")
end

handlers.PARTY_INVITE_REQUEST = function(inviter)
    if IsTrusted(inviter) then return end
    SafeCall(DeclineGroup)
    HidePopup("PARTY_INVITE")
    if LFGInvitePopup and LFGInvitePopup:IsShown() then LFGInvitePopup:Hide() end
    Log("group-invite", inviter, "group invite")
    Notice("party", "a group invite from someone you don't know was turned down. Use the Dungeon Finder to group up!", 20)
end

handlers.GROUP_INVITE_CONFIRMATION = function()
    -- someone asking to join the kid's group through a friend (quick join)
    if not (GetNextPendingInviteConfirmation and RespondToInviteConfirmation) then return end
    local guid = GetNextPendingInviteConfirmation()
    if guid then
        local _, name = GetInviteConfirmationInfo and GetInviteConfirmationInfo(guid)
        if not IsTrusted(name) then
            SafeCall(RespondToInviteConfirmation, guid, false)
            HidePopup("GROUP_INVITE_CONFIRMATION")
            Log("join-request", name, "asked to join the group")
        end
    end
end

handlers.TRADE_REQUEST = function(name)
    if IsTrusted(name) then return end
    HidePopup("TRADE")
    SafeCall(CancelTrade)
    Log("trade", name, "trade request")
end

handlers.TRADE_SHOW = function()
    local partner = UnitName("NPC")
    if IsTrusted(partner) then return end
    if not SafeCall(CancelTrade) then SafeCall(CloseTrade) end
    if TradeFrame then TradeFrame:Hide() end
    Log("trade", partner, "trade window")
    Notice("trade", "trading with other players is turned off.", 20)
end

-- Always-on bookkeeping events
handlers.CHANNEL_UI_UPDATE = function() QueueLeave() end
handlers.CVAR_UPDATE = function() C_Timer.After(0.1, function() ApplyCVars(true) end) end

---------------------------------------------------------------------------
-- Outgoing chat guard: stops the kid whispering, using /say, /yell, channels,
-- and typing personal info. Works on the chat edit boxes without replacing
-- any Blizzard code (so secure slash commands like /cast keep working).
---------------------------------------------------------------------------
local BLOCKED_TYPES = {
    SAY = "Talking to strangers", YELL = "Yelling to strangers", EMOTE = "Custom emotes to strangers",
    WHISPER = "Private messages", BN_WHISPER = "Private messages", CHANNEL = "Chat channels",
    GUILD = "Guild chat", OFFICER = "Guild chat",
}
local GROUP_TYPES = { PARTY = true, RAID = true, RAID_WARNING = true, INSTANCE_CHAT = true }

local blockedCmds, groupCmds = {}, {}
local function AddCmds(set, keys, extra)
    for _, key in ipairs(keys) do
        for i = 1, 12 do
            local s = _G["SLASH_" .. key .. i]
            if type(s) == "string" then set[s:lower()] = true end
        end
    end
    for _, s in ipairs(extra) do set[s] = true end
end

local function BuildCmdLists()
    AddCmds(blockedCmds,
        { "SAY", "YELL", "WHISPER", "REPLY", "GUILD", "OFFICER", "EMOTE", "CHANNEL", "JOIN", "CHAT_INVITE", "CHATINVITE",
          "GUILD_INVITE", "GUILDINVITE", "TRADE" },
        { "/s", "/say", "/y", "/yell", "/sh", "/shout", "/w", "/whisper", "/t", "/tell", "/send", "/r", "/reply",
          "/g", "/guild", "/o", "/officer", "/e", "/em", "/me", "/emote", "/c", "/csay", "/join", "/channel",
          "/chan", "/ginvite", "/gquit", "/cinvite", "/chatinvite", "/bn", "/trade",
          "/1", "/2", "/3", "/4", "/5", "/6", "/7", "/8", "/9", "/10" })
    AddCmds(groupCmds, { "PARTY", "RAID", "RAID_WARNING", "INSTANCE_CHAT" },
        { "/p", "/party", "/ra", "/raid", "/rw", "/i", "/instance", "/bg" })
end

local function Wipe(editBox, key, msg)
    editBox:SetText("")
    Notice(key, msg, 8)
end

local function GuardEditBox(editBox)
    if not Protected() then return end
    local text = editBox:GetText()
    if not Readable(text) then return end

    if text:sub(1, 1) == "/" then
        local cmd, rest = text:match("^(/%S+)%s(.*)$")
        if cmd then
            cmd = cmd:lower()
            if blockedCmds[cmd] then
                return Wipe(editBox, "cmd", "that kind of chat is turned off. Use /p to talk to your group!")
            elseif groupCmds[cmd] then
                local p = LooksPersonal(rest)
                if p then return Wipe(editBox, "personal", "please don't share " .. p .. " online! Keep private stuff secret.") end
            end
        end
        return
    end

    if text == "" then return end
    local chatType = editBox:GetAttribute("chatType")
    if chatType == "WHISPER" then
        local target = editBox:GetAttribute("tellTarget")
        if IsTrusted(target) then chatType = nil end
    end
    if chatType and BLOCKED_TYPES[chatType] then
        return Wipe(editBox, "type", BLOCKED_TYPES[chatType] .. " is turned off. Type /p and a space to talk to your group!")
    end
    local p = LooksPersonal(text)
    if p then
        return Wipe(editBox, "personal", "please don't share " .. p .. " online! Keep private stuff secret.")
    end
end

local hookedBoxes = {}
local function HookEditBoxes()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and not hookedBoxes[eb] then
            hookedBoxes[eb] = true
            eb:HookScript("OnTextChanged", GuardEditBox)
        end
    end
end

---------------------------------------------------------------------------
-- Self-protection: in-game AddOns list, /run, /script, /console
---------------------------------------------------------------------------
local function HookAddonList()
    if AddonList and not KS.addonListHooked then
        KS.addonListHooked = true
        AddonList:HookScript("OnShow", function(self)
            if Protected() then
                self:Hide()
                Notice("addons", "the AddOns list is locked. Ask a grown-up!", 5)
            end
        end)
    end
end

local function LockSlash(key)
    if not SlashCmdList or type(SlashCmdList[key]) ~= "function" then return end
    local original = SlashCmdList[key]
    local locked = function(...)
        if Protected() then
            Notice("slash", "that command is locked. Ask a grown-up!", 5)
            return
        end
        return original(...)
    end
    SlashCmdList[key] = locked
    -- the chat box caches handlers by command text; swap any cached copy too
    if type(hash_SlashCmdList) == "table" then
        for k, v in pairs(hash_SlashCmdList) do
            if v == original then hash_SlashCmdList[k] = locked end
        end
    end
end

local function ProtectSelf()
    if C_AddOns and C_AddOns.DisableAddOn then
        hooksecurefunc(C_AddOns, "DisableAddOn", function(name)
            if Protected() and type(name) == "string" and name:lower() == ADDON:lower() then
                C_AddOns.EnableAddOn(ADDON, UnitName("player"))
            end
        end)
    end
    if C_AddOns and C_AddOns.DisableAllAddOns then
        hooksecurefunc(C_AddOns, "DisableAllAddOns", function()
            if Protected() then C_AddOns.EnableAddOn(ADDON, UnitName("player")) end
        end)
    end
    for _, key in ipairs({ "SCRIPT", "CONSOLE", "DUMP", "TABLEINSPECT" }) do LockSlash(key) end
end

---------------------------------------------------------------------------
-- Break reminder
---------------------------------------------------------------------------
local playedMinutes = 0
local function BreakTick()
    if not Protected() then return end
    playedMinutes = playedMinutes + 1
    local every = KidSafeDB.breakMinutes or 60
    if every > 0 and playedMinutes % every == 0 then
        local h, m = math.floor(playedMinutes / 60), playedMinutes % 60
        local played
        if h == 0 then played = playedMinutes .. " minutes"
        elseif m == 0 then played = (h == 1 and "an hour" or (h .. " hours"))
        else played = h .. (h == 1 and " hour " or " hours ") .. m .. " minutes" end
        local msg = "You've been playing for " .. played .. ". Time for a stretch, a drink of water and a rest for your eyes!"
        Print("|cffffd100" .. msg .. "|r")
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, msg, { r = 1, g = 0.82, b = 0 })
        end
        if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
    end
end

---------------------------------------------------------------------------
-- Read-only page in the game's Options, so it's clear it's locked
---------------------------------------------------------------------------
local function BuildOptionsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "KidSafe"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff66ccffKidSafe|r - kid friendly mode is ON")
    local body = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    body:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    body:SetJustifyH("LEFT")
    body:SetSpacing(4)
    body:SetText(table.concat({
        "These protections are locked by a grown-up and can't be changed here:",
        "",
        "  - Private messages (whispers) are blocked",
        "  - Public chat channels (General, Trade, LFG...) are switched off",
        "  - You only see chat from your group, friends your grown-up added, and Game Masters",
        "  - Guild invites, friend requests, duels and trades are turned down",
        "  - Group invites from strangers are turned down (the Dungeon Finder still works)",
        "  - The language filter is always on",
        "  - KidSafe stops you typing private things like phone numbers or where you live",
        "  - You'll get a reminder to take a break",
        "",
        "Remember: never tell anyone online your real name, address, school,",
        "phone number or password - and tell a grown-up if anyone makes you feel uncomfortable.",
        "",
        "|cff888888Grown-ups: type /kidsafe in chat for parent controls.|r",
    }, "\n"))
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 24)
    open:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
    open:SetText("Parent controls...")
    open:SetScript("OnClick", function() if KS.OpenPanel then KS.OpenPanel() end end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "KidSafe")
    Settings.RegisterAddOnCategory(category)
    KS.category = category
end

---------------------------------------------------------------------------
-- Turn protections on/off (parent mode)
---------------------------------------------------------------------------
local function EnableProtection()
    ApplyCVars(false)
    LeaveAllChannels()
end

-- Bring the game in line with whatever Protected() says now
local function Refresh()
    if Protected() then
        EnableProtection()
    elseif not parentMode and next(KidSafeDB.origCVars or {}) then
        -- a grown-up's character gets their own settings back
        RestoreCVars()
    end
    if KS.OnStateChanged then KS.OnStateChanged() end
end

local api = {}
KS.api = api
api.Print = Print
api.CharKey = CharKey
api.Protected = Protected
api.IsUnlocked = function() return parentMode end
api.HasPin = function() return KidSafeDB.pinHash ~= nil end
api.GetRole = function() return charRole end
api.GetNewChars = function() return KidSafeDB.newChars or "protect" end
api.GetBreak = function() return KidSafeDB.breakMinutes or 60 end

local function ValidPin(pin)
    return type(pin) == "string" and pin:match("^%d%d%d%d+$") ~= nil
end
api.ValidPin = ValidPin

-- returns ok, message
function api.Unlock(pin)
    if not KidSafeDB.pinHash then return false, "No PIN has been set yet." end
    if KS.pinLockUntil and GetTime() < KS.pinLockUntil then
        return false, "Too many wrong tries - wait a few minutes."
    end
    if HashPin(pin) ~= KidSafeDB.pinHash then
        KS.badPins = (KS.badPins or 0) + 1
        Log("wrong-pin", UnitName("player"), "a wrong PIN was entered")
        if KS.badPins >= 3 then
            KS.badPins = 0
            KS.pinLockUntil = GetTime() + 600
            return false, "Wrong PIN. Locked for 10 minutes."
        end
        return false, "Wrong PIN."
    end
    KS.badPins = 0
    parentMode = true
    if charRole == "adult" then api.MarkAdultUnlocked() end
    Refresh()
    return true
end

-- remember the unlock so a /reload doesn't ask again (a real logout always does)
function api.MarkAdultUnlocked()
    adultUnlocked = true
    KidSafeDB.session = { key = CharKey(), t = time() }
end

-- Unlock a grown-up's character for this login (used by the login PIN box)
function api.UnlockAdult(pin)
    local ok, err = api.Unlock(pin)
    if not ok then return false, err end
    parentMode = false
    Refresh()
    return true
end

-- Lock a grown-up's character again right now (button, /kidsafe lockme, or going AFK)
function api.LockCharacter()
    adultUnlocked = false
    parentMode = false
    KidSafeDB.session = nil
    Refresh()
end

api.IsAdultUnlocked = function() return adultUnlocked end
api.GetAdultPin = function() return KidSafeDB.adultPin ~= false end
api.GetLockOnAFK = function() return KidSafeDB.lockOnAFK ~= false end
function api.SetAdultPin(on)
    if not parentMode then return false, "Unlock first." end
    KidSafeDB.adultPin = on and true or false
    return true
end
function api.SetLockOnAFK(on)
    if not parentMode then return false, "Unlock first." end
    KidSafeDB.lockOnAFK = on and true or false
    return true
end

function api.Lock()
    parentMode = false
    Refresh()
end

function api.SetPin(pin)
    -- the first PIN can be set by whoever installs it; changing it needs the PIN
    if KidSafeDB.pinHash and not parentMode then return false, "Unlock first." end
    if not ValidPin(pin) then return false, "The PIN must be at least 4 digits." end
    KidSafeDB.pinHash = HashPin(pin)
    return true
end

-- Making a character SAFER never needs the PIN. Switching protection OFF always does.
function api.SetRole(role, key)
    key = key or CharKey()
    if role ~= "child" and role ~= "adult" then return false, "?" end
    if role == "adult" and not parentMode then return false, "Enter the parent PIN first." end
    KidSafeDB.chars[key] = role
    if key == CharKey() then
        charRole = role
        if role == "child" then parentMode = false; adultUnlocked = false; KidSafeDB.session = nil end
        if role == "adult" then api.MarkAdultUnlocked() end
        Refresh()
    end
    return true
end

-- Unlock + mark as a grown-up's character in one go (used by the new-character pop-up)
function api.ClaimAdult(pin)
    local ok, err = api.Unlock(pin)
    if not ok then return false, err end
    api.SetRole("adult")
    parentMode = false
    Refresh()
    return true
end

function api.SetNewChars(mode)
    if not parentMode then return false, "Unlock first." end
    KidSafeDB.newChars = (mode == "shared") and "shared" or "protect"
    Refresh()
    return true
end

function api.SetBreak(minutes)
    if not parentMode then return false, "Unlock first." end
    minutes = tonumber(minutes)
    if not minutes or minutes < 0 then return false, "Enter minutes (0 = off)." end
    KidSafeDB.breakMinutes = math.floor(minutes)
    return true
end

function api.Trust(name, on)
    if not parentMode then return false, "Unlock first." end
    local n = NormName(name)
    if not n then return false, "Type a character name." end
    KidSafeDB.trusted[n] = on and true or nil
    return true
end

function api.TrustedList()
    local names = {}
    for n in pairs(KidSafeDB.trusted) do names[#names + 1] = n:sub(1, 1):upper() .. n:sub(2) end
    table.sort(names)
    return names
end

function api.CharList()
    local list = {}
    for k, role in pairs(KidSafeDB.chars) do
        local label = k:gsub("^name:(.)", function(c) return c:upper() end)
        if k:find("^name:") then label = label .. " (when they next log in)" end
        list[#list + 1] = { key = k, name = label, role = role }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Protect a character you're not logged in to (by name). Never needs the PIN: it only makes things safer.
function api.ProtectByName(name)
    local n = NormName(name)
    if not n then return false, "Type the character's name." end
    if n == NormName(UnitName("player")) then return api.SetRole("child") end
    KidSafeDB.chars["name:" .. n] = "child"
    return true
end

function api.ForgetChar(key)
    if not parentMode then return false, "Unlock first." end
    KidSafeDB.chars[key] = nil
    if key == CharKey() then charRole = nil; Refresh() end
    return true
end

function api.GetLog() return KidSafeDB.log end
function api.ClearLog() if parentMode then wipe(KidSafeDB.log) return true end return false, "Unlock first." end
function api.Restore() if parentMode then RestoreCVars() return true end return false, "Unlock first." end

-- First-time setup from the wizard (only while no PIN exists)
function api.CompleteSetup(pin, role, newChars)
    if KidSafeDB.pinHash then return false, "KidSafe is already set up." end
    if not ValidPin(pin) then return false, "The PIN must be at least 4 digits." end
    KidSafeDB.pinHash = HashPin(pin)
    KidSafeDB.newChars = (newChars == "shared") and "shared" or "protect"
    KidSafeDB.chars[CharKey()] = (role == "adult") and "adult" or "child"
    charRole = KidSafeDB.chars[CharKey()]
    if charRole == "adult" then api.MarkAdultUnlocked() end
    parentMode = false
    Refresh()
    return true
end

---------------------------------------------------------------------------
-- /kidsafe (parent controls)
---------------------------------------------------------------------------
local function Help()
    Print("is " .. (parentMode and "|cffff8000PAUSED (parent mode)|r" or "|cff00ff00ON|r") .. ".")
    Print("/kidsafe setpin 1234  - first time only: choose a parent PIN")
    Print("/kidsafe unlock 1234  - parent mode (pauses KidSafe until /kidsafe lock or relog)")
    Print("/kidsafe lock  - turn protection back on")
    Print("With the PIN unlocked:  trust <name> | untrust <name> | trusted | log [n] | clearlog | break <minutes, 0=off> | newpin <pin> | restore")
    Print("  adult - this is a grown-up's character (KidSafe off) | child - protect this character | chars")
    Print("  lockme - lock this grown-up's character now (needs the PIN to unlock)")
    Print("Or just type /kidsafe on its own for the parent control window.")
end

local function NeedParent()
    if parentMode then return true end
    Print("you need to unlock with the parent PIN first:  /kidsafe unlock <pin>")
    return false
end

SLASH_KIDSAFE1 = "/kidsafe"
SLASH_KIDSAFE2 = "/ks"
SlashCmdList.KIDSAFE = function(input)
    local cmd, arg = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "setpin" then
        if KidSafeDB.pinHash then return Print("a PIN is already set. Unlock and use /kidsafe newpin to change it.") end
        local ok, err = api.SetPin(arg)
        return Print(ok and "parent PIN saved. Don't let your child see it!" or err)

    elseif cmd == "unlock" then
        local ok, err = api.Unlock(arg)
        if not ok then return Print(err) end
        return Print("|cffff8000parent mode - all protections paused.|r Type /kidsafe lock when you're done (relogging locks it as well).")

    elseif cmd == "lockme" then
        api.LockCharacter()
        return Print("this character is locked. Enter the PIN to unlock it again.")

    elseif cmd == "lock" then
        api.Lock()
        return Print(Protected() and "|cff00ff00protection is back on.|r" or "locked. (KidSafe is off on this grown-up character.)")

    elseif cmd == "trust" then
        if not NeedParent() then return end
        local n = NormName(arg)
        if not n then return Print("usage: /kidsafe trust <character name>") end
        KidSafeDB.trusted[n] = true
        return Print(arg .. " is trusted now and can whisper, invite, trade and duel.")

    elseif cmd == "untrust" then
        if not NeedParent() then return end
        local n = NormName(arg)
        if n then KidSafeDB.trusted[n] = nil end
        return Print((arg or "?") .. " has been taken off the trusted list.")

    elseif cmd == "trusted" then
        if not NeedParent() then return end
        local names = {}
        for n in pairs(KidSafeDB.trusted) do names[#names + 1] = n end
        table.sort(names)
        return Print("trusted: " .. (#names > 0 and table.concat(names, ", ") or "(nobody yet)"))

    elseif cmd == "log" then
        if not NeedParent() then return end
        local log = KidSafeDB.log
        local n = tonumber(arg) or 20
        Print(string.format("the last %d of %d blocked items:", math.min(n, #log), #log))
        for i = math.max(1, #log - n + 1), #log do
            local e = log[i]
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff888888%s|r [%s] |cffffd100%s|r: %s",
                date("%d/%m %H:%M", e.t), e.k, e.w, e.m))
        end
        return

    elseif cmd == "clearlog" then
        if not NeedParent() then return end
        wipe(KidSafeDB.log)
        return Print("log cleared.")

    elseif cmd == "break" then
        if not NeedParent() then return end
        local m = tonumber(arg)
        if not m or m < 0 then return Print("usage: /kidsafe break <minutes>  (0 turns the reminder off)") end
        KidSafeDB.breakMinutes = math.floor(m)
        return Print(m == 0 and "break reminder turned off." or ("break reminder every " .. math.floor(m) .. " minutes."))

    elseif cmd == "newpin" then
        if not NeedParent() then return end
        local ok, err = api.SetPin(arg)
        return Print(ok and "PIN changed." or err)

    elseif cmd == "adult" or cmd == "exempt" then
        local ok, err = api.SetRole("adult")
        return Print(ok and ("|cffff8000" .. CharKey() .. " is a grown-up's character|r - KidSafe is off here.") or err)

    elseif cmd == "child" or cmd == "unexempt" then
        api.SetRole("child")
        return Print("|cff00ff00" .. CharKey() .. " is protected.|r")

    elseif cmd == "chars" then
        if not NeedParent() then return end
        for _, c in ipairs(api.CharList()) do Print(c.name .. " - " .. c.role) end
        return Print("other characters: " .. (api.GetNewChars() == "shared" and "left alone (new level 1 characters protected)" or "protected"))

    elseif cmd == "restore" then
        if not NeedParent() then return end
        RestoreCVars()
        return Print("game settings changed by KidSafe have been put back to how they were. (They'll be locked again on /kidsafe lock.)")
    end

    if cmd == "" and KS.OpenPanel then return KS.OpenPanel() end
    Help()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function TryRegister(ev)
    local ok = pcall(KS.RegisterEvent, KS, ev)
    return ok
end

KS:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON then
            KidSafeDB = KidSafeDB or {}
            KidSafeDB.trusted = KidSafeDB.trusted or {}
            KidSafeDB.log = KidSafeDB.log or {}
            KidSafeDB.chars = KidSafeDB.chars or {}
            for k in pairs(KidSafeDB.exempt or {}) do KidSafeDB.chars[k] = "adult" end
            KidSafeDB.exempt = nil
            KidSafeDB.origCVars = KidSafeDB.origCVars or {}
            if KidSafeDB.breakMinutes == nil then KidSafeDB.breakMinutes = 60 end
            BuildCmdLists()
            SetupChatFilters()
            ProtectSelf()
            BuildOptionsPage()
        end
        HookAddonList()
        return
    elseif event == "PLAYER_LOGIN" then
        -- a parent may have pre-marked this character by name in the panel
        local key = CharKey()
        local byName = "name:" .. (NormName(UnitName("player")) or "?")
        if KidSafeDB.chars[key] == nil and KidSafeDB.chars[byName] then
            KidSafeDB.chars[key] = KidSafeDB.chars[byName]
            KidSafeDB.chars[byName] = nil
        end
        charRole = KidSafeDB.chars[key]
        adultUnlocked = false   -- PLAYER_ENTERING_WORLD puts it back only for a /reload
        -- Shared account: a brand-new character (level 1, never seen) is assumed to be the child's.
        if charRole == nil and KidSafeDB.pinHash and KidSafeDB.newChars == "shared"
            and (UnitLevel("player") or 99) <= 1 then
            charRole = "child"
            KidSafeDB.chars[CharKey()] = "child"
            KS.autoChild = true
        end
        loggedIn = true
        HookEditBoxes()
        HookAddonList()
        C_Timer.NewTicker(60, BreakTick)
        C_Timer.NewTicker(60, function()
            if adultUnlocked and KidSafeDB.session then KidSafeDB.session.t = time() end
        end)
        C_Timer.NewTicker(30, function() if Protected() then ApplyCVars(false) end end)
        Refresh()
        if charRole == "adult" and Protected() then
            Print("|cffff9933this is a grown-up's character - KidSafe stays on until the PIN is entered.|r")
        elseif Protected() then
            Print("is |cff00ff00ON|r - have fun and stay safe!")
        else
            Print("|cff888888is off on this character. Type /kidsafe for parent controls.|r")
        end
        -- first install -> setup wizard; a character nobody has set up -> one quick question
        if KS.ShowFirstRun then
            C_Timer.After(2, function()
                if not KidSafeDB.pinHash then KS.ShowFirstRun("setup")
                elseif charRole == nil then KS.ShowFirstRun("newchar")
                elseif charRole == "adult" and Protected() then KS.ShowFirstRun("adultlock") end
            end)
        end
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        local sess = KidSafeDB.session
        if isReloadingUi and charRole == "adult" and sess and sess.key == CharKey()
            and time() - (sess.t or 0) < RELOAD_GRACE then
            adultUnlocked = true          -- just a /reload by the grown-up
            Refresh()
        elseif isInitialLogin then
            KidSafeDB.session = nil       -- a real login always asks for the PIN
        end
        HookEditBoxes()
        if Protected() then EnableProtection() end
        return
    elseif event == "PLAYER_FLAGS_CHANGED" then
        -- grown-up walked away (game marks you AFK after a few idle minutes) -> lock again
        local unit = ...
        if unit == "player" and charRole == "adult" and adultUnlocked and KidSafeDB.adultPin ~= false
            and KidSafeDB.lockOnAFK ~= false and UnitIsAFK and UnitIsAFK("player") then
            api.LockCharacter()
            Print("|cffff9933locked because you went AFK.|r Enter the PIN to unlock.")
            if KS.ShowFirstRun then KS.ShowFirstRun("adultlock") end
        end
        return
    elseif event == "PLAYER_LOGOUT" then
        if C_AddOns and C_AddOns.EnableAddOn then pcall(C_AddOns.EnableAddOn, ADDON, UnitName("player")) end
        return
    end

    if not Protected() then return end
    local h = handlers[event]
    if h then
        local ok, err = pcall(h, ...)
        if not ok and err then geterrorhandler()(err) end
    end
end)

for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_FLAGS_CHANGED" }) do
    TryRegister(ev)
end
for ev in pairs(handlers) do TryRegister(ev) end
