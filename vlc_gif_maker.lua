--[[
--------------------------------------------
Installation guide: put "vlc_gif_maker.lua" file in installation directory
suitable to your operating system:

* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
* Windows (current user): %APPDATA%\VLC\lua\extensions\
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/
--------------------------------------------
To open GIF Maker: View > VLC Gif Maker

Patched fork: https://github.com/Ron-RONZZ-org/VLC-GIF-Maker
--------------------------------------------
--]]----------------------------------------

default_command = 'ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i "{input_file}" -vf "fps={fps},scale=498:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop {loop} "{output_path}/{output_filename}.gif"'
default_fps = "15"
default_looping = 0

command = false
output_path = false
fps = default_fps
looping = default_looping

function config_path(filename)
    return vlc.config.configdir() .. "/gif_maker_" .. filename
end

function load_config(filename, fallback)
    local file = io.open(config_path(filename), "r")
    if file == nil then
        save_config(filename, fallback)
        return fallback
    end

    local value = file:read("*l")
    file:close()

    if value == nil or value == "" then
        save_config(filename, fallback)
        return fallback
    end

    return value
end

function save_config(filename, value)
    local file, err = io.open(config_path(filename), "w+b")
    if file == nil then
        vlc.msg.err("GIF Maker: could not save " .. filename .. ": " .. tostring(err))
        return false
    end
    file:write(tostring(value))
    file:close()
    return true
end

function trim(text)
    if text == nil then return "" end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Collapse zero or more separators between the output path and the filename
-- placeholders, so both "{output_path}/{output_filename}" and the older
-- "{output_path}{output_filename}" produce a valid path.
function migrate_command(template)
    if template == nil then return template end
    return (template:gsub("{output_path}[/\\]*{output_filename}",
                          "{output_path}/{output_filename}"))
end

