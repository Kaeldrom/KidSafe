"""Runs KidSafe against a mock WoW API in real Lua 5.1.  pip install lupa  then:  python tests/test_kidsafe.py"""
import sys
try:
    from lupa import lua51 as L
except ImportError:
    import lupa as L
lua = L.LuaRuntime(unpack_returned_tuples=True)
print("Lua:", lua.eval("_VERSION"))

MOCK = r'''
calls = {}
local function rec(name) return function(...) calls[#calls+1] = {name, ...} end end
printed = {}
function GetTime() return T or 0 end
function time() return 1 end
function date() return "01/01 00:00" end
wipe = function(t) for k in pairs(t) do t[k]=nil end return t end
function CopyTable(t) local c={} for k,v in pairs(t) do c[k]=v end return c end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed+1] = m end }
UIErrorsFrame = { AddMessage = function() end }
cvars = { profanityFilter="0", blockTrades="0", chatBubbles="1", chatBubblesParty="1", violenceLevel="2", spamFilter="1", clampme="5" }
C_CVar = { GetCVar=function(n) return cvars[n] end, SetCVar=function(n,v) if n=="violenceLevel" and v=="0" then cvars[n]="1" return end cvars[n]=v end }
C_Timer = { After=function(_, f) f() end, NewTicker=function(_, f) tickers[#tickers+1]=f end }
tickers = {}
local frames = {}
Widget = {}
Widget.__index = function(t, k)
  local v = rawget(Widget, k); if v then return v end
  if type(k) == "string" and k:find("^%u") then return function() end end
  return nil
end
function Widget:SetScript(k, fn) self.scripts[k]=fn end
function Widget:GetScript(k) return self.scripts[k] end
function Widget:HookScript(k, fn) self.scripts[k]=fn end
function Widget:RegisterEvent(e) if e=="BOGUS" then error("unknown") end self.events[e]=true end
function Widget:CreateFontString() return CreateFrame("FontString") end
function Widget:SetText(t) self.text=t end
function Widget:GetText() return self.text or "" end
function Widget:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Widget:Hide() local was=self.shown; self.shown=false; self.hidden=true; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Widget:IsShown() return self.shown end
function Widget:SetChecked(v) self.checked=v end
function Widget:Click() self.scripts.OnClick(self) end
function CreateFrame(kind, name)
  local f = setmetatable({ scripts={}, events={}, kind=kind }, Widget)
  if name then _G[name]=f end
  return f
end
UIParent = CreateFrame("Frame"); UISpecialFrames = {}; tinsert = table.insert
GameFontHighlightSmall = {}
level = 60
function UnitLevel() return level end
filters = {}
ChatFrameUtil = { AddMessageEventFilter=function(ev, fn) filters[ev]=filters[ev] or {}; table.insert(filters[ev], fn) end }
function issecretvalue(v) return v == "SECRET" end
function UnitGUID() return "Player-1" end
function UnitFullName() return "Kiddo","Realm" end
function UnitName(u) if u=="NPC" then return tradePartner end return "Kiddo" end
function Ambiguate(n) return n end
group = {}
function UnitInParty(n) return group[n] end
function UnitInRaid() return nil end
function IsGUIDInGroup(g) return group[g] end
DeclineGuild=rec("DeclineGuild"); ClosePetition=rec("ClosePetition"); DeclineGroup=rec("DeclineGroup")
CancelDuel=rec("CancelDuel"); CancelTrade=rec("CancelTrade"); LeaveChannelByName=rec("Leave")
DeclineChannelInvite=rec("DeclineChannelInvite"); BNDeclineFriendInvite=rec("BNDecline")
StaticPopup_Hide=rec("PopupHide"); SetAutoDeclineGuildInvites=rec("AutoDeclineGuild")
function GetChannelList() return 1,"General",false,2,"Trade",false end
function BNGetNumFriendInvites() return 1 end
C_BattleNet = { GetFriendInviteInfo=function() return {inviteID=7, accountName="Stranger#1"} end }
C_Club = { DeclineInvitation=rec("ClubDecline") }
C_AddOns = { DisableAddOn=function() end, EnableAddOn=rec("EnableAddOn"), DisableAllAddOns=function() end }
function hooksecurefunc(t, k, post) local o=t[k]; t[k]=function(...) o(...) post(...) end end
SlashCmdList = { SCRIPT=function(m) calls[#calls+1]={"RAN", m} end, CONSOLE=function() end }
hash_SlashCmdList = { ["/run"]=SlashCmdList.SCRIPT }
SLASH_SAY1="/s"; SLASH_SAY2="/say"; SLASH_PARTY1="/p"; SLASH_WHISPER1="/w"
Settings = { RegisterCanvasLayoutCategory=function() return {} end, RegisterAddOnCategory=function() end }
NUM_CHAT_WINDOWS=1
-- edit box
EB = { text="", attrs={chatType="SAY"} }
function EB:GetText() return self.text end
function EB:SetText(t) self.text=t; if self.scripts and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function EB:GetAttribute(k) return self.attrs[k] end
function EB:HookScript(k, fn) self.scripts = self.scripts or {}; self.scripts[k]=fn end
ChatFrame1EditBox = EB
function geterrorhandler() return function(e) error(e) end end

-- groups
ROSTER = {}          -- unit -> { first, surname }
LEADER = false
function GetNumGroupMembers() local n = 0; for _ in pairs(ROSTER) do n = n + 1 end; return n > 0 and n + 1 or 0 end
function IsInRaid() return false end
function UnitExists(u) return ROSTER[u] ~= nil or u == "player" end
function UnitIsUnit(a, b) return a == b end
function UnitIsGroupLeader() return LEADER end
function IsInGroup() return false end
C_PartyInfo = { InviteUnit = function(n) calls[#calls+1] = {"Invite", n} end,
  UninviteUnit = function(n) calls[#calls+1] = {"Uninvite", n} end,
  LeaveParty = function() calls[#calls+1] = {"LeaveParty"} end }
function hooksecurefunc(t, k, post)
  if type(t) == "string" then post = k; k = t; t = _G end
  local o = t[k]; t[k] = function(...) local r = o and o(...); post(...); return r end
end
-- voice
VOICE = { muted = false, deaf = false, active = 5 }
C_VoiceChat = { SetMuted = function(v) VOICE.muted = v end, SetDeafened = function(v) VOICE.deaf = v end,
  GetActiveChannelID = function() return VOICE.active end,
  DeactivateChannel = function(id) VOICE.active = nil; calls[#calls+1] = {"VoiceOff", id} end,
  LeaveChannel = function(id) calls[#calls+1] = {"VoiceLeave", id} end }
-- macros run their lines through this box
MacroEditBox = { text = "", attrs = {}, scripts = {} }
setmetatable(MacroEditBox, { __index = EB })
-- mail
SendMailMailButton = CreateFrame("Button"); SendMailMailButton.enabled = true
function SendMailMailButton:Disable() self.enabled = false end
function SendMailMailButton:Enable() self.enabled = true; if self.scripts.OnEnable then self.scripts.OnEnable(self) end end
function SendMailMailButton:HookScript(k, fn) self.scripts[k] = fn end
SendMailNameEditBox = CreateFrame("EditBox")
function SendMailNameEditBox:HookScript(k, fn) self.scripts[k] = fn end
function SendMailNameEditBox:SetText(t) self.text = t; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function SendMailFrame_EnableSendMailButton() SendMailMailButton.enabled = true end
SendMailFrame = CreateFrame("Frame")
LETTERS = {}         -- index -> { sender, canReply, isGM }
function GetInboxHeaderInfo(i) local l = LETTERS[i]; if not l then return end
  return nil, nil, l[1], "Hello", 0, 0, 30, false, false, false, true, l[2], l[3] end
InboxFrame = { openMailID = 1, pageNum = 1 }
INBOXITEMS_TO_DISPLAY = 2
MailItem1Subject = CreateFrame("FontString"); MailItem2Subject = CreateFrame("FontString")
function InboxFrame_Update() MailItem1Subject.text = "Hello"; MailItem2Subject.text = "Hello" end
OpenMailBodyText = CreateFrame("FontString"); OpenMailSubject = CreateFrame("FontString")
OpenMailReplyButton = CreateFrame("Button"); function OpenMailReplyButton:Disable() self.off = true end
function OpenMail_Update() OpenMailBodyText.text = "secret letter text"; OpenMailReplyButton.off = false end
SLASH_INVITE1 = "/invite"
'''
lua.execute(MOCK)
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "KidSafe.lua")
src = open(MAIN, encoding="utf-8").read()
loader = lua.execute("return function(src, n) local f, err = loadstring(src, n); if not f then error(err) end; return f end")
ns = lua.table()
loader(src, "KidSafe.lua")("KidSafe", ns)
loader(open(MAIN.replace("KidSafe.lua","KidSafe_UI.lua"), encoding="utf-8").read(), "KidSafe_UI.lua")("KidSafe", ns)
G = lua.globals()
KS = G.KidSafeFrame
on = KS.scripts.OnEvent
def fire(ev, *a): on(KS, ev, *a)
fire("ADDON_LOADED", "KidSafe")
fire("PLAYER_LOGIN")

