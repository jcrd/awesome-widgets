local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local beautiful = require('beautiful')
local dpi = require('beautiful.xresources').apply_dpi

local pomo = {}

pomo.widget = {}

local widget
local show_icon

local icon_widget = {
    widget = wibox.widget.imagebox,
    handler = function(w, a) w.image = a end,
    assets = {},
}

local times = {}
local state = {}
local set_length

local blink_timer = gears.timer {
    timeout = 0.5,
    callback = function()
        widget.id_blink.visible = widget.id_time.visible
        widget.id_time.visible = not widget.id_time.visible
    end,
}

blink_timer:connect_signal('stop', function()
    widget.id_time.visible = true
    widget.id_blink.visible = false
end)

local function set_visibility(v)
    widget.id_time.visible = v
    widget.id_margin.visible = v
    if not show_icon then
        widget.id_const.visible = v
    end
end

local function update_state(tbl, k, v)
    if blink_timer.started then
        blink_timer:stop()
    end
    if k == 'name' then
        set_visibility(not (v == 'stopped'))
        icon_widget.handler(widget.id_const.id_icon, icon_widget.assets[v])
        if times[v] ~= nil then
            tbl.time = times[v]
        end
    elseif k == 'time' then
        widget.id_time.text = os.date('%M:%S', v)
    elseif k == 'rep' then
        widget.id_margin.id_rep.markup = string.format(
            '<span size=\'smaller\' rise=\'2000\'>%d</span>', v)
    end
    state[k] = v
end

local s = setmetatable({}, {
    __index = function(_, k) return state[k] end,
    __newindex = update_state,
})

local function init()
    s.name = 'stopped'
    s.rep = 1
end

local function tick()
    s.time = s.time - 1
    if s.time > 0 then
        return
    end
    if s.name == 'working' then
        if s.rep == set_length then
            s.name = 'long_break'
        else
            s.name = 'short_break'
        end
    elseif s.name == 'long_break' then
        s.rep = 1
        s.name = 'working'
    elseif s.name == 'short_break' then
        s.rep = s.rep + 1
        s.name = 'working'
    end
end

local timer = gears.timer {
    timeout = 1,
    callback = tick,
}

local function load_assets(path)
    local function load_image(file)
        return gears.surface(string.format('%s/assets/pomodoro/%s', path, file))
    end

    return {
        stopped = load_image('done.svg'),
        working = load_image('ticking.svg'),
        short_break = load_image('short_pause.svg'),
        long_break = load_image('long_pause.svg'),
    }
end

function pomo.init(ds)
    assert(ds.config, 'dependency error: missing config')
    assert(ds.config.set_length, 'dependency error: missing config.set_length')
    assert(ds.config.working, 'dependency error: missing config.working')
    assert(ds.config.short_break, 'dependency error: missing config.short_break')
    assert(ds.config.long_break, 'dependency error: missing config.long_break')
    -- `ds.config.show_icon` is an optional dependency.
    -- `ds.icon_widget` is an optional dependency.

    if ds.icon_widget then
        assert(ds.icon_widget.widget, 'dependency error: missing icon_widget.widget')
        assert(ds.icon_widget.handler, 'dependency error: missing icon_widget.handler')
        assert(ds.icon_widget.assets, 'dependency error: missing icon_widget.assets')
        local asset_keys = { 'stopped', 'working', 'short_break', 'long_break' }
        for _, v in ipairs(asset_keys) do
            assert(ds.icon_widget.assets[v],
                'dependency error: missing icon_widget.assets.' .. v)
        end
        icon_widget = ds.icon_widget
    else
        assert(ds.path, 'dependency error: missing path')
        icon_widget.assets = load_assets(ds.path)
    end

    set_length = ds.config.set_length
    show_icon = ds.config.show_icon or false
    times = setmetatable({ stopped = ds.config.working }, { __index = ds.config })
end

function pomo.widget.timer(opts)
    if not widget then
        opts = opts or {}
        opts.buttons = opts.buttons or {
            awful.button({}, 1, pomo.toggle),
            awful.button({}, 3, pomo.stop),
        }

        widget = wibox.widget {
            {
                {
                    id = 'id_icon',
                    widget = icon_widget.widget,
                },
                id = 'id_const',
                layout = wibox.container.constraint,
                strategy = 'min',
                width = beautiful.font_size,
                visible = show_icon,
            },
            {
                id = 'id_time',
                widget = wibox.widget.textbox,
                visible = false,
            },
            {
                -- Same width as time in `id_time` textbox.
                text = '     ',
                visible = false,
                id = 'id_blink',
                widget = wibox.widget.textbox,
            },
            {
                {
                    id = 'id_rep',
                    widget = wibox.widget.textbox,
                },
                id = 'id_margin',
                widget = wibox.container.margin,
                left = dpi(2),
                visible = false,
            },
            layout = wibox.layout.fixed.horizontal,
            buttons = opts.buttons,
        }
        init()
    end
    return widget
end

function pomo.toggle()
    if not widget then
        return
    end
    if s.name == 'stopped' then
        s.name = 'working'
    end
    if timer.started then
        timer:stop()
        blink_timer:start()
    else
        blink_timer:stop()
        timer:start()
    end
end

function pomo.stop()
    if not widget then
        return
    end
    if s.name ~= 'stopped' then
        timer:stop()
        init()
    end
end

function pomo.restart()
    if not widget then
        return
    end
    if s.name ~= 'stopped' then
        s.time = times[s.name]
    end
end

return pomo
