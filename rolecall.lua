--[[
* rolecall - FFXI party management for Ashita v4.
*
* Combines autojoin (atom0s & Thorny) and autoinv (goose), both GPLv3.
* This file is distributed under the same license: https://www.gnu.org/licenses/
--]]

addon.name    = 'rolecall';
addon.author  = 'grimwaldr (from autojoin by atom0s & Thorny, autoinv by goose)';
addon.version = '1.0';
addon.desc    = 'Auto accept/decline party invites and auto-invite players who send a tell.';
addon.link    = 'https://ashitaxi.com/';

require('common');
local chat     = require('chat');
local settings = require('settings');

local defaults = T{
    join = T{ mode = 'ask', accept = T{ }, decline = T{ }, ask = T{ } },
    inv  = T{ mode = 'off', allow = T{ }, deny = T{ } },
    triggers = T{ 'inv', 'please invite me.', 'invite to join party' },
};

-- Each per-player list and the group it belongs to. A name lives in at most one list per group.
local lists = { accept = 'join', decline = 'join', ask = 'join', allow = 'inv', deny = 'inv' };
local modes = { join = { accept = true, decline = true, ask = true }, inv = { on = true, off = true } };

local rc = {
    settings = settings.load(defaults),
    lookup   = { join = { }, inv = { } }, -- lowercase name -> list name
};

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

local function say(...)
    local out = chat.header(addon.name);
    for _, part in ipairs({ ... }) do
        out = out:append(part);
    end
    print(out);
end

-- FFXI names are always "Capitalized".
local function proper(name)
    return (name:lower():gsub('^%l', string.upper));
end

local function rebuild()
    rc.lookup = { join = { }, inv = { } };
    for list, group in pairs(lists) do
        for _, name in ipairs(rc.settings[group][list] or { }) do
            rc.lookup[group][name:lower()] = list;
        end
    end
end

-- Removes a name from every list in a group. Returns the list it was in, or nil.
local function unlist(group, name)
    local found = nil;
    for list, g in pairs(lists) do
        if (g == group) then
            local t = rc.settings[group][list];
            for i = #t, 1, -1 do
                if (t[i]:lower() == name:lower()) then
                    table.remove(t, i);
                    found = list;
                end
            end
        end
    end
    return found;
end

local function save()
    settings.save();
    rebuild();
end

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        rc.settings = s;
    end
    save();
end);

----------------------------------------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------------------------------------

local function print_help()
    local cmds = {
        { '/rc',                                 'Show current modes, lists and triggers.' },
        { '/rc join <accept|decline|ask>',       'Default action for party invites you receive.' },
        { '/rc inv <on|off>',                    'Default for auto-inviting players who send a trigger tell.' },
        { '/rc <accept|decline|ask> <name>',     'Per-player rule for invites from <name>.' },
        { '/rc <allow|deny> <name>',             'Per-player rule for auto-inviting <name>.' },
        { '/rc remove <name>',                   'Remove <name> from every list.' },
        { '/rc trigger <add|del> <phrase>',      'Add or remove a tell phrase that triggers an invite.' },
        { '/rc <reload|reset>',                  'Reload settings from disk, or reset to defaults.' },
    };
    say(chat.message('Commands (/rolecall also works):'));
    for _, c in ipairs(cmds) do
        say(chat.success(c[1]), chat.message(' - '), chat.color1(6, c[2]));
    end
end

