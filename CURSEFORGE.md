# KidSafe

**Makes World of Warcraft Forever safer for young children** - on the child's own account, or on a **shared family account** where a grown-up and a child both have characters.

The rule KidSafe enforces: **on a child's character, nobody outside the family can message them or talk to them - by chat, whisper, mail or voice.** Family means the characters on this account plus the people a grown-up adds with the PIN.

## What it does on a child's character

**Messages and voice**
- **Whispers and Battle.net whispers** are blocked in and out. Family and Game Masters still get through.
- **Public chat channels** (General, Trade, LFG, custom) are left, and channel invites declined.
- **Group chat is family only** - in both directions. Strangers in the group can't message the child, and their /say, /yell and emotes are hidden too. Group speech bubbles are off.
- **Family chat is still filtered:** the language filter is forced on, extra swear words are starred out, and messages asking for personal info or trying to move the child off the game (Discord, Snapchat, "how old are you", links, "free gold"...) are hidden.
- **Voice chat is off:** muted, deafened and taken out of any voice channel; voice-to-text is hidden.
- **Mail:** letters can only be sent to family. Letters from strangers show no subject or text, and ones with gold, items or cash on delivery are sent back unopened.
- **Typing personal info is stopped:** phone numbers, email addresses, "I live...", "my school", passwords, Snapchat or Instagram names. Away messages are off (the game sends them to anyone who whispers).
- **No strangers' text on screen** through raid warnings or Deadly Boss Mods timer bars and notes.
- **Macros can't get round any of this** - macro lines are checked like typed chat, and the macro window is locked.

**Groups** - a grown-up chooses:
- **Quest groups** (default): strangers can group with the child in the open world for group quests and elites. No dungeons, raids or battlegrounds with strangers (the child leaves, and the queue windows are locked), and a group with no quest progress for 20 minutes is left. No messages with them at any point.
- **Family only:** strangers are removed from the group, or the child leaves; the child can't invite strangers.
- **Open:** strangers anywhere, dungeons too - still no messages.

**Invisible to other players.** KidSafe never announces itself, and nothing it does names it, so nobody can tell the character belongs to a child. To other players the child is simply someone who doesn't talk.

**Everything else**
- **Declines automatically** (after a short, human-like pause): guild invites, guild charters, community invites, friend requests, duels, pet battle duels and trades from anyone outside the family.
- **Locks game settings:** language filter, spam filter, block trades, block channel invites, no speech bubbles, no guild names over heads, less blood. If anything changes them, they're put back.
- **Locks windows where other players' messages can be read or sent:** Guild & Communities, chat & voice channels, calendar, group finder listings, Add Friend, macros - and Options. Edit Mode still works.
- **Protects itself:** the in-game AddOns list, /run, /script and /console are locked, and so are other addons' "run code" commands and windows. KidSafe's settings are guarded: changes from outside are put back.
- **Stays quiet:** the child isn't told when someone tried to whisper, invite or friend them - it's all in the parent log.
- **Break reminder** every 60 minutes (adjustable).

## Shared accounts
- A **setup wizard** runs the first time: choose a PIN, say who plays this character, and whether the account is shared.
- Each new character asks **"Who plays this character?"** once and stays protected until someone answers. "My child" needs no PIN; "It's mine" needs the PIN.
- **Brand-new level 1 characters are protected automatically** on a shared account.
- **Grown-up characters ask for the PIN at every login** and lock again on logout or AFK, so a child logging in to a parent's character is still protected.
- Making a character safer never needs the PIN. Turning protection off always does.

## Parent controls
Type **/kidsafe** (or use the addon button by the minimap, or Options > AddOns > KidSafe) and enter the PIN to mark characters, review the log, set the break reminder or change the PIN. Closing the panel locks everything again, and so does going AFK or 15 minutes without using the controls.

With the PIN entered:
- **/kidsafe trust First Surname** - family and real-life friends on other accounts. Use the full name (a first name on its own is refused): on WoW Forever every character has a surname.
- **/kidsafe groups quests | family | open** - who the child can group with.

## Limits
An addon can't run on the character-select screen, so it can't stop someone unticking it there. For limits that can't be bypassed, also set up **Battle.net Parental Controls** (play time, spending, voice, social) - those are enforced by Blizzard's servers. KidSafe doesn't control the in-game shop, and can't stop messages that other addons send by themselves. Any addon that runs Lua code could in principle undo any other addon: KidSafe locks the known ones and guards its settings, but only install addons you trust on a child's computer.

**Forgot the PIN?** Close the game and delete `WTF\Account\<ACCOUNT>\SavedVariables\KidSafe.lua`, and also `KidSafe.lua` in each character's own folder, `WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\` (each character remembers the PIN, so deleting only the first file isn't enough).

Source and issues: https://github.com/Kaeldrom/KidSafe
