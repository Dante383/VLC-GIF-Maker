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

default_command = 'ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=15,scale=498:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "{output_path}/{output_filename}.gif"'

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

function load_command()
    local config_path = vlc.config.configdir() .. "/gif_maker_command"

    local command_file, err = io.open(config_path, "r")
    
    if command_file == nil then 
        command = default_command
        save_command(command)
    end 

    command = command_file:read()
    command_file:close()

    if not command or command == "" then
        command = default_command
        save_command(command)
    end

    return command
end


function save_command (command)
    config_path = vlc.config.configdir() .. "/gif_maker_command"

    local file = assert(io.open(config_path, 'w+b'), 'Error while saving the command')
    file:write(command)
    file:close()
end

-- seperate file for path so there are no issues and weird gimmicks with multi-line commands
-- this is a simple project after all, not nginx 
function load_output_path ()
    local config_path = vlc.config.configdir() .. "/gif_maker_output_path"

    local path_file, err = io.open(config_path, "r")
    
    if path_file == nil then 
        output_path = vlc.config.homedir()
        save_output_path(vlc.config.homedir())
    end 

    output_path = path_file:read()
    path_file:close()

    if not output_path or output_path == "" then
        output_path = vlc.config.homedir()
        save_output_path(output_path)
    end

    return output_path
end

function save_output_path (output_path)
    config_path = vlc.config.configdir() .. "/gif_maker_output_path"

    local file = assert(io.open(config_path, 'w+b'), 'Error while saving output path')
    file:write(output_path)
    file:close()
end

function create_window()
    local input = vlc.object.input()
    command = load_command()
    output_path = load_output_path()

    dlg = vlc.dialog("GIF Maker")

    -- col, row, col_span, row_span, width, height
    dlg:add_label("Start time: ", 1, 1)
    start_timestamp_input = dlg:add_text_input("", 2, 1)
    dlg:add_button("Get", fill_start_timestamp, 3, 1)

    dlg:add_label("End time: ", 1, 2)
    stop_timestamp_input = dlg:add_text_input("", 2, 2)
    dlg:add_button("Get", fill_stop_timestamp, 3, 2)

    dlg:add_label("Command to execute (for advanced users):", 1, 3)
    dlg:add_button("Set to default", set_default_command, 3, 3)
    command_input = dlg:add_text_input(command, 1, 4, 4)

    dlg:add_label("GIFs output path:", 1, 5)
    output_path_input = dlg:add_text_input(output_path, 1, 6, 4)

    dlg:add_label("Filename (leave empty to randomly generate):", 1, 7)
    output_filename_input = dlg:add_text_input('', 1, 8, 4)

    dlg:add_button("Generate GIF", generate_gif, 1, 9, 4)
end

function fill_start_timestamp()
    start_timestamp_input:set_text(get_timestamp())
end

function fill_stop_timestamp()
    stop_timestamp_input:set_text(get_timestamp())
end

function generate_gif()
    local start_timestamp = start_timestamp_input:get_text()
    local stop_timestamp = stop_timestamp_input:get_text()
    local command = command_input:get_text()

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
    
    save_command(command)
    save_output_path(output_path)

    command = string.gsub(command, '{start_timestamp}', start_timestamp)
    command = string.gsub(command, '{stop_timestamp}', stop_timestamp)
    command = string.gsub(command, '{input_file}', media_path)
    command = string.gsub(command, '{output_path}', output_path)
    command = string.gsub(command, '{output_filename}', output_filename)
    
    os.execute(command)
    vlc.osd.message("GIF created! Saved to " .. output_path .. "/" .. output_filename, 1, "top", 3000000) -- why, tf, is vlc's osd msg duration in MICROseconds??
end

function set_default_command()
    command_input:set_text(default_command)
    save_command(default_command)
end

-- functions below are called by VLC

function descriptor()
    return {
        title = "VLC GIF maker";
        version = "0.1";
        author = "Piotr Zdolski";
        url = "https://github.com/Dante383/VLC_GIF_Maker";
        description = [[
This extension allows you to quickly make GIFs.
]];
        capabilities = {"menu"};
    }
end


function activate()
    create_window()
end


function deactivate()
    save_command(command)
end


function close()
    if dlg then
        dlg:delete()
        dlg = nil
    end
end

function menu()
    return {"GIF maker","Settings"}
end
