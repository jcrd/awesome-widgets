local wibox = require('wibox')
local gears = require('gears')
local beautiful = require('beautiful')
local dpi = require('beautiful.xresources').apply_dpi

local battery = {}

battery.widget = {}
battery.widget.icons = {
    power = 'ﮣ',
    [100] = '',
    [75] = '',
    [50] = '',
    [25] = '',
    [0] = '',
}

local power = false
local batt
local widget

local function get_battery(upower)
    for i = 1,#upower.Manager.devices do
        local dev = upower.Manager.devices[i]
        if dev.type == upower.enums.DeviceType.Battery then
            return dev
        end
    end
end

local function format_sec(s)
    return os.date('!%X', s)
end

local function format_icon(i)
    return '<span rise="4000">'..i..'</span>'
end

local function get_icon(percent)
    if percent > 75 then
        return battery.widget.icons[100]
    elseif percent > 50 then
        return battery.widget.icons[75]
    elseif percent > 25 then
        return battery.widget.icons[50]
    elseif percent > 10 then
        return battery.widget.icons[25]
    else
        return battery.widget.icons[0]
    end
end

local function update()
    local function on_update(time)
        if battery.on_update then
            battery.on_update(power, time, batt.Percentage)
        end
    end

    if batt.TimeToEmpty > 0 then
        local function set()
            local t = format_sec(batt.TimeToEmpty)

            widget.id_icon.markup = format_icon(get_icon(batt.Percentage))
            widget.id_time.text = t

            on_update(t)
        end

        if power then
            -- TimeToEmpty is incorrect immediately after unplugging power
            gears.timer {
                timeout = 1,
                single_shot = true,
                autostart = true,
                callback = set,
            }
            power = false
        else
            set()
        end
    else
        power = true
        local t = format_sec(batt.TimeToFull)

        widget.id_icon.markup = format_icon(battery.widget.icons.power)
        widget.id_time.text = t

        on_update(t)
    end
end

function battery.init(ds)
    assert(ds.upower_dbus, 'dependency error: missing upower_dbus')

    batt = get_battery(ds.upower_dbus)

    if batt then
        batt:on_properties_changed(function (p, changed)
            if changed.TimeToEmpty or changed.TimeToFull then
                update()
            end
        end)

        gears.timer {
            timeout = 20,
            autostart = true,
            callback = function () batt:Refresh() end,
        }
    end
end

function battery.widget.time()
    if batt and not widget then
        widget = wibox.widget {
            {
                id = 'id_icon',
                widget = wibox.widget.textbox,
                forced_width = beautiful.font_size + dpi(8),
            },
            {
                id = 'id_time',
                widget = wibox.widget.textbox,
            },
            layout = wibox.layout.fixed.horizontal,
        }
        update()
    end
    return widget
end

return battery