fails = 0
def check(name, cond):
    global fails
    print(("PASS " if cond else "FAIL ") + name)
    if not cond: fails += 1

calls = lambda: [c[1] for c in G.calls.values()]
check("profanity forced", G.cvars.profanityFilter == "1")
check("blockTrades forced", G.cvars.blockTrades == "1")
check("bubbles off", G.cvars.chatBubbles == "0")
check("clamped cvar dropped, no loop", G.cvars.violenceLevel == "1")
check("left channels", calls().count("Leave") == 2)

def filt(ev, msg, author, flags="", lineID=1, guid="Player-9"):
    res = None
    for f in G.filters[ev].values():
        r = f(None, ev, msg, author, "", "", "", flags, 0, 0, "", 0, lineID, guid)
        if isinstance(r, tuple):
            if r[0]: return True, None
            if len(r) > 1: msg = r[1]
        elif r: return True, None
    return False, msg

check("whisper blocked", filt("CHAT_MSG_WHISPER", "hi kid", "Creep", lineID=10)[0])
check("whisper logged", any(e.k == "whisper" for e in G.KidSafeDB.log.values()))
check("GM whisper allowed", not filt("CHAT_MSG_WHISPER", "hello from GM", "Gm", flags="GM")[0])
check("channel blocked", filt("CHAT_MSG_CHANNEL", "WTS stuff", "Seller")[0])
check("secret whisper blocked", filt("CHAT_MSG_WHISPER", "SECRET", "SECRET", lineID=11)[0])
check("stranger say hidden", filt("CHAT_MSG_SAY", "hello", "Rando")[0])
G.group["Buddy"] = True
check("stranger in group: say still hidden", filt("CHAT_MSG_SAY", "hello", "Buddy", guid="x")[0])
check("stranger in group: party chat hidden", filt("CHAT_MSG_PARTY", "hi kid", "Buddy", lineID=19)[0])
G.KidSafeDB.trusted["buddy"] = True
check("family: say shown", not filt("CHAT_MSG_SAY", "hello", "Buddy", guid="x")[0])
h, m = filt("CHAT_MSG_PARTY", "this boss is shit lol", "Buddy", lineID=20)
check("party censored", not h and m == "this boss is **** lol")
check("party grooming hidden", filt("CHAT_MSG_PARTY", "add me on discord", "Buddy", lineID=21)[0])
check("'instance' not false-positive", not filt("CHAT_MSG_PARTY", "instance reset pls, kick him", "Buddy", lineID=22)[0])
check("'add melee' not false-positive", not filt("CHAT_MSG_PARTY", "add melee to camp", "Buddy", lineID=23)[0])
check("url hidden", filt("CHAT_MSG_PARTY", "go to www.free-gold.com", "Buddy", lineID=24)[0])
check("secret party msg hidden (fail closed)", filt("CHAT_MSG_PARTY", "SECRET", "Buddy", lineID=25)[0])
check("secret sender hidden (fail closed)", filt("CHAT_MSG_PARTY", "hello", "SECRET", lineID=26)[0])
G.KidSafeDB.trusted["buddy"] = None

