# rolecall

An FFXI group management addon (Ashita v4) designed to assist support players in buffing multiple parties in an alliance. Replaces `autojoin` and `autoinv`.

## How it works

One whitelist, both directions:

- A whitelisted player invites you: auto-accepted.
- A whitelisted player sends you the trigger in a tell (`inv` by default): auto-invited.

Anyone not on the whitelist is left alone, so the normal game prompts apply.

For a BRD/COR moving between alliance parties, the BRD/COR whitelists each party leader and each leader whitelists the BRD/COR.

## Example

Grimwald (COR) needs to roll for Goose's party in the alliance.

Both load rolecall and whitelist each other:

```
Grimwald: /rc add Goose
Goose:    /rc add Grimwald
```

Grimwald sets up two hotkeys (macros or Ashita binds):

```
/pcmd leave
/tell Goose inv
```

Two presses: leave, then tell. Goose's rolecall sees the tell and invites Grimwald, and Grimwald's rolecall accepts. Goose doesn't have to do anything, but he does need to be his party's leader to invite.

Keep one leave key and add a tell key per party leader to move around the alliance, including back to your own party.

## Commands

`/rolecall` also works.

| Command | Does |
|---|---|
| `/rc` | Show the whitelist and trigger |
| `/rc add <name>` | Add a player to the whitelist |
| `/rc remove <name>` | Remove a player from the whitelist |
| `/rc trigger <word>` | Set the trigger tell (not case sensitive) |
| `/rc help` | Command list |

Settings are per character in `config/addons/rolecall/`.

## Install

Copy the `rolecall` folder to `Ashita/addons/` and run `/addon load rolecall`. Unload `autojoin` and `autoinv` first.
