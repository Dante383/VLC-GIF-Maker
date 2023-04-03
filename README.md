# VLC-GIF-Maker
Extension to the VLC player which allows you to easily generate GIFs from watched content

## Installation 

**WARNGING: THIS EXTENSION REQUIRES FFMPEG TO BE INSTALLED (and put in PATH for Windows)**

Put "vlc_gif_maker.lua" file in directory suitable for your operating system:

* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
* Windows (current user): %APPDATA%\VLC\lua\extensions\
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/

## Usage 

![GUI](https://i.imgur.com/Q2fZT07.png)

In VLC, click "View" and select "VLC GIF Creator". GIF creator window will open.

Adjust output path and filename as needed. **Do not put a slash at the end of the output path!**

Now, you can either input start and end timestamps by hand, or you can simply navigate the player 
and click "Get" by the inputs. The timestamps will be set automatically. 

Press "Generate GIF" and it's gonna be saved to the path you specified, followed by a confirmation on the VLC screen. 

## Adjusting framerate, resolution and looping

This is how the command looks by default, important bits are bold:

ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "**fps=15**,**scale=498:-1**:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" **-loop 0** {output_path}/{output_filename}

<details>
<summary>Framerate</summary>
Default framerate is 15. You can change 15 to any number you wish, this is how the command would look like with framerate 30:

    ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=30,scale=498:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 {output_path}/{output_filename}

See https://ffmpeg.org/ffmpeg-filters.html#fps for more information
</details>
<details>
<summary>Resolution</summary>
    
In short, scale = resolution, width:height in pixels to be exact. 

If you put -1 instead of one of the values (like in the default command), it will be scaled without losing proportions.
For example, input video has 2000x1000 resolution. You put scale=500:-1 in the command, and the GIF will have 500x250 resolution. 
Same with the other way - scale=-1:500 and the GIF will have 1000x500 resolution.

This is how the command would look like with 600px height (and scaled width):

    ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=15,scale=-1:600:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 {output_path}/{output_filename}

This is how the command would look like with forced 1920x1080px resolution (probably a bad idea, just set the width or height, not both)

    ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=15,scale=1920:1080:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 {output_path}/{output_filename}

You can leave it empty and the GIF will be generated with the maximum resolution (so input video's). This is however probably a very bad idea. 6 second GIF from a 1080p source material would weight around 70MB.

This is how the command would look like with source material's resolution:

    ffmpeg -ss {start_timestamp} -to {stop_timestamp} -i {input_file} -vf "fps=15,scale=flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 {output_path}/{output_filename}  
 
See https://ffmpeg.org/ffmpeg-filters.html#scale for more information 
</details>
<details>
<summary>Looping</summary>

Default value of **0** means the GIF will loop indefinitely. **-1** would mean no looping, and **1** would mean one loop, so the GIF will play twice. **22** would mean the GIF will play 23 times.

See https://ffmpeg.org/ffmpeg.html#Main-options for more information.
</details>
<details>
<summary>Other uses</summary>

You might notice that this extension simply executes a command with filled parameters. You can of course change it, here is an example command which will just export the selected timeframe to mp4 instead of turning it into a GIF.

    ffmpeg -i {input_file} -ss {start_timestamp} -to {stop_timestamp} -c:v copy -c:a copy {output_path}/{output_filename}.mp4
</details>