G.KidSafeDB.groupPolicy = "family"
fire("PARTY_INVITE_REQUEST", "Rando")
check("party invite declined (family only)", "DeclineGroup" in calls())
fire("GUILD_INVITE_REQUEST", "Rando", "Bad Guild")
check("guild declined", "DeclineGuild" in calls())
fire("DUEL_REQUESTED", "Rando"); check("duel cancelled", "CancelDuel" in calls())
G.tradePartner = "Rando"; fire("TRADE_SHOW"); check("trade cancelled", "CancelTrade" in calls())
fire("BN_FRIEND_INVITE_ADDED"); check("bnet friend declined", "BNDecline" in calls())
fire("CHANNEL_INVITE_REQUEST", "Spam", "Rando"); check("channel invite declined", "DeclineChannelInvite" in calls())
fire("PETITION_SHOW"); check("charter closed", "ClosePetition" in calls())

# cvar tamper
G.cvars.profanityFilter = "0"; fire("CVAR_UPDATE", "profanityFilter", "0")
check("tamper reverted", G.cvars.profanityFilter == "1")

# edit box guard
EB = G.EB
def typ(text, ctype="PARTY", target=None):
    EB.attrs.chatType = ctype; EB.attrs.tellTarget = target
    EB.SetText(EB, text); return EB.text
check("say wiped", typ("hello everyone", "SAY") == "")
check("party ok", typ("hello group") == "hello group")
check("/w wiped", typ("/w Creep hi") == "")
check("/wave kept while typing", typ("/wav", "SAY") == "/wav")
check("/p phone wiped", typ("/p call me 07700 900123") == "")
check("party email wiped", typ("mail me kid@mail.com") == "")
check("party address wiped", typ("i live on Elm street") == "")
check("own slash ok", typ("/kidsafe unlock 1234", "SAY") == "/kidsafe unlock 1234")

# /run lock
G.hash_SlashCmdList["/run"]("print(1)")
check("/run locked", "RAN" not in calls())

