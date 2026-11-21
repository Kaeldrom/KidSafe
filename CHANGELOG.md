# Changelog

## 1.5.0
Fixes from a penetration test, done as the child and as a stranger. `tests/pentest_kidsafe.py` now runs 40 attacks.
- **Fix: other addons' "run code" commands could switch KidSafe off.** For example, Details!' `/dumpt` runs any Lua after it.
  - Those commands and windows are locked on a child's character, from the chat box and from macros: Details! `/dumpt`, Run Code and custom displays, WeakAuras, WowLua and similar.
  - Lua code typed after any command is wiped.
- **Fix: saved settings could be rewritten or the PIN deleted.**
  - KidSafe keeps a private copy of its settings. Changes made by anything else are put back within 2 seconds and again before the game saves, and are logged.
  - The saved file is sealed. If it was changed anyway, every character stays protected until the PIN is entered.
  - Each character's own saved file remembers the PIN. Deleting the account file no longer lets the set-up wizard run again.
- **Fix: closing "Who plays this character?" left an old character unprotected.**
  - Characters nobody has set up are protected until a grown-up answers.
  - This also covers new characters that start above level 1.
- **Fix: raid warnings from strangers showed on screen.** The game's big centre-screen text skipped the chat filters. Family's raid warnings still show.
- **Fix: Deadly Boss Mods showed strangers' timer text and notes.** DBM's own "don't show other players' timers" and "block note sharing" switches are on for children's characters, and handed back for grown-ups.
- **Fix: `/afk` and `/dnd` messages reached strangers.**
  - Away messages are off. Plain `/afk` and `/dnd` still work.
  - Personal info is now checked after any command.
  - "snap", "insta", "gamertag" and similar words are on the list.
- **Fix: a `/reload` reset the PIN lock-out.**
  - Wrong tries are saved.
  - Three wrong tries lock the PIN for 10 minutes, then 20, then 30 and so on.
- **Fix: parent mode on a child's character never ended.** It now ends on AFK, or after 15 minutes without using the controls.
- **Fix: instant declines could give KidSafe away.**
  - Group, duel, trade and guild invites are answered after a 2-6 second pause.
  - The question is hidden from the child in the meantime.
- **Fix: strangers could send gold and items by mail.**
  - Letters from strangers with gold, items or cash on delivery are sent back unopened.
  - Their money and item buttons can't be clicked.
- **Fix: the quest-group idle timer restarted on `/reload`.** The time is saved now.
- **Fix: a first name on its own matched strangers.**
  - `/kidsafe trust` needs the full "First Surname".
  - First names trusted before 1.5.0 no longer count. The parent is told which ones when they unlock.
- New saved file per character (`KidSafeCharDB`).

## 1.4.0
- **Fix: a child could invite a stranger and chat with them in /p.** Messages and voice with anyone who isn't family (trusted list + this account's characters) are now off everywhere, whatever the group.
- Groups, chosen by a grown-up with `/kidsafe groups`:
  - **quests** (default): strangers can group in the open world for group quests and elites. No dungeons, raids or battlegrounds with strangers (the child leaves), the queue windows are locked, and a group with no quest progress for 20 minutes is left.
  - **family**: family only; strangers are removed (or the child leaves) and invites to strangers are cancelled.
  - **open**: strangers anywhere, dungeons too.
- Nothing tells other players that KidSafe is there: no announcements, and leaving or removing happens after a short, uneven pause. To others the child is just someone who doesn't talk.
- Group chat is family only both ways; strangers in the group can't be heard in /say or emotes either. Group speech bubbles are off.
- Unreadable messages or names (secret values) are hidden, not shown.
- Voice chat: muted, deafened, removed from voice channels; voice-to-text hidden; the channels window is locked.
- Mail: Send is disabled unless the recipient is family; strangers' letters show no subject or text and can't be replied to.
- Macros: lines run by macros are checked like typed chat; the macro window is locked.
- Calendar, group finder listings and Add Friend are locked (other players write text there).
- Trusted names must be the full "First Surname" so a stranger with the same first name doesn't count.
- 198 automated checks, including a bypass hunt that fails on 1.3.0.

## 1.3.0
- Guild & Communities window (J) is locked on children's characters, so guild chat (live and history) can't be read there.
- Options/Settings window is locked and the Options button in the Escape menu is greyed out. Edit Mode still works, so UI can be moved around.
- Quieter: no more "use /p" tips, and the child isn't told when someone tried to whisper, invite or friend them (it's still in the parent log).

## 1.2.0
- Grown-up characters ask for the parent PIN at every login and lock again on logout or AFK, so a child logging in to a parent's character stays protected. A /reload doesn't ask again.
- "Lock this character now" button and `/kidsafe lockme`.

## 1.1.0
- Shared-account support: each character asks "Who plays this character?" once; brand-new level 1 characters are protected automatically.
- First-time setup wizard, parent control panel, blocked-items log window.
- Protect a character by name without logging in to it.
- Grown-ups' characters get their own game settings back.

## 1.0.0
- First version: blocks whispers, chat channels, strangers' chat, invites, trades and duels; forces the language filter on; personal-info guard; break reminder; parent PIN.
