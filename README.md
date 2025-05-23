# `flef`: Fleeting Folders, a Single-Day Project Utility

<div align="center">
    <img align="center" src="logo.svg">
    
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
    
</div>

`flef` is a small convenience utility for creating and
navigating to single-day project directories without needing
to type dates in their names. Invoking `flef` ensures the
existence of a project directory, named with the current
date, and starts a shell there; creating a clean
environment and helping facilitate a habit of daily coding.

The most common usage is running `flef` without arguments:
```bash
$ flef
Starting a new shell
/home/user/flef/23-07-11
```

This either creates or finds the most recent project
directory for today, then and starts a new shell there. The
tool is written with brevity in mind, making it fast to
create new terminals and navigate them where they need to
be.

## Motivation

As a developer, I often find myself needing a temporary
space to experiment, memorize concepts, or debug code by
creating a fresh directory with a tiny project. To promote
speed and recollection, I try to keep these projects
constrained to a single day of development, calling them
"mini-projects".

At first, manually creating project directories directory
wreaked havoc on my cluttered home directory.  Organizing
them in a specific directory structure,
`~/$HOME/mini/%y%m-%d_$NAME`, with a new major directory for
these projects and with the date in their names, a new
problem emerged: the problem of minor inconvenience. Instead
of spending seconds typing directory names, I typed up a
small shell utility.

Initially written under the name `mini`, I wrote `flef` to
save a few keystrokes I do each day, and it also keeps my
organization consistent. The original name inspired the
configuration options; on my own system I wrote the `.zshrc`
to alias `flef` to `mini`, and have it use the `~/mini/`
directory, and for ease-of-typing reasons I prefer an
unconventional date format.

## Installation

`flef` is a simple bash script with (almost&ast;) no
dependencies, and as an opinionated shell tool oriented
around the home directory, it is recommended to install for
a single user without root privileges.  After cloning the
repo, it can be installed by copying the `flef.sh` file
anywhere in your `PATH`, creating a link to that file, or by
creating an alias to the `flef.sh` script. For convenience,
there is an interactive `install.sh` script, which attempts
to automate a setup.

To clone the repo and run the installer, one can run the following:
```bash
git clone https://github.com/GilchristTech/flef.git ~/.flef
cd ~/.flef/
./install.sh
```

\* The sync features are written in Perl, and also uses SSH
and `rsync`. These are all dependencies if the sync features
are used. Perl was chosen because it comes installed on the
vast majority of \*nix systems, and is unlikely to require any
additional setup, allowing the sync functionality to install
`flef` for a user on another machine over SSH without
touching a package manager.

### Alias-source installation

By default, `flef` creates a new shell inside the project
directory, but it can also be configured to be ran such that
`flef`'s code is sourced directory into current shell, and
the directory is changed in the current shell instead of
creating a new shell session.

To do this, first ensure `flef` is *not* found inside a
`$PATH` directory. Then, add the following command to your
`.bashrc`:
```bash
alias flef="FLEF_USE_SOURCE=1 source /path/to/flef/installation/directory/flef.sh"
```
This will cause `flef` to get ran as an alias, and when ran
prevents it from creating a new shell.

## Usage

```bash
$ flef [project_name|last [n]|rm|link [name [directory]]|help]
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

### `flef last [n]`: Go to the Nth last project

If you want to access the last modified project directory
(regardless of the date), you can use the `last` argument:

```bash
$ flef last
Starting a new shell
/home/user/flef/20-12-03
```

In order to go back even further, you can specify a number,
N, to go back to the Nth most recent directory. For example,
to go the fifth most recent project:
```bash
$ flef last 5
```

### `flef rm`: Delete the current project directory

When the current working directory is either a `flef`
project directory or a subdirectory thereof, the project
directory can be deleted with the delete command:
```bash
$ flef rm
```
This will delete the project directory. If in alias-source
mode, the shell will switch directories into `$FLEF_DIR`,
otherwise, the working directory will be nonexistent.

### `flef link`: Create a flef project with a symlink to an existing directory

Creates a new `flef` directory from an existing folder,
creating a symbolic link under the `$FLEF_DIR`. If no
arguments are used, the link will point to the current
working directory, and its `basename` will be used. The
first argument after `link` overrides the project name, and
the second overrides the directory linked to.

```bash
$ flef link
$ flef link new-name
$ flef link new-name ./other-directory/
```

## Sync: Transfer projects between machines

To move projects between computers, `flef`'s sync features
can be used. These sync commands make it easy to, for
example, transfer in-progress code to-and-from one's desktop
and laptop computers on a local network. These features are
two subcommands: push and pull, which send a `flef` project
from one computer to another.

Flef's sync features require SSH and rsync on both machines,
and requires the remote machine to .
For composing the host addresses used in the sync commands,
it tends to be easiest to use a zeroconf networking
implementation such as Avahi instead of typing IP addresses
on your local network. Installing and configuring these
technologies may vary among systems, and is beyond the scope
of this README. 

### Sync usage

The examples below use a host called `laptop.local`, which
assumes a host on the local network being defined using
zeroconf. An IP address can also be used.

To send the project in the current working directory to your
laptop at `laptop.local` (if it's a `flef` project), type:

```bash
flef sync push laptop.local
```

And then, if you're in that same directory, you can download
it back with:
```bash
flef sync pull laptop.local
```

By default, the push and pull commands attempt to use `flef`
project in the current directory, or its parents. However,
an additional argument can specify a project name, or a last
Nth project:

```bash
flef sync pull laptop.local last 2
flef sync push laptop.local 2024-04-23_my-project
```

In all the above commands, `rsync` commands with the paths
to the projects are generated.

### Remote installation

When pushing a project to another machine and user, if
`flef` is not installed for that user, it will attempt to
install `flef` for them, using the same settings as the
local system. This is so that `flef` can later be used to
query the project directory, and also so that a developer
can carry on where they left off.


## Environment Variable Configuration

You can customize the behavior of `flef` by setting the
following environment variables:

-   `FLEF_DIR`:
    The base directory where `flef` will store project
    directories. By default, it is set to `~/flef`. If this
    directory does not exist, `flef` will create it
    automatically. You can customize the base directory by
    setting the `FLEF_DIR` environment variable:
    
    ```bash
    export FLEF_DIR="/path/to/custom/directory"
    ```

-   `FLEF_DATEFORMAT`:
    The date format to be used for the project directories. By
    default, it is set to `%y-%m-%d`, which represents the year,
    month, and day in a two-digit format. You can customize the
    date format by setting the `FLEF_DATEFORMAT` environment
    variable to any valid format recognized by the `date`
    command. For example:
    
    ```bash
    export FLEF_DATEFORMAT="%Y-%m-%d"
    ```
    
    This would use the year, month, and day in a four-digit format.

-   `FLEF_USE_SOURCE`:
    Prevents `flef` from spawning a new shell, and instead
    runs everything in the current shell. Meant to be used
    when `flef` ran with the `source` command.

## Python Virtual Environments

`flef` automatically detects Python virtual environment
directories within your project. If a virtual environment is
found (`venv` or `env` directory in the project), it will be
activated within the shell session.

## Acknowledgements

`flef` was created by Gilchrist Pitts. If you have any
suggestions, bug reports, or feature requests, please feel
free to contact me.