# PIN flow
sc = G.SlashCmdList.KIDSAFE
sc("trust Mum"); check("trust needs PIN", G.KidSafeDB.trusted.mum is None)
sc("setpin 4321"); sc("unlock 1111"); sc("trust Mum"); check("wrong pin rejected", G.KidSafeDB.trusted.mum is None)
sc("unlock 4321"); sc("trust Mum"); check("trust after unlock", G.KidSafeDB.trusted.mum == True)
check("parent mode: say allowed", typ("hi all", "SAY") == "hi all")
G.hash_SlashCmdList["/run"]("print(1)"); check("parent mode: /run works", "RAN" in calls())
sc("log 5"); sc("lock")
check("relocked", typ("hi all", "SAY") == "")
check("trusted whisper allowed", not filt("CHAT_MSG_WHISPER", "dinner time", "Mum", lineID=30)[0])
check("whisper to trusted allowed", typ("ok coming", "WHISPER", "Mum") == "ok coming")
n = len(G.calls); fire("PARTY_INVITE_REQUEST", "Mum"); check("trusted invite allowed", len(G.calls) == n)
for _ in range(3): sc("unlock 0000")
sc("unlock 4321"); check("pin lockout", typ("hi", "SAY") == "")

# break reminder
for t in G.tickers.values(): pass
tick = G.tickers[1]
before = len(G.printed)
for _ in range(60): tick()
check("break reminder at 60", any("an hour" in str(p) for p in list(G.printed.values())[before:]))
# exempt flow (continues from pin lockout: wait it out)
G.T = 10000
sc("unlock 4321"); sc("exempt")
pass #, list(G.KidSafeDB.exempt.keys()), G.printed[len(G.printed)])
check("exempt saved", G.KidSafeDB.chars["Kiddo-Realm"] == "adult")
sc("lock")
check("exempt char: say allowed after lock", typ("hello", "SAY") == "hello")
G.parent_dummy = 1
sc("unlock 4321"); sc("unexempt")
check("unexempt protects", typ("hello", "SAY") == "")
# simulate login on an exempt character
G.KidSafeDB.chars["Kiddo-Realm"] = "adult"
fire("PLAYER_LOGIN")
check("login on adult char starts locked (PIN at login)", typ("hello", "SAY") == "")
G.KidSafeDB.chars["Kiddo-Realm"] = "child"
fire("PLAYER_LOGIN")
check("login on normal char protects", typ("hello", "SAY") == "")

# ---------- shared account / UI flows ----------
UI = lambda n: G[n]
def fresh_login(name, lvl=60):
    G.level = lvl
    lua.execute('UnitFullName = function() return "%s","Realm" end; UnitName = function(u) if u=="NPC" then return tradePartner end return "%s" end' % (name, name))
    G.KidSafeFrame.scripts.OnEvent(G.KidSafeFrame, "PLAYER_LOGIN")
api = G.KidSafe.api
# shared mode set by parent
sc("unlock 4321"); api.SetNewChars("shared"); api.Lock()
fresh_login("Dad")
check("shared: unknown dad char not locked", typ("hello", "SAY") == "hello")
check("shared: who-plays popup shown", UI("KidSafeWhoPlaysFrame").shown)
ask = UI("KidSafeWhoPlaysFrame")
G.T = 20000
ask.pin = None
# find the pin editbox + claim: use api directly like the button does
ok = api.ClaimAdult("4321")
check("claim adult with PIN", ok == True or (isinstance(ok, tuple) and ok[0]))
check("dad char saved adult", G.KidSafeDB.chars["Dad-Realm"] == "adult")
check("dad not unlocked afterwards (parent mode off)", not api.IsUnlocked())
fresh_login("Dad")
check("dad relog: stays grown-up but locked until PIN", G.KidSafeDB.chars["Dad-Realm"] == "adult" and typ("hi", "SAY") == "")
api.UnlockAdult("4321")
ok = api.SetRole("adult")
check("kid can't mark adult without PIN", not (ok == True))
fresh_login("Newbie", 1)
check("shared: new level-1 char auto-protected", G.KidSafeDB.chars["Newbie-Realm"] == "child" and typ("hi", "SAY") == "")
fresh_login("Oldkid", 35)
check("shared: existing kid char off until asked", typ("hi", "SAY") == "hi")
api.SetRole("child")
check("child button needs no PIN and protects", typ("hi", "SAY") == "")
# protect by name from dad's char
fresh_login("Dad")
api.ProtectByName("Sister")
check("pre-marked by name", G.KidSafeDB.chars["name:sister"] == "child")
fresh_login("Sister", 20)
check("pre-marked char protected on login", G.KidSafeDB.chars["Sister-Realm"] == "child" and typ("hi", "SAY") == "")
# panel: unlock then close re-locks
fresh_login("Sister", 20)
panel = UI("KidSafeParentFrame")
G.KidSafe.OpenPanel(); check("panel opens", panel.shown)
api.Unlock("4321"); G.KidSafe.OnStateChanged()
check("unlocked: kid char paused", typ("hi", "SAY") == "hi")
panel.Hide(panel)
check("closing panel relocks", not api.IsUnlocked() and typ("hi", "SAY") == "")
G.KidSafe.ShowLog(); check("log window opens", UI("KidSafeLogFrame").shown)
# protect mode: unknown char protected
api.Unlock("4321"); api.SetNewChars("protect"); api.Lock()
fresh_login("Mystery")
check("protect mode: unknown char protected", typ("hi", "SAY") == "")
# setup wizard on a fresh DB
G.KidSafeDB.pinHash = None
fresh_login("First")
check("wizard shows when no PIN", UI("KidSafeSetupFrame").shown)
ok = api.CompleteSetup("2468", "adult", "shared")
check("wizard setup works", G.KidSafeDB.pinHash is not None and G.KidSafeDB.chars["First-Realm"] == "adult" and typ("hi","SAY")=="hi")
check("setup cannot be re-run", not (api.CompleteSetup("1111", "adult", "shared") == True))
print("FAILURES:", fails)
# ---------- grown-up character PIN at login ----------
def pew(initial, reload):
    G.KidSafeFrame.scripts.OnEvent(G.KidSafeFrame, "PLAYER_ENTERING_WORLD", initial, reload)
