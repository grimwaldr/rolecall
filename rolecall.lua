--[[
* rolecall - FFXI party management for Ashita v4.
*
* Based on Ashita's autojoin addon, Copyright (c) 2021 Ashita Development Team.
* Licensed under the GNU GPL v3: https://www.gnu.org/licenses/
--]]

addon.name    = 'rolecall';
addon.author  = 'Grimwald & Goose';
addon.version = '1.1';
addon.desc    = 'Auto-accept invites from, and auto-invite on trigger tell, players on a whitelist.';
addon.link    = 'https://github.com/grimwaldr/rolecall';

require('common');
local chat     = require('chat');
local settings = require('settings');

local defaults = T{
    whitelist = T{ },
    trigger   = 'inv',
};

local rc = {
    settings = settings.load(defaults),
    lookup   = { }, -- lowercase name -> true
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
    rc.lookup = { };
    for _, name in ipairs(rc.settings.whitelist) do
        rc.lookup[name:lower()] = true;
    end
end

local function save()
    settings.save();
    rebuild();
end

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        rc.settings = s;
    end
    rebuild();
end);

----------------------------------------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------------------------------------

local function print_status()
    local wl = rc.settings.whitelist;
    say(chat.message('Whitelist: '), chat.color1(5, #wl > 0 and table.concat(wl, ', ') or '(empty)'));
    say(chat.message('Trigger: '), chat.success(rc.settings.trigger));
end

local function print_help()
    local cmds = {
        { '/rc',                'Show the whitelist and trigger.' },
        { '/rc add <name>',     'Add a player to the whitelist.' },
        { '/rc remove <name>',  'Remove a player from the whitelist.' },
        { '/rc trigger <word>', 'Set the tell that gets a whitelisted player invited.' },
    };
    say(chat.message('Whitelisted players are auto-accepted when they invite you,'));
    say(chat.message('and auto-invited when they /tell you the trigger.'));
    for _, c in ipairs(cmds) do
        say(chat.success(c[1]), chat.message(' - '), chat.color1(6, c[2]));
    end
end

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or not args[1]:lower():any('/rc', '/rolecall')) then
        return;
    end
    e.blocked = true;

    local cmd = (args[2] or ''):lower();
    local wl  = rc.settings.whitelist;

    if (cmd == '' or cmd == 'list') then
        print_status();

    elseif (cmd == 'add' and args[3] ~= nil) then
        local name = proper(args[3]);
        if (rc.lookup[name:lower()]) then
            say(chat.success(name), chat.message(' is already on the whitelist.'));
            return;
        end
        table.insert(wl, name);
        save();
        say(chat.success(name), chat.message(' added to the whitelist.'));

    elseif (cmd:any('remove', 'rm', 'del') and args[3] ~= nil) then
        local name = proper(args[3]);
        for i = #wl, 1, -1 do
            if (wl[i]:lower() == name:lower()) then
                table.remove(wl, i);
                save();
                say(chat.success(name), chat.message(' removed from the whitelist.'));
                return;
            end
        end
        say(chat.error(name .. ' is not on the whitelist.'));

    elseif (cmd == 'trigger' and args[3] ~= nil) then
        rc.settings.trigger = table.concat(args, ' ', 3):lower();
        settings.save();
        say(chat.message('Trigger set to: '), chat.success(rc.settings.trigger));

    else
        print_help();
    end
end);

----------------------------------------------------------------------------------------------------
-- Packets
----------------------------------------------------------------------------------------------------

-- 0x00DC: someone invited us to their party. Non-whitelisted invites pass through to the normal prompt.
local function on_party_invite(e)
    local name = struct.unpack('c16', e.data_modified, 0x0C + 1):trim('\0');
    if (not rc.lookup[name:lower()]) then
        return;
    end

    e.blocked = true;
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x74, { 0x74, 0x04, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 });
    say(chat.message('Accepted invite from: '), chat.success(name));
end

-- 0x0017: incoming chat. Mode 3 is a tell.
local function on_chat(e)
    if (struct.unpack('B', e.data_modified, 0x04 + 1) ~= 0x03) then
        return;
    end

    local name = struct.unpack('c15', e.data_modified, 0x08 + 1):trim('\0');
    if (not rc.lookup[name:lower()]) then
        return;
    end

    -- Packet size is stored in the upper 7 bits of the header, in 4-byte units.
    local size = 0x04 * bit.rshift(struct.unpack('H', e.data_modified, 0x01), 0x09) - 0x17;
    if (size <= 0) then
        return;
    end

    local text = struct.unpack(('c%d'):fmt(size), e.data_modified, 0x17 + 1):trim('\0');
    text = AshitaCore:GetChatManager():ParseAutoTranslate(text, true):lower():match('^%s*(.-)%s*$');

    if (text == rc.settings.trigger) then
        AshitaCore:GetChatManager():QueueCommand(1, '/pcmd add ' .. name);
        say(chat.message('Inviting: '), chat.success(name));
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