-- Accepts "SS", "MM:SS" and "HH:MM:SS", with an optional fractional part
-- separated by "." or ",". Returns a normalized "H:MM:SS.mmm" string and the
-- value in seconds, or nil and an error message.
function parse_timestamp(text)
    text = trim(text)
    if text == "" then
        return nil, "empty timestamp"
    end
    text = text:gsub(",", ".")

    local parts = {}
    for part in text:gmatch("[^:]+") do
        parts[#parts + 1] = part
    end

    local seconds
    if #parts == 1 then
        local value = tonumber(parts[1])
        if value == nil or value < 0 then
            return nil, "invalid seconds"
        end
        seconds = value
    elseif #parts == 2 then
        local minutes = tonumber(parts[1])
        local secs = tonumber(parts[2])
        if minutes == nil or secs == nil
           or minutes < 0 or secs < 0 or minutes >= 60 or secs >= 60 then
            return nil, "minutes and seconds must be between 0 and 59"
        end
        seconds = minutes * 60 + secs
    elseif #parts == 3 then
        local hours = tonumber(parts[1])
        local minutes = tonumber(parts[2])
        local secs = tonumber(parts[3])
        if hours == nil or minutes == nil or secs == nil
           or hours < 0 or minutes < 0 or secs < 0
           or minutes >= 60 or secs >= 60 then
            return nil, "expected HH:MM:SS"
        end
        seconds = hours * 3600 + minutes * 60 + secs
    else
        return nil, "expected SS, MM:SS or HH:MM:SS"
    end

    local whole = math.floor(seconds)
    local millis = math.floor((seconds - whole) * 1000 + 0.5)
    if millis >= 1000 then
        whole = whole + 1
        millis = millis - 1000
    end

    local hours = math.floor(whole / 3600)
    local minutes = math.floor((whole % 3600) / 60)
    local secs = whole % 60

    return string.format("%d:%02d:%02d.%03d", hours, minutes, secs, millis), seconds
end

function get_timestamp()
    local input = vlc.object.input()
    if input == nil then
        return string.format("%d:%02d:%02d.%03d", 0, 0, 0, 0)
    end

    local microseconds = vlc.var.get(input, "time") or 0
    local seconds_total = math.floor(microseconds / 1000000)
    local hours = math.floor((seconds_total % 86400) / 3600)
    local minutes = math.floor((seconds_total % 3600) / 60)
    local seconds = seconds_total % 60
    local milliseconds = math.floor((microseconds / 1000) % 1000)

    return string.format("%d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
end

function strip_trailing_separators(path)
    if path == nil then return "" end
    return (path:gsub("[/\\]+$", ""))
end

function output_file_for(path, filename)
    return strip_trailing_separators(path) .. "/" .. filename .. ".gif"
end

-- Keep everything except a trailing .gif, so "my.video" stays "my.video".
function sanitize_filename(name)
    name = trim(name)
    if name == "" then
        return "g" .. os.time()
    end
    name = name:gsub("%.[gG][iI][fF]$", "")
    if name == "" then
        return "g" .. os.time()
    end
    return name
end

function url_decode(text)
    return (text:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

function execute_succeeded(ok)
    -- Lua 5.1 returns an exit status number; Lua 5.2+ returns true/nil.
    if type(ok) == "number" then
        return ok == 0
    end
    return ok == true
end

function fail(message)
    vlc.msg.err("GIF Maker: " .. message)
    vlc.osd.message(message, 1, "top", 5000000)
end

function gui_create_ffmpeg_warning()
    ffmpegDlg = vlc.dialog("GIF Maker")

    -- col, row, col_span, row_span, width, height
    ffmpegDlg:add_label("WARNING: ffmpeg couldn't be found! Make sure it's available globally (PATH for Windows users)", 1, 1)
    ffmpegDlg:add_button("OK", startExtension, 1, 2)
end

function gui_create_main_dialog(template, path, saved_fps, saved_looping)
    dlg = vlc.dialog("GIF Maker")
    -- left side

    -- col, row, col_span, row_span, width, height
    dlg:add_label("Start time: ", 1, 1)
    start_timestamp_input = dlg:add_text_input("", 2, 1)
    dlg:add_button("Get", fill_start_timestamp, 3, 1)

    dlg:add_label("End time: ", 1, 2)
    stop_timestamp_input = dlg:add_text_input("", 2, 2)
    dlg:add_button("Get", fill_stop_timestamp, 3, 2)

    dlg:add_label("GIFs output path:", 1, 3)
    output_path_input = dlg:add_text_input(path, 1, 4, 3)

    dlg:add_label("Filename (leave empty to randomly generate):", 1, 5)
    output_filename_input = dlg:add_text_input('', 1, 6, 3)

    -- right side

    separator_string = '|<br/>'
    for var=0,17 do
        separator_string = separator_string .. '|<br/>'
    end

    dlg:add_label("<div style='color:#000; line-height:80%;'>" .. separator_string .. "</div>", 4, 1, 1, 8)

    dlg:add_label("<b>Advanced settings:</b>", 6, 1)

    dlg:add_label("Command to execute:", 5, 2, 2)
    dlg:add_button("Restore to default", restore_default_command, 7, 2)
    command_input = dlg:add_text_input(template, 5, 3, 2)
    dlg:add_button("Save settings", save_settings, 7, 3)

    dlg:add_label("FPS", 5, 4, 1)
    fps_input = dlg:add_text_input(tostring(saved_fps), 5, 5, 1)

    dlg:add_label("Looping", 6, 4, 1)
    looping_input = dlg:add_dropdown(6, 5, 1)
    -- The first value added is selected, so respect the saved setting.
    if saved_looping == -1 then
        looping_input:add_value("Only play once", -1)
        looping_input:add_value("Loop GIF", 0)
    else
        looping_input:add_value("Loop GIF", 0)
        looping_input:add_value("Only play once", -1)
    end

    -- middle
    dlg:add_button("Generate GIF", generate_gif, 3, 9, 3, 2)
end

function fill_start_timestamp()
    start_timestamp_input:set_text(get_timestamp())
end

function fill_stop_timestamp()
    stop_timestamp_input:set_text(get_timestamp())
end

-- Replace every {placeholder} in one pass, so the result does not depend on
-- table iteration order and values containing pattern characters are safe.
function generate_command(template, values)
    local result = template:gsub("{([%w_]+)}", function(name)
        local value = values[name]
        if value == nil then
            vlc.msg.warn("GIF Maker: unknown placeholder {" .. name .. "}")
            return "{" .. name .. "}"
        end
        return tostring(value)
    end)

    if vlc.win then
        result = result:gsub("/", "\\")
    end
    return result
end

-- Widget access is guarded: deactivate() may run while VLC is tearing the
-- dialog down, where a stale widget would otherwise raise a Lua error.
function widget_text(widget)
    if widget == nil then return nil end
    local ok, text = pcall(function() return widget:get_text() end)
    if ok then return text end
    return nil
end

function widget_value(widget)
    if widget == nil then return nil end
    local ok, value = pcall(function() return widget:get_value() end)
    if ok then return value end
    return nil
end

function save_current_settings()
    local text = widget_text(command_input)
    if text then
        save_config('command', text)
    end
    text = widget_text(output_path_input)
    if text then
        save_config('output_path', text)
    end
    text = widget_text(fps_input)
    if text then
        save_config('fps', text)
    end
    local loop = widget_value(looping_input)
    if loop ~= nil then
        save_config('looping', tostring(loop))
    end
end

function save_settings()
    save_current_settings()
    vlc.osd.message("Settings saved.", 1, "top", 2000000)
end

function restore_default_command()
    command_input:set_text(default_command)
    save_config('command', default_command)
    vlc.osd.message("Command restored to default.", 1, "top", 2000000)
end

function generate_gif()
    local item = vlc.input.item()
    if item == nil then
        fail("No media is playing.")
        return
    end

    local start_text = trim(start_timestamp_input:get_text())
    local stop_text = trim(stop_timestamp_input:get_text())

    if start_text == "" then
        start_text = "0"
    end
    if stop_text == "" then
        stop_text = get_timestamp()
    end

    local start_timestamp, start_seconds = parse_timestamp(start_text)
    if start_timestamp == nil then
        fail("Invalid start time: " .. tostring(start_seconds))
        return
    end

    local stop_timestamp, stop_seconds = parse_timestamp(stop_text)
    if stop_timestamp == nil then
        fail("Invalid end time: " .. tostring(stop_seconds))
        return
    end

    if stop_seconds <= start_seconds then
        fail("End time must be after start time.")
        return
    end

    local template = command_input:get_text()
    local current_fps = trim(fps_input:get_text())
    if current_fps == "" then
        current_fps = default_fps
    end

    local uri = item:uri()
    local media_path
    if vlc.win then
        media_path = uri:gsub("^file:///", "")
    else
        media_path = uri:gsub("^file://", "")
    end
    media_path = url_decode(media_path)

    local current_output_path = trim(output_path_input:get_text())
    if current_output_path == "" then
        fail("Set an output path first.")
        return
    end

    local output_filename = sanitize_filename(output_filename_input:get_text())
    local output_file = output_file_for(current_output_path, output_filename)
    local loop_value = looping_input:get_value()

    save_current_settings()

    local values = {
        start_timestamp = start_timestamp,
        stop_timestamp = stop_timestamp,
        input_file = media_path,
        output_path = strip_trailing_separators(current_output_path),
        output_filename = output_filename,
        fps = current_fps,
        loop = loop_value,
        looping = loop_value,
    }

    local generated = generate_command(template, values)
    vlc.msg.info("GIF Maker command: " .. generated)

    local ok, how, code = os.execute(generated)
    if not execute_succeeded(ok) then
        save_config('last_command', generated)
        fail("GIF creation failed (exit " .. tostring(code) .. "). Details: " .. config_path("last_command"))
        return
    end

    -- Only verify the file when the command actually writes to the expected
    -- location; custom commands may produce a different output file.
    if generated:find(output_file, 1, true) then
        local file = io.open(output_file, "rb")
        if file == nil then
            save_config('last_command', generated)
            fail("ffmpeg finished but " .. output_file .. " was not created. Details: " .. config_path("last_command"))
            return
        end
        file:close()
    end

    vlc.osd.message("GIF created! Saved to " .. output_file, 1, "top", 3000000)
end

function check_ffmpeg_status()
    local status = os.execute("ffmpeg -version")
    if execute_succeeded(status) then
        startExtension()
    else
        gui_create_ffmpeg_warning()
    end
end

function startExtension()
    if ffmpegDlg then
        ffmpegDlg:delete()
        ffmpegDlg = nil
    end
    gui_create_main_dialog(command, output_path, fps, looping)
end

-- functions below are called by VLC

function descriptor()
    return {
        title = "VLC GIF maker";
        version = "0.0.7";
        author = "Piotr Zdolski";
        url = "https://github.com/Dante383/VLC_GIF_Maker";
        description = [[
This extension allows you to quickly make GIFs.
]];
        capabilities = {"menu"};
    }
end


function activate()
    local loaded = load_config('command', default_command)
    local migrated = migrate_command(loaded)
    if migrated ~= loaded then
        save_config('command', migrated)
    end
    command = migrated
    output_path = load_config('output_path', vlc.config.homedir())
    fps = load_config('fps', default_fps)
    looping = tonumber(load_config('looping', tostring(default_looping))) or default_looping

    -- is ffmpeg even used in the current command?
    if string.find(command, "ffmpeg") then
        check_ffmpeg_status()
    else
        startExtension()
    end
end


function deactivate()
    save_current_settings()
end


function close()
    save_current_settings()

    if dlg then
        dlg:delete()
        dlg = nil
    end
    start_timestamp_input = nil
    stop_timestamp_input = nil
    output_path_input = nil
    output_filename_input = nil
    command_input = nil
    fps_input = nil
    looping_input = nil

    if ffmpegDlg then
        ffmpegDlg:delete()
        ffmpegDlg = nil
    end
end

function menu()
    return {"GIF maker","Settings"}
end