fails2 = fails
G.T = 50000
fresh_login("First"); pew(True, False)
check("adult char locked at login", typ("hi", "SAY") == "")
check("PIN box shown", UI("KidSafeUnlockFrame").shown)
r = api.UnlockAdult("0000"); check("wrong PIN keeps locked", typ("hi", "SAY") == "")
r = api.UnlockAdult("2468"); check("right PIN unlocks", typ("hi", "SAY") == "hi" and not api.IsUnlocked())
fresh_login("First"); pew(False, True)
check("/reload keeps adult unlocked", typ("hi", "SAY") == "hi")
fresh_login("First"); pew(True, False)
check("real relog locks again", typ("hi", "SAY") == "")
api.UnlockAdult("2468")
lua.execute('UnitIsAFK = function() return true end')
G.KidSafeFrame.scripts.OnEvent(G.KidSafeFrame, "PLAYER_FLAGS_CHANGED", "player")
check("going AFK relocks", typ("hi", "SAY") == "")
lua.execute('UnitIsAFK = function() return false end')
api.UnlockAdult("2468"); api.LockCharacter()
check("lock now works", typ("hi", "SAY") == "")
api.Unlock("2468"); api.SetAdultPin(False); api.Lock()
fresh_login("First"); pew(True, False)
check("adultPin off: no lock at login", typ("hi", "SAY") == "hi")
api.Unlock("2468"); api.SetAdultPin(True); api.Lock()
fresh_login("Newkid2", 1); pew(True, False)
check("new kid char still protected", typ("hi", "SAY") == "")
# ---------- locked windows ----------
lua.execute('''
  function Widget:SetEnabled(v) self.enabled = v end
  CommunitiesFrame = CreateFrame("Frame"); SettingsPanel = CreateFrame("Frame")
  EditModeManagerFrame = CreateFrame("Frame")
  GameMenuFrame = CreateFrame("Frame")
  optBtn = CreateFrame("Button"); optBtn.text = "Options"; optBtn.enabled = true
  editBtn = CreateFrame("Button"); editBtn.text = "Edit Mode"; editBtn.enabled = true
  function GameMenuFrame:GetChildren() return optBtn, editBtn end
''')
G.KidSafeFrame.scripts.OnEvent(G.KidSafeFrame, "ADDON_LOADED", "Blizzard_Communities")
fresh_login("Newkid2", 1); pew(True, False)
G.CommunitiesFrame.Show(G.CommunitiesFrame)
check("guild window blocked for child", not G.CommunitiesFrame.shown)
G.SettingsPanel.Show(G.SettingsPanel)
check("options blocked for child", not G.SettingsPanel.shown)
G.GameMenuFrame.Show(G.GameMenuFrame)
check("Options button greyed", G.optBtn.enabled == False)
check("Edit Mode button left alone", G.editBtn.enabled == True)
G.GameMenuFrame.Hide(G.GameMenuFrame)
check("button handed back enabled on close", G.optBtn.enabled == True)
G.EditModeManagerFrame.Show(G.EditModeManagerFrame)
check("Edit Mode opens", G.EditModeManagerFrame.shown)
whisper_notices = [m for m in G.printed.values() if "private message" in str(m) or "/p" in str(m)]
check("no whisper or /p notices", not whisper_notices)
fresh_login("First"); pew(True, False); api.UnlockAdult("2468")
G.CommunitiesFrame.Show(G.CommunitiesFrame); G.SettingsPanel.Show(G.SettingsPanel)
G.GameMenuFrame.Show(G.GameMenuFrame)
check("unlocked grown-up: guild, options and button work", G.CommunitiesFrame.shown and G.SettingsPanel.shown and G.optBtn.enabled == True)

# =====================================================================================
# Bypass hunt: every way a protected child could reach, or be reached by, a stranger.
# The rule: no messages or voice with anyone who isn't family (trusted list + own characters).
# =====================================================================================
G.KidSafeDB.chars["Bokor-Realm"] = "child"
fresh_login("Bokor", 20); pew(True, False)
lua.execute("""
  function UnitName(u)
    if ROSTER[u] then return ROSTER[u][1], ROSTER[u][2] end
    if u == "NPC" then return tradePartner end
    if u == "target" then return TARGET and TARGET[1], TARGET and TARGET[2] end
    return "Bokor"
  end
""")
check("bypass setup: child protected", api.Protected())
G.KidSafeDB.groupPolicy = "family"
def last(name):
    return [c for c in G.calls.values() if c[1] == name]

