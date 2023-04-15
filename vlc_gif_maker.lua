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
--]]----------------------------------------

default_command = 'ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps={fps},scale=498:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop {loop} "{output_path}/{output_filename}.gif"'
command = false
output_path = false

function esc(x)
    x = tostring(x)
    return (x:gsub('%%', '%')
            :gsub('^%^', '%^')
            :gsub('%$$', '%$')
            :gsub('%(', '%(')
            :gsub('%)', '%)')
            :gsub('%[', '%[')
            :gsub('%]', '%]')
            )
end

function get_timestamp()
    local microseconds = vlc.var.get(vlc.object.input(), "time")
    local seconds_total = math.floor((microseconds/1000)/1000)

    local hours = math.floor((seconds_total % 86400)/3600)
    local minutes = math.floor((seconds_total % 3600)/60)
    local seconds = math.floor((seconds_total % 60))
    local miliseconds = math.floor((microseconds % 1000))

    -- format() seems to not be supported :(
    return hours .. ":" .. minutes .. ":" .. seconds .. "." .. miliseconds
end

-- seperate file for path so there are no issues and weird gimmicks with multi-line commands
-- this is a simple project after all, not nginx 
function load_config(filename)
    local config_path = vlc.config.configdir() .. "/gif_maker_" .. filename

    local config_file, err = io.open(config_path, "r")
    
    if config_file == nil then
        if filename == 'command' then 
            value = default_command
        elseif filename == 'output_path' then 
            value = vlc.config.homedir()
        end
        save_config(filename, value)
        return value
    end 

    value = config_file:read()
    config_file:close()

    if not value or value == "" then
        if filename == 'command' then 
            value = default_command
        elseif filename == 'output_path' then 
            value = vlc.config.homedir()
        end
        save_config(filename, value)
    end

    return value
end

function save_config(filename, value)
    config_path = vlc.config.configdir() .. "/gif_maker_" .. filename

    local file = assert(io.open(config_path, 'w+b'), 'Error while saving the ' .. filename)
    file:write(value)
    file:close()
end

function gui_create_ffmpeg_warning()
    ffmpegDlg = vlc.dialog("GIF Maker")

    -- col, row, col_span, row_span, width, height
    ffmpegDlg:add_label("WARNING: ffmpeg couldn't be found! Make sure it's available globally (PATH for Windows users)", 1, 1)
    ffmpegDlg:add_button("OK", startExtension, 1, 2)
end

function gui_create_main_dialog(command, output_path)
    local input = vlc.object.input()

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
    output_path_input = dlg:add_text_input(output_path, 1, 4, 3)

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
    dlg:add_button("Set to default", set_default_command, 7, 2)
    command_input = dlg:add_text_input(command, 5, 3, 3)

    dlg:add_label("FPS", 5, 4, 1)
    fps_input = dlg:add_text_input("15", 5, 5, 1)

    dlg:add_label("Looping", 6, 4, 1)
    looping_input = dlg:add_dropdown(6, 5, 1)
    looping_input:add_value("Loop GIF", 0)
    looping_input:add_value("Only play once", -1)

   --[[dlg:add_label("Resolution", 7, 4, 1)
    resolution_input = dlg:add_dropdown(7, 5, 1)
    resolution_input:add_value("498px x height", 1) 
    resolution_input:add_value("Don't scale (input video resolution)", 2)
    resolution_input:add_value("Set height in pixels:", 3)
    resolution_input:add_value("Set width in pixels:", 4)
    resolution_input:add_value("Set height and width in pixels:", 5)]]

    -- middle 
    dlg:add_button("Generate GIF", generate_gif, 3, 9, 3, 2)
end

function fill_start_timestamp()
    start_timestamp_input:set_text(get_timestamp())
end

function fill_stop_timestamp()
    stop_timestamp_input:set_text(get_timestamp())
end

function generateCommand(command, generalOptions, commandBuilder)
    for optionName,optionValue in pairs(generalOptions) do 
        if vlc.win and string.sub(optionValue, 1,1) == '/' then optionValue = string.sub(optionValue, 2, -1) end
        if vlc.win then optionValue = string.gsub(optionValue, '//', '\\') end
        command = string.gsub(command, optionName, esc(optionValue))
    end

    if commandBuilder then 
        return generateCommand(command, commandBuilder)
    end
    
    command = string.gsub(command, '\\', '\\')
    vlc.msg.info(command)
    return command
end

function generate_gif()
    local start_timestamp = start_timestamp_input:get_text()
    local stop_timestamp = stop_timestamp_input:get_text()
    local command = command_input:get_text()
    local fps = fps_input:get_text()

    local item = vlc.input.item()
    local uri = item:uri()
    local media_path = string.gsub(uri, '^file://', '') 

    local output_path = output_path_input:get_text()
    local output_filename = output_filename_input:get_text()

    if output_filename == '' then
        output_filename = 'g' .. os.time()
    else
        output_filename = output_filename:match('([^.]+)') -- remove extension
    end
    
    save_config('command', command)
    save_config('output_path', output_path)

    local generalOptions = {}
    generalOptions['{start_timestamp}'] = start_timestamp
    generalOptions['{stop_timestamp}'] = stop_timestamp
    generalOptions['{input_file}'] = media_path
    generalOptions['{output_path}'] = output_path
    generalOptions['{output_filename}'] = output_filename

    local commandBuilder = {}
    commandBuilder['{fps}'] = fps
    commandBuilder['{loop}'] = looping_input:get_value()

    command = generateCommand(command, generalOptions, commandBuilder)
    
    os.execute(command)
    vlc.osd.message("GIF created! Saved to " .. output_path .. "/" .. output_filename, 1, "top", 3000000) -- why, tf, is vlc's osd msg duration in MICROseconds??
end

function set_default_command()
    command_input:set_text(default_command)
    save_config('command', default_command)
end

function check_ffmpeg_status()
    status_code = os.execute("ffmpeg -version")
    if status_code then
        startExtension(command, output_path)
    else 
        gui_create_ffmpeg_warning()
    end
end

function startExtension()
    if ffmpegDlg then 
        ffmpegDlg:delete()
        ffmpegDlg = nil 
        startExtension()
    end
    gui_create_main_dialog(command, output_path)
end

-- functions below are called by VLC

function descriptor()
    return {
        title = "VLC GIF maker";
        version = "0.0.3";
        author = "Piotr Zdolski";
        url = "https://github.com/Dante383/VLC_GIF_Maker";
        description = [[
This extension allows you to quickly make GIFs.
]];
        capabilities = {"menu"};
    }
end


function activate()
    command = load_config('command')
    output_path = load_config('output_path')

    -- is ffmpeg even used in the current command?
    if string.find(command, "ffmpeg") then
        check_ffmpeg_status()
    else 
        startExtension()
    end
end


function deactivate()
    save_config('command', command)
end


function close()
    if dlg then
        dlg:delete()
        dlg = nil
    end
    if ffmpegDlg then 
        ffmpegDlg:delete()
        ffmpegDlg = nil 
        startExtension()
    end
end

function menu()
    return {"GIF maker","Settings"}
end
