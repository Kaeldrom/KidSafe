# KidSafe

A World of Warcraft **Forever** addon (interface 16001) that makes the game safer for young children, and works on a **shared account** where a parent and child both have characters.

## What it does on a child's character
- **Blocks private messages** (whispers and Battle.net whispers) in and out. Game Masters and family still get through.
- **Leaves all public chat channels** (General, Trade, LFG, custom) and declines channel invites.
- **No messages with strangers, in or out of a group.** Only family can chat, whisper, mail, trade or duel with the child: the trusted list (full "First Surname" names) plus the characters on this account.
- **Groups** (`/kidsafe groups`): **quests** (default) lets strangers group in the open world for group quests and elites, but not dungeons, raids or battlegrounds, and a group with no quest progress for 20 minutes is left; **family** is family only; **open** allows dungeons with strangers too. Chat with strangers stays off in every mode, and nothing tells other players KidSafe is there.
- **No voice chat:** muted, deafened, and taken out of any voice channel; voice-to-text is hidden.
- **Mail:** letters can only be sent to family; letters from strangers show no text (items and gold still arrive).
- **Macros can't get round it:** macro lines are checked like typed chat, and the macro window is locked.
- **Hides strangers' /say, /yell and emotes**, even when they're in the group.
- **Filters group chat:** forces the language filter on, stars out extra swear words, and hides messages that ask for personal info or try to move the child off the game (Discord, Snapchat, "how old are you", links, "free gold"...).
- **Stops the child typing personal info:** phone numbers, email addresses, "I live...", "my school", passwords.
- **Declines automatically:** guild invites, guild charters, community invites, friend requests, duels, pet battle duels and trades from anyone who isn't family. With groups set to **family**, group invites from strangers are declined too, and the child can't invite strangers.
- **Locks game settings:** language filter, spam filter, block trades, block channel invites, no speech bubbles (group ones too), no guild names over heads, less blood. If anything changes them, they're put back.
- **Locks windows** where other players' messages can be read or sent: Guild & Communities (J), chat & voice channels, calendar, group finder listings, Add Friend and macros. Options/Settings is locked too (the Escape menu button is greyed out), and so are the dungeon and battleground queues unless groups are **open**. Edit Mode still works.
- **Protects itself:** the in-game AddOns list, `/run`, `/script` and `/console` are locked.
- **Stays quiet:** the child isn't told when someone tried to whisper, invite or friend them; it's all in the parent log.
- **Invisible to other players:** nothing is announced and nothing names KidSafe, so nobody can tell the character is a child's. To others the child is just a player who doesn't talk.
- **Break reminder** every 60 minutes (adjustable).
- **Logs everything it blocks**, so a parent can review it.

## Characters
- A **setup wizard** runs the first time: choose a PIN, say who plays the current character, and say whether this is a shared account or the child's own.
- Each character KidSafe hasn't seen asks **"Who plays this character?"** once. "My child" needs no PIN; "It's mine" needs the PIN.
- On a shared account, **brand-new level 1 characters are protected automatically**.
- **Grown-up characters ask for the PIN at every login** and lock again on logout or AFK, so a child who logs in to a parent's character is still protected. A `/reload` doesn't ask again.
- Making a character safer never needs the PIN. Turning protection off always does.

## Parent controls
Type `/kidsafe` (or use the addon button by the minimap, or Options → AddOns → KidSafe) and enter the PIN. From there you can mark characters as a child's or a grown-up's, manage trusted people, set the break reminder, change the PIN, review what was blocked, and choose whether grown-up characters ask for the PIN.

With the PIN entered you can also type:
- `/kidsafe trust First Surname` - family and real-life friends on other accounts (the full name: on WoW Forever every character has a surname). The characters on this account are family already.
- `/kidsafe groups quests | family | open` - who the child can group with (see above).

Closing the panel locks everything again.

## Limits
An addon can't run on the character-select screen, so it can't stop someone unticking it there. For limits that can't be bypassed, also set up **Battle.net Parental Controls** at account.battle.net (play time, spending, voice chat, social). Those are enforced by Blizzard's servers.

KidSafe doesn't control the in-game shop. Messages that other addons send by themselves (for example a quest addon announcing progress to the group) aren't something KidSafe can stop.

**Forgot the PIN?** Close the game and delete `WTF\Account\<ACCOUNT>\SavedVariables\KidSafe.lua`.

## Development
```
pip install lupa
python tests/test_kidsafe.py
```
The tests run the addon in real Lua 5.1 against a mock WoW API. They are not part of the packaged addon.

Releases: CurseForge packages the addon straight from this repository (every commit becomes a test build; a tag such as `v1.4.0` becomes a release). The tests are left out of the package.
