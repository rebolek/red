# Values: Red IDE - editor component

## Installation

Editor is availbale in my Red fork, in the `editor` branch ([link](https://github.com/rebolek/red/tree/editor)).

### OSX

Checkout this branch and compile console.

### Windows

This branch cannot be compiled under Windows currently because it merged `MacOSX-GUI` branch, so you need to:

* Checkout qtxie’s [Red console branch](https://github.com/qtxie/red/tree/red-console).
* Compile console.
* Checkout this branch.

## Running

* Open Red's console and run View console with
```
do %environment/red-console/red-console.red
```
* press `Escape` to enter editor.

## Usage

There are two editor modes: `insert` and `command`. Editor starts in `insert` mode. To enter command mode, press `Escape`. To go back to editor mode from command mode, press `a` for append or `i` for insert (see below).

### Keyboard bindings

#### insert mode

* `cursor keys` - movement
* `shift` + `cursor keys` - selection
* `escape` - switch to `command` mode

#### command mode

* `cursor keys` and `h`, `j`, `k`, `l` - movement
* `shift` + `cursor keys` and `H`, `J`, `K`, `L` - selection
* `b` - select to value start
* `e` - select to value end
* `v` - select current value
* `y` - cut selection
* `i` - switch to editor mode and set cursor before current selection
* `a` - switch to editor mode and set cursor after current selection
* `q` - switch to console
* `f` - find selection
* `r` - reduce and replace selection
* `s` - pastes source of one function into buffer (*debug*)
* `d` - print debug information into (*debug*)