# --- 1. the reported case: invite a random person, then /p
G.calls = lua.table()
check("/invite stranger wiped", typ("/invite Random Person", "SAY") == "")
lua.execute('TARGET = {"Random", "Person"}')
check("/inv on a stranger target wiped", typ("/inv ", "SAY") == "")
G.C_PartyInfo.InviteUnit("Random Person")
check("menu invite to stranger cancelled at once", any(c[2] == "Random Person" for c in last("Uninvite")))
lua.execute('ROSTER = { party1 = {"Random", "Person"} }; LEADER = true')
G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("stranger who joined anyway is removed (kid leads)", any(c[2] == "Random Person" for c in last("Uninvite")))
lua.execute('LEADER = false'); G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("stranger's group: kid leaves", len(last("LeaveParty")) == 1)
check("/p with a stranger in the group wiped", typ("/p hello", "SAY") == "")
check("sticky PARTY chat with a stranger wiped", typ("hello", "PARTY") == "")
check("/raid, /i and /rw too", typ("/raid hi", "SAY") == "" and typ("/i hi", "SAY") == "" and typ("/rw hi", "SAY") == "")
check("stranger's party message hidden", filt("CHAT_MSG_PARTY", "hi", "Random Person", lineID=900)[0])
check("stranger's party leader message hidden", filt("CHAT_MSG_PARTY_LEADER", "hi", "Random Person", lineID=901)[0])
check("stranger's raid warning hidden", filt("CHAT_MSG_RAID_WARNING", "hi", "Random Person", lineID=902)[0])
check("stranger's instance chat hidden", filt("CHAT_MSG_INSTANCE_CHAT", "hi", "Random Person", lineID=903)[0])
check("stranger in group: /say hidden", filt("CHAT_MSG_SAY", "hi", "Random Person", lineID=904)[0])
check("stranger in group: custom emote hidden", filt("CHAT_MSG_EMOTE", "hugs you", "Random Person", lineID=905)[0])
check("group bubbles off (they skip chat filters)", G.cvars.chatBubblesParty == "0")

# --- 2. open groups (grown-up allows dungeons): grouped, but still no chat
G.KidSafeDB.groupPolicy = "open"; G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("open: stranger may stay", len(last("LeaveParty")) == 0 and len(last("Uninvite")) == 0)
check("open: /p still wiped", typ("/p hi", "SAY") == "")
check("open: stranger's party chat still hidden", filt("CHAT_MSG_PARTY", "hi", "Random Person", lineID=906)[0])
G.KidSafeDB.groupPolicy = "family"

# --- 3. family is fine
G.KidSafeDB.trusted["mum smith"] = True
lua.execute('ROSTER = { party1 = {"Mum", "Smith"} }')
G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("family in group: stays", len(last("LeaveParty")) == 0 and len(last("Uninvite")) == 0)
check("family in group: /p works", typ("/p hi mum", "SAY") == "/p hi mum")
check("family party message shown", not filt("CHAT_MSG_PARTY", "dinner", "Mum Smith", lineID=907)[0])
check("same first name, different person: still a stranger", filt("CHAT_MSG_PARTY", "hi", "Mum Jones", lineID=908)[0])
G.KidSafeDB.chars["Gromir-Crypmaghar"] = "adult"
check("own character: whisper allowed", not filt("CHAT_MSG_WHISPER", "hi", "Gromir Crypmaghar", lineID=910)[0])
lua.execute('ROSTER = { party1 = {"Mum", "Smith"}, party2 = {"Random", "Person"} }')
check("family + one stranger: /p wiped", typ("/p hi", "SAY") == "")
lua.execute('ROSTER = { party1 = {"SECRET", nil} }'); G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("unreadable group member treated as stranger", len(last("LeaveParty")) == 1)

# --- 4. macros (run through MacroEditBox, not the chat box)
MB = G.MacroEditBox
lua.execute('ROSTER = { party1 = {"Random", "Person"} }')
for line in ("/s hello", "/w Random hi", "/p hi", "/1 hello", "/invite Random Person", "/e waves", "/g hi"):
    MB.SetText(MB, line)
    check("macro line blocked: " + line, MB.text == "")
MB.SetText(MB, "/cast Frostbolt")
check("macro /cast untouched", MB.text == "/cast Frostbolt")
lua.execute('ROSTER = {}')
lua.execute('MacroFrame = CreateFrame("Frame")'); fire("ADDON_LOADED", "Blizzard_MacroUI")
G.MacroFrame.Show(G.MacroFrame)
check("macro window locked", not G.MacroFrame.shown)

