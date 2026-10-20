# rolecall

An FFXI group management addon (Ashita v4) designed to assist support players in buffing multiple parties in an alliance. Replaces `autojoin` and `autoinv`.

## How it works

**Invites you receive** (packet 0x0DC). Each invite is checked against your per-player lists, then the default mode:

- `accept`: auto-accepts
- `decline`: auto-declines
- `ask`: does nothing, so the normal in-game prompt shows

**Auto-invite** (tells, packet 0x017). If a player sends you a tell that exactly matches a trigger phrase (not case sensitive, auto-translate is parsed), rolecall runs `/pcmd add <name>`. Players on `allow` are always invited. Players on `deny` are never invited. Everyone else depends on whether the default is `on` or `off`.

A name can only be on one list per side, so adding it to `accept` takes it off `decline`.

## Commands

`/rolecall` also works.

| Command | Does |
|---|---|
| `/rc` | Show modes, lists, triggers |
| `/rc join <accept\|decline\|ask>` | Default for invites you receive |
| `/rc inv <on\|off>` | Default for auto-invite |
| `/rc <accept\|decline\|ask> <name>` | Per-player invite rule |
| `/rc <allow\|deny> <name>` | Per-player auto-invite rule |
| `/rc remove <name>` | Remove name from all lists |
| `/rc trigger <add\|del> <phrase>` | Manage trigger phrases |
| `/rc reload` / `/rc reset` | Reload settings from disk / reset to defaults |
| `/rc help` | Command list |

Defaults: join `ask`, inv `off`, triggers `inv`, `please invite me.`, `invite to join party`.

Settings are per character in `config/addons/rolecall/`.

## Install

Copy the `rolecall` folder to `Ashita/addons/` and run `/addon load rolecall`. Unload `autojoin` and `autoinv` first.

## Credits

Based on autojoin (atom0s & Thorny) and autoinv (goose). GPLv3.
