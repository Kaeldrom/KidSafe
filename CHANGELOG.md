# Changelog

## 1.4.0
- **Fix: a child could invite a stranger and chat with them in /p.** Groups are now family only: the trusted list plus this account's characters. Strangers who get in are removed (or the child leaves); invites to strangers are cancelled, typed or from menus.
- Group chat is family only both ways, even with a grown-up's permission for dungeon groups (`/kidsafe groups quiet`). Strangers in the group can't be heard in /say or emotes either. Group speech bubbles are off.
- Unreadable messages or names (secret values) are hidden, not shown.
- Voice chat: muted, deafened, removed from voice channels; voice-to-text hidden; the channels window is locked.
- Mail: Send is disabled unless the recipient is family; strangers' letters show no subject or text and can't be replied to.
- Macros: lines run by macros are checked like typed chat; the macro window is locked.
- Calendar, group finder listings and Add Friend are locked (other players write text there).
- Trusted names must be the full "First Surname" so a stranger with the same first name doesn't count.
- 180 automated checks, including a bypass hunt that fails on 1.3.0.

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