local function print_status()
    local s = rc.settings;
    local function show(label, t)
        say(chat.message(label .. ': '), chat.color1(5, #t > 0 and table.concat(t, ', ') or '(none)'));
    end
    say(chat.message('Invites received, default: '), chat.success(s.join.mode));
    show('  accept', s.join.accept);
    show('  decline', s.join.decline);
    show('  ask', s.join.ask);
    say(chat.message('Auto-invite on tell, default: '), chat.success(s.inv.mode));
    show('  allow', s.inv.allow);
    show('  deny', s.inv.deny);
    show('Triggers', s.triggers);
end

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or not args[1]:lower():any('/rc', '/rolecall')) then
        return;
    end
    e.blocked = true;

    local cmd = (args[2] or ''):lower();
    local arg = args[3];

    if (cmd == '' or cmd == 'list' or cmd == 'status') then
        print_status();

    elseif (cmd == 'help') then
        print_help();

    elseif (cmd == 'reload' or cmd == 'rl') then
        settings.reload();
        say(chat.message('Settings reloaded from disk.'));

    elseif (cmd == 'reset') then
        settings.reset();
        say(chat.message('Settings reset to defaults.'));

    -- /rc join <mode>  |  /rc inv <mode>
    elseif (modes[cmd] ~= nil and arg ~= nil) then
        local m = arg:lower();
        if (not modes[cmd][m]) then
            local opts = { };
            for k in pairs(modes[cmd]) do opts[#opts + 1] = k; end
            say(chat.error('Invalid mode. Expected one of: '), chat.message(table.concat(opts, ', ')));
            return;
        end
        rc.settings[cmd].mode = m;
        settings.save();
        say(chat.message(('Default %s mode set to: '):fmt(cmd)), chat.success(m));

    -- /rc <accept|decline|ask|allow|deny> <name>
    elseif (lists[cmd] ~= nil and arg ~= nil) then
        local group, name = lists[cmd], proper(arg);
        local prev = unlist(group, name);
        table.insert(rc.settings[group][cmd], name);
        save();
        if (prev ~= nil and prev ~= cmd) then
            say(chat.success(name), chat.message((' moved from %s to %s.'):fmt(prev, cmd)));
        else
            say(chat.success(name), chat.message((' added to %s.'):fmt(cmd)));
        end

    -- /rc remove <name>
    elseif (cmd:any('remove', 'del', 'rm') and arg ~= nil) then
        local name = proper(arg);
        local a, b = unlist('join', name), unlist('inv', name);
        if (a == nil and b == nil) then
            say(chat.error(name .. ' is not on any list.'));
            return;
        end
        save();
        say(chat.success(name), chat.message(' removed.'));

    -- /rc trigger <add|del> <phrase...>
    elseif (cmd == 'trigger' and #args >= 4) then
        local op, phrase = args[3]:lower(), table.concat(args, ' ', 4):lower();
        local t = rc.settings.triggers;
        local idx = nil;
        for i, v in ipairs(t) do
            if (v == phrase) then idx = i; end
        end

        if (op == 'add') then
            if (idx == nil) then table.insert(t, phrase); end
            say(chat.message('Trigger added: '), chat.success(phrase));
        elseif (op:any('del', 'remove', 'rm')) then
            if (idx == nil) then
                say(chat.error('No such trigger: ' .. phrase));
                return;
            end
            table.remove(t, idx);
            say(chat.message('Trigger removed: '), chat.success(phrase));
        else
            print_help();
            return;
        end
        settings.save();

    else
        say(chat.error('Invalid command. '), chat.message('Try /rc help'));
    end
end);

----------------------------------------------------------------------------------------------------
-- Packets
----------------------------------------------------------------------------------------------------

-- 0x00DC: someone invited us to their party.
local function on_party_invite(e)
    local name   = struct.unpack('c16', e.data_modified, 0x0C + 1):trim('\0');
    local action = rc.lookup.join[name:lower()] or rc.settings.join.mode;


    -- 'ask' lets the packet through so the normal in-game invite prompt appears.
    if (action == 'ask') then
        return;
    end

    e.blocked = true;
    local reply = { 0x74, 0x04, 0x00, 0x00, (action == 'accept') and 1 or 0, 0x00, 0x00, 0x00 };
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x74, reply);

    say(chat.message(action == 'accept' and 'Accepted invite from: ' or 'Declined invite from: '), chat.success(name));
end

-- 0x0017: incoming chat. Mode 3 is a tell.
local function on_chat(e)
    if (struct.unpack('B', e.data_modified, 0x04 + 1) ~= 0x03) then
        return;
    end

    local name = struct.unpack('c15', e.data_modified, 0x08 + 1):trim('\0');
    local rule = rc.lookup.inv[name:lower()];
    if (rule == 'deny' or (rule == nil and rc.settings.inv.mode ~= 'on')) then
        return;
    end

    -- Packet size is stored in the upper 7 bits of the header, in 4-byte units.
    local size = 0x04 * bit.rshift(struct.unpack('H', e.data_modified, 0x01), 0x09) - 0x17;
    if (size <= 0) then
        return;
    end

    local text = struct.unpack(('c%d'):fmt(size), e.data_modified, 0x17 + 1):trim('\0');
    text = AshitaCore:GetChatManager():ParseAutoTranslate(text, true):lower():match('^%s*(.-)%s*$');

    for _, trigger in ipairs(rc.settings.triggers) do
        if (text == trigger) then
            AshitaCore:GetChatManager():QueueCommand(1, '/pcmd add ' .. name);
            say(chat.message('Inviting: '), chat.success(name));
            return;
        end
    end
end

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.id == 0x00DC) then
        on_party_invite(e);
    elseif (e.id == 0x0017) then
        on_chat(e);
    end
end);

ashita.events.register('load', 'load_cb', rebuild);
