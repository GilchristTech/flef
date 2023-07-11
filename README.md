# `flef`: Fleeting Folders, a Single-Day Project Utility

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`flef` is a small convenience utility for creating and/or
navigating to single-day project directories without needing
to type dates in their names.  Invoking `flef` ensures the
existence of a project directory, named with the current
date and starts a shell there; creating a clean
environment, and helping facilitate a habit of daily coding.

The most common usage is running `flef` without arguments:
```bash
$ flef
Starting a new shell
/home/user/flef/23-07-11
```

This either creates or finds the most recent project
directory for today, then and starts a new shell there. The
tool is written with brevity in mind, to make it easy to
create new terminals and get them to where they need to be.

## Motivation

As a developer, I often find myself needing a temporary
space to experiment, memorize concepts, or debug code by
creating a fresh project. To promote speed and recollection,
I try to keep these projects constrained to a single day of
development, calling them "mini-projects".

However, managing project directories manually became
cumbersome and wreaked havoc on my cluttered home directory.
I started placing these mini-projects inside
`~/$HOME/mini/%y%m-%d_$NAME`, but found manually typing in
that string format tedious.

Initially written under the name `mini`, I wrote `flef` to
save a few keystrokes I do each day, and it also keeps my
organization consistent. The original name inspired the
configuration options; on my own system I wrote the `.zshrc`
to alias `flef` to `mini`, and have it use the `~/mini/`
directory, and for ease-of-typing reasons I prefer an
unconventional date format.

## Installation

`flef` is a simple bash script with no dependencies, and
can be installed by copying the `flef` file anywhere in your
`PATH`. Here's a way it can be installed locally for one
user. First, if it does not already exist, create
the `~/.local/bin/` directory:

```bash
mkdir -p ~/.local/bin
```

Then ensure that directory is in your `PATH`, allowing files inside it to be
found as shell commands by ensuring this line exists within your `.bashrc` file:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then, to install, clone the `flef` repository into the directory of your choice
(in this example, I use `~/.flef/`, and symlink it into your local `bin/`:
```bash
git clone https://github.com/GilchristTech/flef.git ~/.flef
ln -s ~/.flef/flef ~/.local/bin/flef
```

## Usage

```bash
$ flef [project_name|last|help]
```

### `flef`: Default behavior with no arguments

```bash
$ flef
Starting a new shell
/home/user/flef/23-07-11
```

This will search for the most recently modified project
directory with the current date and create a shell inside
it. If no existing project is found, a new project directory
will be created with just the date as a name.  When you exit
the shell, you will return to your previous directory.

### `flef [project_name]`: Use a directory name with a string appended

```bash
$ flef my-project
Starting a new shell
/home/user/flef/23-07-11_my-project
```

If `project_name` is provided, `flef` will create a project
directory with the name `$DATE_$PROJECT_NAME`. If a project
with the same name and date already exists, it just uses
that one. After this, for today, invoking `flef` without
arguments will use that directory.

### `flef last`: Go to the last project

If you want to access the last modified project directory
(regardless of the date), you can use the `last` argument:

```bash
$ flef last
Starting a new shell
/home/user/flef/20-12-03
```

## Environment Variable Configuration

You can customize the behavior of `flef` by setting the
following environment variables:

-   `FLEFDIR`:
    The base directory where `flef` will store project
    directories. By default, it is set to `~/flef`. If this
    directory does not exist, `flef` will create it
    automatically. You can customize the base directory by
    setting the `FLEFDIR` environment variable:
    
    ```bash
    export FLEFDIR="/path/to/custom/directory"
    ```

-   `FLEFDATEFORMAT`:
    The date format to be used for the project directories. By
    default, it is set to `%y-%m-%d`, which represents the year,
    month, and day in a two-digit format. You can customize the
    date format by setting the `FLEFDATEFORMAT` environment
    variable to any valid format recognized by the `date`
    command. For example:
    
    ```bash
    export FLEFDATEFORMAT="%Y-%m-%d"
    ```
    
    This would use the year, month, and day in a four-digit format.

## Python Virtual Environments

`flef` automatically detects Python virtual environment
directories within your project. If a virtual environment is
found (`venv` or `env` directory in the project), it will be
activated within the shell session.

## Acknowledgements

`flef` was created by Gilchrist Pitts. If you have any
suggestions, bug reports, or feature requests, please feel
free to contact me.
