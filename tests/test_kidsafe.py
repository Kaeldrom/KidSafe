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
cvars = { profanityFilter="0", blockTrades="0", chatBubbles="1", violenceLevel="2", spamFilter="1", clampme="5" }
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
check("group say shown", not filt("CHAT_MSG_SAY", "hello", "Buddy", guid="x")[0])
h, m = filt("CHAT_MSG_PARTY", "this boss is shit lol", "Buddy", lineID=20)
check("party censored", not h and m == "this boss is **** lol")
check("party grooming hidden", filt("CHAT_MSG_PARTY", "add me on discord", "Buddy", lineID=21)[0])
check("'instance' not false-positive", not filt("CHAT_MSG_PARTY", "instance reset pls, kick him", "Buddy", lineID=22)[0])
check("'add melee' not false-positive", not filt("CHAT_MSG_PARTY", "add melee to camp", "Buddy", lineID=23)[0])
check("url hidden", filt("CHAT_MSG_PARTY", "go to www.free-gold.com", "Buddy", lineID=24)[0])
check("secret party msg passes", not filt("CHAT_MSG_PARTY", "SECRET", "Buddy", lineID=25)[0])

fire("PARTY_INVITE_REQUEST", "Rando")
check("party invite declined", "DeclineGroup" in calls())
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
print("FAILURES TOTAL:", fails)
sys.exit(1 if fails else 0)
