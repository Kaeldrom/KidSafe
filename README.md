# KidSafe

A World of Warcraft **Forever** addon (interface 16001) that makes the game safer for young children, and works on a **shared account** where a parent and child both have characters.

## What it does on a child's character
- **Blocks private messages** (whispers and Battle.net whispers) in and out. Game Masters and trusted people still get through.
- **Leaves all public chat channels** (General, Trade, LFG, custom) and declines channel invites.
- **Hides strangers' /say, /yell and emotes.** The child can only talk to their group (/p, /raid, /instance).
- **Filters group chat:** forces the language filter on, stars out extra swear words, and hides messages that ask for personal info or try to move the child off the game (Discord, Snapchat, "how old are you", links, "free gold"...).
- **Stops the child typing personal info:** phone numbers, email addresses, "I live...", "my school", passwords.
- **Declines automatically:** guild invites, guild charters, community invites, friend requests, duels, pet battle duels, group invites from strangers (the Dungeon Finder still works) and trades.
- **Locks game settings:** language filter, spam filter, block trades, block channel invites, no speech bubbles from strangers, no guild names over heads, less blood. If anything changes them, they're put back.
- **Protects itself:** the in-game AddOns list, `/run`, `/script` and `/console` are locked.
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

Closing the panel locks everything again.

## Limits
An addon can't run on the character-select screen, so it can't stop someone unticking it there. For limits that can't be bypassed, also set up **Battle.net Parental Controls** at account.battle.net (play time, spending, voice chat, social). Those are enforced by Blizzard's servers.

KidSafe doesn't filter in-game mail, the in-game shop or voice chat.

**Forgot the PIN?** Close the game and delete `WTF\Account\<ACCOUNT>\SavedVariables\KidSafe.lua`.

## Development
```
pip install lupa
python tests/test_kidsafe.py
```
The tests run the addon in real Lua 5.1 against a mock WoW API. They are not part of the packaged addon.

Releases: push a tag such as `v1.2.0`. GitHub Actions runs the tests, then packages the addon with BigWigsMods/packager and uploads it to CurseForge.
