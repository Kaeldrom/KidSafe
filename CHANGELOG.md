# Changelog

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
