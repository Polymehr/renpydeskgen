# Ren'Py Desktop File Generator
A SH script to generate `.desktop` files for the
[Ren'Py visual novel engine](https://www.renpy.org/)
([GitHub](https://github.com/renpy/renpy)).

## Key Features
* Generate desktop files for your Ren'Py games
* Install the generated files or create them in the current directory
* Create a desktop file that searches for the most recent version for you
  (by default, when all versions are installed to the same directory)
* Rudimentary GUI and desktop file for drag and drop support (needs `zenity`)
* Searches for icons automatically if none were given (and ability to download
  ones)
* Handles all that pesky (believe me) icon stuff for you while adhering to the
  specification (needs *ImageMagick*)
* Install for your user or system wide
* The game directory can be determined from many sources

## Usage
To use the script clone this repository or download the latest release as a zip
archive. In case you downloaded a zip you may have to make the files
`renpy_desktop_generator.sh`, `renpy_desktop_generator.desktop` and
`make_absolute.sh` executable (e.g. with
`chmod +x renpy_desktop_generator.sh`).

After that you can execute the file `renpy_desktop_generator.sh` from your file
manager or the console.

If the script does not have permission to edit a file, it will try to acquire
them using `sudo`.

### Console Usage
You can provide the script with a direct path to the game start script (usually
called *NAME*.sh), a path to your Ren'Py game's directory (as well as
subdirectories), or an icon file.

The script will search for the game directory from these sources (in that
order). If no argument is given, the current directory will be used.

### Desktop File Usage
Due to the wonders of modern technology you can also drag and drop the game
start script (usually called *NAME*.sh), the game directory or the game's icon
file on the desktop file. When you drop multiple files onto the desktop file,
the best matching location will be chosen.

The desktop file expects `renpy_desktop_generator.sh` to be in the same
directory before `make_absolute.sh` has been run.
The specification demands that the paths to scripts that should be executed are
absolute. Because of this file managers might refuse to execute it or assume
incorrect current working directory.
If the desktop file does not work, try running `make_absolute.sh`. After making
the paths absolute, `renpy_desktop_generator.sh` should not be moved to a
different location.
You may also want to install the desktop file to have access to its actions.
See `desktop-file-install`.

Please note that this feature may is not supported by all file managers.
Somtimes, activating running executable files will help. I made some tests
and got the following results:
Name                      | Desktop Environment   | Status
--------------------------|-----------------------|------------------------------------------
`caja`                    | MATE (Mint)           | :heavy_check_mark: Works
`deepin-file-manger`      | Deepin                | :heavy_check_mark: Works
`dolphin`                 | KDE                   | :heavy_minus_sign: Works (only full path)
`liri-files`              | Liri                  | :x: Does not work.
 GNOME Files (`nautilus`) | GNOME (Ubuntu)        | :x: Does not work. (Maybe that's a bug?)
`nemo` (`nautilus` fork)  | Cinnamon (Mint)       | :heavy_check_mark: Works
`thunar`                  | Xfce (Mint)           | :heavy_check_mark: Works
`xfe`                     |                       | :x: Does not work.

## Dependencies
This script was written with GNU/BSD tools in mind. It will most likely not
work in other environments. If you find a way to make it work, please contact
me.

### Mandatory Dependencies
All of these should already be installed on a normal system.
```
/bin/sh basename cat cd command cp cut dirname eval exit file find grep head ln
id mkdir mkfifo mv printf read readlink return rm sed set shift sudo sort test
tr unset
```

### Highly Recommended Dependencies
* :warning: If you want to use the script without a terminal (e.g. running
  it from the file manager or desktop file), the GUI tool `zenity` should be
  installed on your system. Otherwise, the script will silently log to the
  system log and choose some defaults that you may not want.
* For the correct handling of icons the *ImageMagick* suite **must be
  installed**. If the icon is not in `.png` format, some launchers might not
  support it.<br>
  If you have an Apple Icon Image format file, `icns2png` **must be
  installed**.<br>
  At least one of these two programs should be installed.

### Optional Dependencies
These are not required but add more features to the script:
Name                      | Purpose
--------------------------|-----------------------------------------------------------------
`base64`                  | Used in current version search script (to escape escaping hell).
`wget`                    | Download fallback icon.
`desktop-file-install`    | Check and install the generated desktop file.
`env`                     | Used in current version search script.
`icns2png`                | Handle the Apple Icon Image format correctly.
`logger`                  | Log to the system log.
`magick`                  | Ensure correct image format. (*ImageMagick*)
`mktemp`                  | Ensure no naming conflicts for temporary files.
`uniq`                    | Used in current version search script.
`update-desktop-database` | Check the installed generated desktop file and make it findable.
`xargs`                   | Used in current version search script.
`zenity`                  | Create a rudimentary GUI.
`$PAGER`/`less`           | Pager to display the help.

## Examples
Show all the options you have (can also be triggered via the appropriate
Desktop file action) with `-h` (`--help`)
```sh
./renpy_desktop_generator.sh -h
```

Force the use of the GUI with `-g` (`--gui`)
```sh
./renpy_desktop_generator.sh ../../path/to/your/vn -g
```

Install without any prompts with version search support with `-i` (`--install`)
and `-v` (`--current-version-search`)
```sh
./renpy_desktop_generator.sh ../../path/to/your/vn -iv
```

If the script cannot determine the name of the game correctly or the name is
not descriptive, you can use the `-N` (`--display-name`) option
```sh
./renpy_desktop_generator.sh vn/YVN.sh -N "Your Visual Novel"
```

This script was originally only to generate desktop files for the visual
[PASSWORD](https://passwordvn.itch.io/password) by Grizz. If you want to
recreate the original behaviour, you could do the following (`-V`,
`--no-current-version-search`)
```sh
cd ./path/to/your/password/installation
./path/to/renpy_desktop_generator.sh -V
```

Make the script talk a lot (verbosity: ‘debug’). This is good if you want to
see the changes to your file system and what will be executed with `sudo` with
`-l` and `-L` (`--log-level`; `--gui-log-level`)
```sh
./renpy_desktop_generator.sh ../../path/to/your/vn -l 4 -L 4
```

## Older Versions and Credits
This script is based on a script by 🐲Shin from the
[PASSWORD Discord server](https://discord.gg/CSuEPWt). This version can be
found [here](https://discordapp.com/channels/569701885032792064/569755878043942913/735801398242836500).

Other versions can be found in the commit history.

## Used Specifications
* [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html) 1.5
* [Icon Theme Specification](https://specifications.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html) 0.13
* [Desktop Menu Specification](https://specifications.freedesktop.org/menu-spec/menu-spec-latest.html) 1.1
* [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) 0.7
