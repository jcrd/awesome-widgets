local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local beautiful = require('beautiful')
local dpi = require('beautiful.xresources').apply_dpi

local deps = {}

local audio = {}

audio.widget = {}
audio.widget.icons = {[false] = '', [true] = ''}
audio.widget.icon_markup = function (i)
    return '<span rise="4000">'..i..'</span>'
end

audio.volume_step = 0.05

local widget
local backend
local backend_name

local function on_change(v, m)
    if audio.on_change then
        audio.on_change(v * 100, m)
    end

    if not widget then
        return
    end

    widget.id_progress.value = v
    widget.id_icon.markup = audio.widget.icon_markup(audio.widget.icons[m])

    if not widget.visible then
        widget.visible = true
    end
end

local function with_backend(func_name, ...)
    if not backend then
        return
    end
    if not backend.default then
        deps.logger.error('[audio] Failed to get default sink')
        return
    end
    deps.logger.debug('[audio] Calling backend function: %s', func_name)
    backend.default[func_name](...)
end

local function connect_backend(appear)
    if not appear then
        backend = nil
        if backend_name then
            deps.logger.error('[audio] Lost connection to backend: %s', backend_name)
            backend_name = nil
        end
        return
    end

    if deps.sessiond_dbus and deps.sessiond_dbus.audio_enabled then
        backend_name = 'sessiond'
        backend = deps.sessiond_dbus.audiosinks
        deps.sessiond_dbus.on_default_audiosink_change = on_change
    elseif deps.pulseaudio_backend then
        backend_name = 'pulseaudio'
        backend = deps.pulseaudio_backend.connect(deps)
        if backend then
            backend.on_default_audiosink_change = on_change
        end
    end

    if not backend then
        deps.logger.error('[audio] Failed to connect to backend: %s', backend_name)
        return
    end

    deps.logger.debug('[audio] Connected to backend: %s', backend_name)

    with_backend('update')
end

function audio.init(ds)
    assert(ds.logger, 'dependency error: missing logger')
    assert(ds.logger.error, 'dependency error: missing logger.error')
    assert(ds.logger.debug, 'dependency error: missing logger.debug')

    local found
    for dep in pairs(ds) do
        if dep == 'sessiond_dbus' or dep == 'pulseaudio_backend' then
            found = true
        end
    end
    assert(found, 'dependency error: missing one of {sessiond_dbus, pulseaudio_backend}')

    deps = ds

    local function delayed_connect(appear)
        gears.timer.delayed_call(function ()
            connect_backend(appear)
        end)
    end

    if deps.sessiond_dbus then
        deps.sessiond_dbus.add_hook(delayed_connect)
    elseif deps.pulseaudio_backend then
        delayed_connect(true)
    end
end

function audio.widget.volumebar(opts)
    if not widget then
        opts = opts or {}
        opts.width = dpi(opts.width or 50)
        opts.height = dpi(opts.height or 2)
        opts.buttons = opts.buttons or {
            awful.button({}, 1, audio.toggle_mute),
            awful.button({}, 4, function () audio.inc_volume() end),
            awful.button({}, 5, function () audio.dec_volume() end),
        }

        widget = wibox.widget {
            {
                id = 'id_icon',
                widget = wibox.widget.textbox,
                forced_width = beautiful.font_size * 1.5,
            },
            {
                id = 'id_progress',
                widget = wibox.widget.progressbar,
                max_value = 1,
                forced_width = opts.width,
                margins = {
                    top = beautiful.wibar_height / 2 - opts.height,
                    bottom = beautiful.wibar_height / 2 - opts.height,
                    left = opts.height,
                    right = opts.height,
                },
                color = beautiful.fg_normal,
                background_color = beautiful.bg_normal_alt
                    or beautiful.bg_normal,
            },
            layout = wibox.layout.fixed.horizontal,
            visible = false,
            buttons = opts.buttons,
        }
    end
    return widget
end

function audio.inc_volume(v)
    with_backend('inc_volume', v or audio.volume_step)
end

function audio.dec_volume(v)
    with_backend('dec_volume', v or audio.volume_step)
end

function audio.toggle_mute()
    with_backend('toggle_mute')
end

return audio
