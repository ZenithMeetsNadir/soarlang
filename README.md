# Foreword

I should probably mention that this is a free time project, whose fate is determined by nothing else but my oscillating motivation, hitting its peak every now and then and likely to run dry at any moment.

# Soar

Soar is supposed to be a pseudo coding language directed towards operating with audio files. You can think of it as a simple audio composition environment entirely lacking all of the GUI stuff. So it is up to your fingers and keyboard as opposed to drag-and-dropping chunky audio rectangles. 

Its syntax and use case is vague (I have been keeping that in my head) and so is its future at this point.

## Compilation process

The compilation process takes multiple steps. First, high level language code is fed to compiler (yet to be developed) that translates it to primitive assembly-like language. This language (referred to as `Soar IR`), consisting mainly of imperative instructions, is then a lot easier to interpret.

### Release

As of the latest release, only the interpreter (`1.4.0`) is available. To interpret a soar IR file, use the `melodify` command followed by its absolute path.

For those wanting to poke at it, feel free to build it on your own with Zig, as well as check out branch `develop` for the current state of this project.

## Why?

What are you asking about? 

The purpose or the name? 

Its purpose is pretty clear, let me explain. I am too lazy to learn how to compose music in those fancy GUI domains, so why not design my own? At least I can improve my programming skills, hopefully... 

You would like to inquire about the name, then. Put simply, I like the word 'soar'. I intended to use 'ascend' to relate to music a bit more (as in ascending melody), however, I decided 'soar' is better. And I made it stand for "Shenanigan Outlasting Audio Representation". 

Having more lore than factual description is crucial. 

And did I mention I adore dragons?