# --- 5. every free-text chat type and command
for ct in ("SAY", "YELL", "EMOTE", "WHISPER", "BN_WHISPER", "CHANNEL", "GUILD", "OFFICER"):
    check("typing in %s wiped" % ct, typ("hello", ct, "Random") == "")
for cmd in ("/s", "/y", "/e", "/me", "/w Random", "/r", "/g", "/o", "/1", "/2", "/join x", "/bn x", "/voice x", "/friend Random", "/f Random"):
    check("command wiped: " + cmd, typ(cmd + " hi", "SAY") == "")
check("incoming BN whisper hidden", filt("CHAT_MSG_BN_WHISPER", "hi", "Stranger#1", lineID=911)[0])
check("incoming community chat hidden", filt("CHAT_MSG_COMMUNITIES_CHANNEL", "hi", "Rando", lineID=912)[0])
check("incoming guild chat hidden", filt("CHAT_MSG_GUILD", "hi", "Rando", lineID=913)[0])
check("AFK auto-reply hidden", filt("CHAT_MSG_AFK", "brb", "Rando", lineID=914)[0])

# --- 6. voice
G.calls = lua.table(); G.VOICE.active = 5; G.VOICE.muted = False; G.VOICE.deaf = False
fire("VOICE_CHAT_LOGIN")
check("voice: muted and deafened", G.VOICE.muted == True and G.VOICE.deaf == True)
check("voice: active channel turned off", G.VOICE.active is None)
G.calls = lua.table(); fire("VOICE_CHAT_CHANNEL_JOINED", 0, 77, 1)
check("voice: joined channel left straight away", any(c[2] == 77 for c in last("VoiceOff")) and any(c[2] == 77 for c in last("VoiceLeave")))
G.VOICE.muted = False; fire("VOICE_CHAT_MUTED_CHANGED", False)
check("voice: unmuting is undone", G.VOICE.muted == True)
check("voice transcription text hidden", filt("CHAT_MSG_VOICE_TEXT", "hello kid", "Rando", lineID=915)[0])
lua.execute('ChannelFrame = CreateFrame("Frame")'); fire("ADDON_LOADED", "Blizzard_Channels")
G.ChannelFrame.Show(G.ChannelFrame)
check("chat & voice channel window locked", not G.ChannelFrame.shown)

# --- 7. mail
fire("MAIL_SHOW")
SB, NB = G.SendMailMailButton, G.SendMailNameEditBox
NB.SetText(NB, "Random Person"); G.SendMailFrame_EnableSendMailButton()
check("mail to a stranger: Send disabled", SB.enabled == False)
SB.Enable(SB)
check("mail: re-enabled Send gets disabled again", SB.enabled == False)
NB.SetText(NB, "Gromir Crypmaghar"); SB.enabled = True; G.SendMailFrame_EnableSendMailButton()
check("mail to own character allowed (Family Mailbox)", SB.enabled == True)
NB.SetText(NB, "Mum Smith"); SB.enabled = True; G.SendMailFrame_EnableSendMailButton()
check("mail to trusted family allowed", SB.enabled == True)
lua.execute('LETTERS = { [1] = {"Random Person", true, false}, [2] = {"Auction House", false, false} }')
G.InboxFrame_Update()
check("stranger's letter subject hidden in inbox", G.MailItem1Subject.text == "(hidden)")
check("auction house mail left alone", G.MailItem2Subject.text == "Hello")
G.OpenMail_Update()
check("stranger's letter text hidden", "hid" in G.OpenMailBodyText.text and G.OpenMailReplyButton.off)
lua.execute('LETTERS = { [1] = {"Mum Smith", true, false} }; InboxFrame.openMailID = 1')
G.OpenMail_Update()
check("family letter readable", G.OpenMailBodyText.text == "secret letter text")
lua.execute('LETTERS = { [1] = {"Gm", true, true} }'); G.OpenMail_Update()
check("Game Master letter readable", G.OpenMailBodyText.text == "secret letter text")

# --- 8. other places strangers write text
FR = ("CalendarFrame", "LFGListFrame", "LFGBrowseFrame", "LFGListingFrame", "LFGListApplicationDialog", "AddFriendFrame")
for fname in FR: lua.execute(fname + ' = CreateFrame("Frame")')
fire("ADDON_LOADED", "Blizzard_Calendar")
for fname in FR:
    f = G[fname]; f.Show(f)
    check(fname + " locked", not f.shown)

# --- 9. still no way to switch any of it off
G.hash_SlashCmdList["/run"]("KidSafeDB.groupPolicy='open'")
check("/run still locked", G.KidSafeDB.groupPolicy == "family")
sc("groups open")
check("group setting needs the PIN", G.KidSafeDB.groupPolicy == "family")
sc("trust Random Person")
check("trusting needs the PIN", G.KidSafeDB.trusted["random person"] is None)

