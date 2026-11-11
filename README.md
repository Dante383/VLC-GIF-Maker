# VLC-GIF-Maker
Extension to the VLC player which allows you to easily generate GIFs from watched content

## Installation 

**WARNING: THIS EXTENSION REQUIRES FFMPEG TO BE INSTALLED (and put in PATH for Windows)**

Put "vlc_gif_maker.lua" file in directory suitable for your operating system:

* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
* Windows (current user): %APPDATA%\VLC\lua\extensions\
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/

### Linux (Debian/Ubuntu)

A small installer is included for Debian-based distributions. It copies
`vlc_gif_maker.lua` into the right VLC extensions directory and offers to
install VLC and ffmpeg when they are missing.

```bash
./install.sh            # prompts: 1) current user  2) all users
./install.sh -user      # current user
./install.sh -system    # all users (requires sudo)
```

The installer detects Debian's multiarch VLC directory, so no manual path
editing is needed.

## Usage 

![GUI](https://i.imgur.com/Q2fZT07.png)

In VLC, click "View" and select "VLC GIF Creator". GIF creator window will open.

Adjust output path and filename as needed. A trailing slash on the output path is
fine (it is removed automatically, so no `//` appears in the path). If the
filename does not already end in `.gif`, the extension is appended; `.gif` is
never added twice.

Now, you can either input start and end timestamps by hand, or you can simply navigate the player 
and click "Get" by the inputs. The timestamps will be set automatically. 

Hand-written timestamps accept `SS`, `MM:SS` and `H:MM:SS`/`HH:MM:SS`, with
an optional fractional part (`.` or `,`) - e.g. `12`, `12.5`, `.5`, `1:23`,
`1:23.5`, `1:02:03.456`. Components may exceed 59 and are summed, so `84:22`
means 1:24:22. Leaving the start time empty uses the beginning of the video;
leaving the end time empty uses the current playback position. The parsed
times are normalised before ffmpeg runs.

FPS, looping, the command and the output path are remembered across restarts.
Use "Save settings" to store them immediately, or just generate a GIF / close
the dialog. "Restore to default" resets the command to the bundled default.

The **Resolution** dropdown applies a preset to the `scale=` part of the
command: Original (no scaling), 498 px wide (the default), or 144p/240p/360p/
480p/720p/1080p. Picking a different value rewrites the command when you press
"Generate GIF", so the command field always shows what will run. Presets above
the source resolution upscale, so choose Original to keep the source size.

Press "Generate GIF" and it's gonna be saved to the path you specified, followed by a confirmation on the VLC screen. If ffmpeg fails, the extension tells you
instead of claiming success, and writes the exact command to
`<VLC config dir>/gif_maker_last_command` for troubleshooting.

## Fixes in this fork

This fork (`Ron-RONZZ-org/VLC-GIF-Maker`) keeps the original extension but
fixes a few issues:

- Settings are saved on generate/close/save and no longer overwritten with the
  value loaded when the dialog opened.
- "Set to default" is now "Restore to default", which actually resets the
  command.
- Input paths are URL-decoded (`%20` etc.) and quoted automatically, so media
  paths containing spaces work even from an older hand-edited command.
- Hardcoded `fps=` / `-loop` values in an old command are migrated to
  `{fps}` / `{loop}`, so the FPS and looping controls apply again.
- Start/end timestamps accept `SS`, `MM:SS` and `H:MM:SS` (with optional
  fractional seconds), and out-of-range components are summed instead of
  rejected (`84:22` = 1:24:22).
- A trailing slash on the output path no longer produces `//`.
- `.gif` is added only when the filename does not already have it, and other
  dots in the name are preserved.
- ffmpeg failures are reported instead of showing a false "GIF created"
  message; the command is logged for debugging.
- Input paths are URL-decoded (`%20` etc.).
- A Resolution dropdown (Original, 498 px wide, 144p–1080p) rewrites the
  command's `scale=` filter, so resolution can be changed without editing the
  command by hand.
- A Linux installer (`install.sh`) is included for Debian-based systems.

## Adjusting resolution

This is how the command looks by default, important bits are bold:

ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps={fps},**scale=498:-1**:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop {loop} "{output_path}/{output_filename}.gif"

<details>
<summary>Resolution</summary>
    
In short, scale = resolution, width:height in pixels to be exact. 

If you put -1 instead of one of the values (like in the default command), it will be scaled without losing proportions.
For example, input video has 2000x1000 resolution. You put scale=500:-1 in the command, and the GIF will have 500x250 resolution. 
Same with the other way - scale=-1:500 and the GIF will have 1000x500 resolution.

This is how the command would look like with 600px height (and scaled width):

    ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=15,scale=-1:600:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "{output_path}/{output_filename}.gif"

This is how the command would look like with forced 1920x1080px resolution (probably a bad idea, just set the width or height, not both)

    ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=15,scale=1920:1080:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "{output_path}/{output_filename}.gif"

You can leave it empty and the GIF will be generated with the maximum resolution (so input video's). This is however probably a very bad idea. 6 second GIF from a 1080p source material would weight around 70MB.

This is how the command would look like with source material's resolution:

    ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=15,scale=flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "{output_path}/{output_filename}.gif"
 
See https://ffmpeg.org/ffmpeg-filters.html#scale for more information 
</details>
<details>
<summary>Other uses</summary>

You might notice that this extension simply executes a command with filled parameters. You can of course change it, here is an example command which will just export the selected timeframe to mp4 instead of turning it into a GIF.

    ffmpeg -i {input_file} -ss {start_timestamp} -to {stop_timestamp} -c:v copy -c:a copy {output_path}/{output_filename}.mp4
</details>
