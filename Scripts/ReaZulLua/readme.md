# ReaZulLua: Hands-free arranged live looping for REAPER in 100% Lua, no dependencies, no fuzz

## Project setup

ReaZuLLua assumes the following setup:

1. Your REAPER project contains every song in your set.
1. You have one **region** for each song in your set. The name of the region is the name of the song.
1. You have one track called **Songs** (literally). This is the **container track** that will contain all other tracks that make up the arrangement of your various songs.
1. You have one track for each song. The name of the track must match the name of the region it is for. This will be your **song-master track** and must be one level below the **container track**. It can have any number of sub-tracks or anything else you want to put in there.

### Areas

ReaZulLua uses the concept "areas" to control things. An area is nothing more than an empty MIDI item with a specific name. These are the supported types:

- **Recording**: a recoring area will record Audio/MIDI into it. You must give it a name in the format of `record:[id]`. `id` can be anything you want really. ReaZulLua will then automatically select it and punch it in/out.

- **Looping**: a looping area will be an area where stuff you recorded with a recording area will be looped/replicated. You must give it a name in the format of `loop:[id]` where - you guessed it - the `id` will indicate the recording area where that looping area takes it's source (audio/midi) from. There's nothing you need to do with them really, aside from placing them in the right places where you want to loop stuff you recorded earlier. They don't need to be consecutive.

- **Track selector**: A track selector is simply an empty midi item with the name `select` (literally). This will cause ReaZulLua to select the track it is on at the moment in time it is placed. This comes in handy when you pair it with REAPERs "Automatically arm on selection" feature.

### Workflow

After having set up your project and songs, you will typically do the following:

1. Use any method you like to select the song to play. This means: moving your edit/playback cursor withn it's **region**s bounds. REAPERs region manager comes in handy.
1. Initialize ReaZulLua by the running `looper.lua` script. This will prepare things and start the looper engine. ReaZulLua will also erase all looped and recorded items that come **after** the postition you start at.
1. Start playback within 5secs. Combining the above action and "Transport: Play" into a custom action might make sense.
1. Do yer thang
1. When the end of the song region is reached, playback will automatically stop.

At any time, when playback is stopped (manually or because end-of-region) is reached, ReaZulLua will reset and you need to start it again, as explained above.

### REAPER setup

There are a few settings in REAPER that needs to be tweaked for better results:

1. Enable "Automatically record-arm when selected" on tracks you will record on. This is handy for controlling which inputs are active and monitoring.
1. Audio > Buffering > Disable media buffering for tracks that are selected: This makes sure that tracks that are selected aren't media-buffered. Otherwise a noticeable gap between recording and looping will be heard (applies to audio-looping only)
1. Audio > Recording > Prompt to save/rename/delete files: disable all, this will avoid pesky dialogs (applies to audio-looping only)