# --- 10. grown-up characters are left alone
fresh_login("First"); pew(True, False); api.UnlockAdult("2468")
lua.execute('ROSTER = { party1 = {"Random", "Person"} }; LEADER = false')
G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("unlocked grown-up: groups with strangers untouched", len(last("LeaveParty")) == 0)
check("unlocked grown-up: /p works", typ("/p hi", "SAY") == "/p hi")
lua.execute('ROSTER = {}')


# --- 11. quest groups (the default): strangers OK in the open world, never chat, no dungeons
G.KidSafeDB.chars["Bokor-Realm"] = "child"
fresh_login("Bokor", 20); pew(True, False)
lua.execute("""
  function UnitName(u)
    if ROSTER[u] then return ROSTER[u][1], ROSTER[u][2] end
    if u == "NPC" then return tradePartner end
    return "Bokor"
  end
  INSTANCE = { false, "none" }
  function IsInInstance() return INSTANCE[1], INSTANCE[2] end
  RAID = false
  function IsInRaid() return RAID end
""")
G.KidSafeDB.groupPolicy = None
check("default is quest groups", G.KidSafe.GroupPolicy() == "quests")
G.calls = lua.table(); fire("PARTY_INVITE_REQUEST", "Random Person")
check("quests: a stranger's invite isn't auto-declined", "DeclineGroup" not in calls())
check("quests: inviting a stranger is allowed", typ("/invite Random Person", "SAY") == "/invite Random Person")
lua.execute('ROSTER = { party1 = {"Random", "Person"} }; LEADER = false')
G.calls = lua.table(); fire("GROUP_JOINED"); fire("GROUP_ROSTER_UPDATE")
check("quests: open-world group with a stranger stays", len(last("LeaveParty")) == 0 and len(last("Uninvite")) == 0)
check("quests: /p to the stranger still wiped", typ("/p hi", "SAY") == "")
check("quests: stranger's party chat still hidden", filt("CHAT_MSG_PARTY", "you noob", "Random Person", lineID=950)[0])
check("quests: no message is sent to the group about KidSafe", not any(c[1] == "SendChatMessage" for c in G.calls.values()))
lua.execute('INSTANCE = { true, "party" }'); G.calls = lua.table(); fire("ZONE_CHANGED_NEW_AREA")
check("quests: entering a dungeon with strangers -> leaves", len(last("LeaveParty")) == 1)
lua.execute('INSTANCE = { true, "pvp" }'); G.calls = lua.table(); fire("ZONE_CHANGED_NEW_AREA")
check("quests: battleground with strangers -> leaves", len(last("LeaveParty")) == 1)
lua.execute('INSTANCE = { false, "none" }; RAID = true; ROSTER = { raid1 = {"Random", "Person"} }'); G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("quests: turned into a raid -> leaves", len(last("LeaveParty")) == 1)
lua.execute('RAID = false; ROSTER = { party1 = {"Random", "Person"} }')
G.T = 100000; fire("QUEST_WATCH_UPDATE"); G.T = 100000 + 19 * 60
G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("quests: 19 minutes without progress: stays", len(last("LeaveParty")) == 0)
G.T = 100000 + 21 * 60; G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
check("quests: 21 minutes without quest progress -> leaves", len(last("LeaveParty")) == 1)
lua.execute('ROSTER = { party1 = {"Mum", "Smith"} }'); G.calls = lua.table(); fire("GROUP_ROSTER_UPDATE")
lua.execute('INSTANCE = { true, "party" }'); fire("ZONE_CHANGED_NEW_AREA")
check("quests: dungeon with family only is fine", len(last("LeaveParty")) == 0)
lua.execute('INSTANCE = { false, "none" }; ROSTER = {}')
lua.execute('LFDParentFrame = CreateFrame("Frame"); PVPUIFrame = CreateFrame("Frame")'); fire("ADDON_LOADED", "Blizzard_PVPUI")
G.LFDParentFrame.Show(G.LFDParentFrame); G.PVPUIFrame.Show(G.PVPUIFrame)
check("quests: dungeon and battleground queues locked", not G.LFDParentFrame.shown and not G.PVPUIFrame.shown)
G.KidSafeDB.groupPolicy = "open"
G.LFDParentFrame.Show(G.LFDParentFrame)
check("open: dungeon queue allowed", G.LFDParentFrame.shown)
lua.execute('ROSTER = { party1 = {"Random", "Person"} }; INSTANCE = { true, "party" }'); G.calls = lua.table(); fire("ZONE_CHANGED_NEW_AREA")
check("open: dungeon with strangers stays", len(last("LeaveParty")) == 0)
check("open: still no chat", typ("/p hi", "SAY") == "" and filt("CHAT_MSG_PARTY", "hi", "Random Person", lineID=951)[0])
lua.execute('ROSTER = {}; INSTANCE = { false, "none" }')
G.KidSafeDB.groupPolicy = "quiet"
check("1.4.0's 'quiet' reads as open", G.KidSafe.GroupPolicy() == "open")
G.KidSafeDB.groupPolicy = None

print("FAILURES TOTAL:", fails)
sys.exit(1 if fails else 0)
