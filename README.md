# MacBook-Music-Button

`mediactl` is a small macOS command line utility for controlling media playback on a MacBook.

It can:

- play music
- pause music
- toggle play and pause
- return current playback info

This tool is useful for building custom AI assistants that automate laptop actions, for example voice controlled assistants that can pause or resume music without opening a media app manually.

## Requirements

- macOS
- Xcode Command Line Tools
- Apple Silicon or Intel Mac with `clang++`

## Build

```bash
clang++ -fobjc-arc -framework Foundation -framework AppKit mediactl.mm -o mediactl
```

## Usage

```bash
./mediactl play
./mediactl pause
./mediactl toggle
./mediactl info
```
## Commands
	•	play — start or resume playback
	•	pause — pause playback
	•	toggle — switch between play and pause
	•	info — return playback status as JSON

## Example Output
```json
{"ok":true,"playing":true,"title":"Track name","artist":"Artist name"}
```

## Use Case
This utility can be integrated into local automation tools, AI agents, voice assistants, or Node.js applications.
For example, it can be called from a custom assistant that listens for commands like:
	•	pause the music
	•	resume playback
	•	what is playing now
