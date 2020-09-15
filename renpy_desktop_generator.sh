#!/bin/sh
set -eu
# This script should be `sh` compatible (and is uglier because of that...).
# The usage of the commands on the other hand should restrict usage to GNU/BSD.
# I don't even know whether Ren'Py supports non-GNU/BSD Unixes, but the original
# script used `sh` and shellcheck complained so here you go.
#
# Please Mrs Lovelace, forgive me my ugly coding!
#
# For more info use the ‘--help’ flag.



# Only set variable if it is not already set. Useful if the variable may be
# changed externally (e.g. set outside of the script).
#
# $1: The name of the variable to be maybe set.
# $2: The value to may be set.
set_if_unset() {
    eval 'SIF_TMP="${'"$1"'+.}"'
    [ -z "$SIF_TMP" ] && eval "$1"'="$2"'
    unset SIF_TMP
    return 0 # Never fail
}

# Script options. You may set these manually but they are not always checked, so beware.
################################################################################
set_if_unset CHECK_OPTIONAL_DEPENDENCIES 'true' # If this check is annoying it can be disabled here (and only here).
set_if_unset INSTALL_SYSTEM_WIDE "$([ "$(id -u)" = 0 ] && echo true || echo false)" # Install the desktop file for all users or only the current user
set_if_unset INSTALL_DIR "" # The directory to which the desktop file shall be installed. Will be determined automatically if left empty, otherwise $XDG_DATA_HOME/applications, $XDG_DATA_DIRS/applications are the standard paths
set_if_unset ICON_DIR "" # The directory to which the icons shall be installed. Will be determined automatically if left empty, otherwise "$XDG_DATA_DIRS/icons", "$HOME/.icons" (legacy), "/usr/share/pixmaps" are the standard paths
set_if_unset ICON_DISABLED 'false' # Whether to use an icon at all. If the default is changed ‘--no-no-icon’ may help.
set_if_unset ICON_SIZE_HANDLING 'convert' # Determines how icons are installed if their size is not registered. See ‘--icon-size-not-existing’.
set_if_unset ICON_RESIZE_METHOD 'resize' # The scaling method used when resizing an image. Must be a valid `magick convert` option.
set_if_unset ICON_CREATE_48x48 'true' # Whether to create the default size demanded by the specification
set_if_unset ICON_BROAD_SEARCH 'false' # Search for icons matching '*icon*.*'. May produce undesirable results.
set_if_unset ICON_DOWNLOAD_DEFAULT 'false' # If no icon is found download the default Android one and use that
set_if_unset ICON_DOWNLOAD_DEFAULT_URL 'https://raw.githubusercontent.com/renpy/rapt/master/templates/android-icon_foreground.png' # The URL to the file to use
set_if_unset LOCATION_AGNOSTIC_SEARCH_DIR "" # The directory from which to start searching if script should be version agnostic. Defaults to parent of $RENPY_ROOT_DIR if empty and is relative to it
set_if_unset THEME_ATTRIBUTE_FILE "" # The theme attribute file to use as reference and to edit. Defaults to the first found theme attribute file if empty.
set_if_unset THEME_UPDATE_SCALE_MIN    1 # The default minimum range for icon sizes if no one is given. Must be an integer.
set_if_unset THEME_UPDATE_SCALE_MAX 1024 # The default maximum range for icon sizes if no one is given. Must be an integer.
set_if_unset THEME_UPDATE_THRESHOLD    2 # The default threshold for icon sizes if no one is given. Must be an integer.
set_if_unset GUI '' # Whether to use a GUI (may be ‘true’, ‘false’ or empty). Will be determined automatically if empty.

# These variables control interactive behaviour: if empty they will be asked for
# interactively, otherwise ‘yes’ or ‘no’ are supported. [default if unset]
set_if_unset INSTALL '' # Whether to install the desktop file and icon or save them in the game directory [yes]
set_if_unset UNINSTALL '' # Whether to uninstall the desktop file and icon instead of installing and exit afterwards [no]
set_if_unset UNINSTALL_REMOVE '' # Whether to remove empty icon directories created by uninstalling [yes]
set_if_unset LOCATION_AGNOSTIC '' # Whether to use a script that searches for the newest version script instead of a set path to it [yes]


# These variables are used by the script and can be set
# but that may lead to unexpected behaviour.
set_if_unset DISPLAY_NAME '' # The name of the game used in the desktop file instead of $GAME_NAME when non-empty
set_if_unset GAME_NAME '' # The name of the game used in the desktop file, determined automatically if empty (or $BUILD_NAME)
set_if_unset VENDOR_PREFIX 'renpydeskgen' # The vendor prefix to use for the desktop file and icons to avoid naming conflicts
set_if_unset DESKTOP_FILE '' # The temporary name and location for the desktop file.
set_if_unset START_DIR '' # The directory from which to start the search if no other way could be found
set_if_unset LOG_LEVEL '3' # A numeric level for logging; 0 meaning no logging at all and 4 ‘debug’
set_if_unset LOG_LEVEL_GUI '2' # A numeric level for logging by GUI dialogues; 0 meaning no logging at all and 4 ‘debug’. Can only be <= $LOG_LEVEL.
set_if_unset LOG_SYSTEM '' # Whether to print logs to the system log (may be ‘true’, ‘false’ or empty). Will be determined automatically if empty.
set_if_unset LOG_VERBOSE '' # Setting this to any non-empty value will make commands verbose where possible
set_if_unset GUI_HELP_WIDTH '600' # The width of the help dialogue.
set_if_unset GUI_HELP_HEIGHT '400' # The height of the help dialogue.
set_if_unset GUI_SUDO_TIMEOUT '300' # The timeout for the sudo password prompt in seconds (sudo's default is 5 minutes)
set_if_unset IS_SOURCED 'false' # Set this to true if you want to source the script without executing it
VERSION_INFO="Ren'Py desktop file generator 2.0

Written by Polymehr.
Based on a script by 🐲Shin." # Printed by ‘--version’
THIS="$(readlink -f "$0")" # The path to this script.
THIS_NAME="$(basename "$THIS")" # The name of this script.
################################################################################

# Checks whether a specific command is installed on the current system.
#
# $1: The command to be checked. Must be accepted by `command`.
#
# Returns success if it is, and failure otherwise.
has() {
    command -v "$1" > /dev/null
}

# Checks whether a specific set of commands is installed on the current system.
#
# $@: The commands to be checked. Must be accepted by `command`.
#
# Returns success if all of them are, and failure otherwise.
has_all() {
    for HA_COMMAND in "$@"; do
        if ! has "$HA_COMMAND"; then
            unset HA_COMMAND
            return 1
        fi
    done
    unset HA_COMMAND
    return 0
}

# Simulates the echo command in a more reliable form.
# See https://unix.stackexchange.com/questions/65803/why-is-printf-better-than-echo
#
# $*: The arguments to be printed.
#
# Prints the result to stdout.
if has local; then
echo() {
    # The horrors of Echo even extend to the realm of shell scripting in the
    # form of cross platform compatibility and escaping.
    # shellcheck disable=SC2039
    local IFS=' '
    printf '%s\n' "$*"
}
else
echo() {
    # The horrors of Echo even extend to the realm of shell scripting in the
    # form of cross platform compatibility and escaping. (This needs repeating.)
    E_OLD_IFS="$IFS"
    IFS=' '
    printf '%s\n' "$*"
    IFS="$E_OLD_IFS"
    unset E_OLD_IFS
}
fi

# Writes a log message to an external program. In this case these programs are
# `zenity` and `logger`. Any whitespace and the starting scope will be stripped
# from the message.
#
# $1: The scope of the message. This can be either ‘error’, ‘warning’, ‘info’
#     or ‘debug’.
# $2: The message. Has to contain the sequence ‘: ’ in the first line.
log_external() {
    LE_TEMP="$(echo "$2" | sed '1s/^[^:]*:\s//;2,$s/^\s*//')"
    if [ "$LOG_SYSTEM" = true ] && has logger; then
        case "$1" in
            error)
                logger --id="$$" --priority err --tag "$THIS_NAME" "$LE_TEMP"
                ;;
            warning)
                logger --id="$$" --priority warning --tag "$THIS_NAME" "$LE_TEMP"
                ;;
            info)
                logger --id="$$" --priority info --tag "$THIS_NAME" "$LE_TEMP"
                ;;
            debug)
                logger --id="$$" --priority debug --tag "$THIS_NAME" "$LE_TEMP"
                ;;
                *)
                    echo "ERROR: Invalid external log scope!" >&2
        esac
    fi
    if [ "$GUI" = true ] && has zenity; then
        case "$1" in
            error)
                if [ "$LOG_LEVEL_GUI" -gt 0 ]; then
                    zenity --error --text="$LE_TEMP" --title "Error: ${THIS_NAME%.sh}"  --no-wrap || true
                fi
                ;;
            warning)
                if [ "$LOG_LEVEL_GUI" -gt 1 ]; then
                    zenity --warning --text="$LE_TEMP" --title "Warning: ${THIS_NAME%.sh}"  --no-wrap || true
                fi
                ;;
            info)
                if [ "$LOG_LEVEL_GUI" -gt 2 ]; then
                    zenity --info --text="$LE_TEMP" --title "Info: ${THIS_NAME%.sh}"  --no-wrap || true
                fi
                ;;
            debug)
                if [ "$LOG_LEVEL_GUI" -gt 3 ]; then
                    zenity --info --text="$LE_TEMP" --title "Debug: ${THIS_NAME%.sh}"  --no-wrap || true
                fi
                ;;
                *)
                    echo "ERROR: Invalid external log scope!" >&2
        esac
    fi
    unset LE_TEMP
}

# Outputs the remaining arguments according to the value of the first argument
# depending on the current log level.
#
# $1: The scope to log to. This can be either ‘error’, ‘warning’, ‘info’ or
#     ‘debug’. If the scope ends with ‘>’ create a new line for the next log,
#     while not printing the scope again and only matching indent. If the GUI
#     is used all the lines will be combined in one box.
#
# The function sets the "static" variables $L_CACHE_[LEVEL] to keep track
# of multi-line logs. They should not be changed.
log() {
    case "$1" in
        error)
            if [ "$LOG_LEVEL" -gt 0 ]; then
                shift
                if [ -z "${L_CACHE_ERROR:-}" ]; then
                    printf '%-7s: ' 'error' >&2
                    echo "$@" >&2

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        # shellcheck disable=SC2116
                        log_external 'error' "$(echo ': ' "$@")"
                    fi
                else
                    printf '%s\n' "$L_CACHE_ERROR" >&2
                    printf '%-9s' '' >&2
                    echo "$@" >&2

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        log_external 'error' "$(printf '%s\n' "$L_CACHE_ERROR"; echo "$@")"
                    fi
                    L_CACHE_ERROR=
                fi
            fi
            ;;
        error\>)
            if [ "$LOG_LEVEL" -gt 0 ]; then
                shift
                if [ -z "${L_CACHE_ERROR:-}" ]; then
                    L_CACHE_ERROR="$(printf '%-7s: ' 'error')"
                else
                    L_CACHE_ERROR="$L_CACHE_ERROR$(printf '\n%-9s' '')"
                fi
                # shellcheck disable=SC2116
                L_CACHE_ERROR="$L_CACHE_ERROR$(echo "$@")"
            fi
            ;;
        warning)
            if [ "$LOG_LEVEL" -gt 1 ]; then
                shift
                if [ -z "${L_CACHE_WARNING:-}" ]; then
                    printf '%-7s: ' 'warning' >&2
                    echo "$@" >&2

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        # shellcheck disable=SC2116
                        log_external 'warning' "$(echo ': ' "$@")"
                    fi
                else
                    printf '%s\n' "$L_CACHE_WARNING" >&2
                    printf '%-9s' '' >&2
                    echo "$@" >&2

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        log_external 'warning' "$(printf '%s\n' "$L_CACHE_WARNING"; echo "$@")"
                    fi
                    L_CACHE_WARNING=
                fi
            fi
            ;;
        warning\>)
            if [ "$LOG_LEVEL" -gt 1 ]; then
                shift
                if [ -z "${L_CACHE_WARNING:-}" ]; then
                    L_CACHE_WARNING="$(printf '%-7s: ' 'warning')"
                else
                    L_CACHE_WARNING="$L_CACHE_WARNING$(printf '\n%-9s' '')"
                fi
                # shellcheck disable=SC2116
                L_CACHE_WARNING="$L_CACHE_WARNING$(echo "$@")"
            fi
            ;;
        info)
            if [ "$LOG_LEVEL" -gt 2 ]; then
                shift
                if [ -z "${L_CACHE_INFO:-}" ]; then
                    printf '%-7s: ' 'info'
                    echo "$@"

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        # shellcheck disable=SC2116
                        log_external 'info' "$(echo ': ' "$@")"
                    fi
                else
                    printf '%s\n' "$L_CACHE_INFO"
                    printf '%-9s' ''
                    echo "$@"

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        log_external 'info' "$(printf '%s\n' "$L_CACHE_INFO"; echo "$@")"
                    fi
                    L_CACHE_INFO=
                fi
            fi
            ;;
        info\>)
            if [ "$LOG_LEVEL" -gt 2 ]; then
                shift
                if [ -z "${L_CACHE_INFO:-}" ]; then
                    L_CACHE_INFO="$(printf '%-7s: ' 'info')"
                else
                    L_CACHE_INFO="$L_CACHE_INFO$(printf '\n%-9s' '')"
                fi
                # shellcheck disable=SC2116
                L_CACHE_INFO="$L_CACHE_INFO$(echo "$@")"
            fi
            ;;
        debug)
            if [ "$LOG_LEVEL" -gt 3 ]; then
                shift
                if [ -z "${L_CACHE_DEBUG:-}" ]; then
                    printf '%-7s: ' 'debug'
                    echo "$@"

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        # shellcheck disable=SC2116
                        log_external 'debug' "$(echo ': ' "$@")"
                    fi
                else
                    printf '%s\n' "$L_CACHE_DEBUG"
                    printf '%-9s' ''
                    echo "$@"

                    if [ "$GUI" = true ] || [ "$LOG_SYSTEM" = true ]; then
                        log_external 'debug' "$(printf '%s\n' "$L_CACHE_DEBUG"; echo "$@")"
                    fi
                    L_CACHE_DEBUG=
                fi
            fi
            ;;
        debug\>)
            if [ "$LOG_LEVEL" -gt 3 ]; then
                shift
                if [ -z "${L_CACHE_DEBUG:-}" ]; then
                    L_CACHE_DEBUG="$(printf '%-7s: ' 'debug')"
                else
                    L_CACHE_DEBUG="$L_CACHE_DEBUG$(printf '\n%-9s' '')"
                fi
                # shellcheck disable=SC2116
                L_CACHE_DEBUG="$L_CACHE_DEBUG$(echo "$@")"
            fi
            ;;
        *)
            echo "ERROR: Invalid log scope!" >&2
    esac
}

# Check whether the commands this script depends on are installed and if
# $CHECK_OPTIONAL_DEPENDENCIES is 'true', whether the optional dependencies are
# installed with a short reason why the user should do so if they are found
# missing.
#
# This function expects the $CHECK_OPTIONAL_DEPENDENCIES variable to be set.
check_dependencies() {
    CD_ACT=
    for CD_COMMAND in /bin/sh basename cat cd command cp cut dirname eval exit file find grep head ln\
        id mkdir mkfifo mv printf read readlink return rm sed set shift sudo sort test tr trap unset; do
        if ! has "$CD_COMMAND"; then
            log 'error' "The \`$CD_COMMAND\` command must be installed for this script to work properly!";
            CD_ACT=true
        fi
    done
    [ -n "$CD_ACT" ] && exit 1
    CD_ACT=
    [ "$CHECK_OPTIONAL_DEPENDENCIES" = true ] && for CD_COMMAND in\
            base64 'Used in current version search script (to escape escaping hell).'\
            wget   'Download fallback icon.'                         desktop-file-install 'Check and install the generated desktop file.'\
            env    'Used in current version search script.'          icns2png             'Handle the Apple Icon Image format correctly.'\
            logger 'Log to the system log.'                          magick               'Ensure correct image format. (ImageMagick)'\
            mktemp 'Ensure no naming conflicts for temporary files.' uniq                 'Used in current version search script.'\
            update-desktop-database 'Check the installed generated desktop file and make it findable.'\
            xargs  'Used in current version search script.'          zenity               'Create a rudimentary GUI.'\
            "${PAGER:-less}" 'Pager to display the help.'; do
        if [ -z "$CD_ACT" ]; then
            if ! has "$CD_COMMAND"; then
                log 'warning>' "The \`$CD_COMMAND\` command should be installed for for a better user experience:"
                CD_ACT=true
            else
                CD_ACT=false
            fi
        else
            [ "$CD_ACT" = true ] &&\
                log 'warning' "$CD_COMMAND"
            CD_ACT=
        fi
    done
    unset CD_COMMAND CD_ACT
}

# Escape string so that it can be used in single quotes.
#
# $1: The string to be escaped.
#
# Prints the result to stdout.
escape_single_quote() {
    echo "$1" | sed "s/'/'\\\\''/g"
}

# Escape string so that it can be used in a grep pattern.
# Newlines are not regarded.
#
# $1: The string to be escaped.
#
# Prints the result to stdout.
escape_grep_pattern() {
    echo "$1" | sed 's/[][\^.*$]/\\&/g'
}

# Escape string so that it can be used in a sed pattern section.
# This function expects the sections to be delimited with ‘/’.
# Newlines are not regarded.
#
# $1: The string to be escaped.
#
# Prints the result to stdout.
escape_sed_pattern() {
    echo "$1" | sed -e 's|[][$*.^\/]|\\&|g'
}

# Escape string so that it can be used in a sed replacement section.
# This function expects the sections to be delimited with ‘/’.
# Newlines are not regarded.
#
# $1: The string to be escaped.
#
# Prints the result to stdout.
escape_sed_replacement() {
    echo "$1" | sed 's|[&/\]|\\&|g'
}

# Escapes a string for the use in a desktop file's Exec field. This will probably
# result in a very unreadable string, but the less escaping layers the better (at
# least in my opinion).
#
# $1: The string to be escaped.
#
# Prints the result to stdout.
escape_desktop_exec() {
    echo "$1" | sed 's/[ "'\''\><~|&;\$*?#()`]/\\&/g;
                     s/%/%%/g;
                     s/\n/"\\n"/g;
                     s/\t/"\\t"/g;
                     s/"\\n"$//' -z
}

# Escapes a string for the use in a desktop file's field that accepts a string.
#
# $1: The string to be escaped.
#
# Prints the result to stdout.
escape_desktop_string() {
    echo "$1" | sed 's/\\/&&/g;s/\n/\\n/g;s/\t/\\t/g;s/\r/\\r/g;s/\\n$/\n/' -z
}

unescape_desktop_string() {
    echo "$1" | sed 's/\\n/\n/g;s/\\t/\t/g;s/\\r/\r/g;s/\\s/ /g;s/\\\\/\\/g' -z

}

# Prompt the user to answer a yes/no question. If the user leaves the prompt
# empty a default can be given. If the entry is invalid the prompt will be
# repeated.
# Will return immediately if $1 is already set.
#
# $1: The variable to be set. This will be fed to a eval expression so be
#     careful.
# $2: The prompt string that will be displayed to the user.
# $3: The default if the user leaves the prompt empty. May be ‘yes’, ‘no’ or
#     empty.
#
# This function expects the variable in $1 to be set.
#
# The function returns 0 if yes was was chosen, 1 otherwise.
prompt_user() {
    eval "PC_CHOICE=\"\$$1\""
    if [ "$PC_CHOICE" = yes ]; then
        unset PC_CHOICE
        return 0
    elif [ "$PC_CHOICE" = no ]; then
        unset PC_CHOICE
        return 1
    fi
    unset PC_CHOICE

    if [ "$GUI" = true ] && has zenity; then
        if zenity --question --text="$2" --title "Question: ${THIS_NAME%.sh}" --no-wrap; then
            eval "$1=yes"
            return 0
        else
            eval "$1=no"
            return 1
        fi
    fi

    PC_CHOICE=
    PC_PROMPT="$2"
    case "$3" in
        yes) PC_PROMPT="$PC_PROMPT (Y/n)";;
        no)  PC_PROMPT="$PC_PROMPT (y/N)";;
        '')  PC_PROMPT="$PC_PROMPT (y/n)";;
        *) log 'error' 'Invalid default choice!' && exit 1
    esac

    while [ "$PC_CHOICE" != yes ] && [ "$PC_CHOICE" != no ]; do
        printf '%s ' "$PC_PROMPT"
        read -r PC_CHOICE
        PC_CHOICE="$(echo "$PC_CHOICE" | sed 's/^\s*//;s/\s*$//')"
        if [ -z "$PC_CHOICE" ]; then
            PC_CHOICE="$3"
        elif echo "$PC_CHOICE" | grep -qiE '^y(e(s)?)?$'; then
            PC_CHOICE=yes
        elif echo "$PC_CHOICE"  | grep -qiE '^n(o)?$'; then
            PC_CHOICE=no
        fi
    done
    eval "$1=\"$PC_CHOICE\""

    if [ "$PC_CHOICE" = yes ]; then
        unset PC_CHOICE
        return 0
    else
        unset PC_CHOICE
        return 1
    fi
}

# Execute stdin as root if the file given as first argument is not writeable by
# the current user. Otherwise execute stdin directly.
#
# $@: The file(s) to be checked for write permissions. If one is not, use sudo.
# stdin: The script to be executed.
#
# The function sets the "static" variable $SINW_ASKPASS to keep track
# of a temporary script that is created when the GUI is used to start `zenity`.
# This variable or the attached file shouldn't be changed and cleaned up
# afterwards by calling `cleanup`.
#
# This function returns successfully if the execution of stdin was successful.
sudo_if_not_writeable() {
    SINW_SCRIPT=$(cat)
    for SINW_FILE in "$@"; do
        if  [ -e "$SINW_FILE" ] && [ ! -w "$SINW_FILE" ]; then
            # Sometimes we'll need the right PASSWORD to progress
            log 'warning' "Access to ‘$SINW_FILE’ needed."
            unset SINW_FILE
            if [ -n "${LOG_VERBOSE:+?}" ]; then
                log 'debug>' 'This will be executed:'
                log 'debug'  "$SINW_SCRIPT"
            fi
            if [ "$GUI" = true ] && has zenity; then
                if [ -n "${SUDO_ASKPASS:-}" ] || ! grep -sq '^\s*Path\s\+askpass\s\+.' /etc/sudo.conf; then # Prefer users settings if possible
                    # Generate the file even when password is cached to avoid race conditions
                    if has mktemp; then
                        SINW_ASKPASS="$(mktemp --suffix=.sh)"
                    else
                        SINW_ASKPASS="/tmp/renpy_deskgen_askpass.sh"
                    fi
                    cat > "$SINW_ASKPASS" << EOF
#!/bin/sh
zenity --title '[sudo] : $(escape_single_quote "${THIS_NAME%.sh}")'\
    --password --timeout=$GUI_SUDO_TIMEOUT
EOF
                    chmod u+x "$SINW_ASKPASS"
                    export SUDO_ASKPASS="$SINW_ASKPASS"
                fi
                if ! echo "set -eu; $SINW_SCRIPT" | sudo -Ai /bin/sh; then
                    log 'error' "Execution with \`sudo\` failed."
                    unset SINW_SCRIPT
                    return 1
                fi
            else
                if ! echo "set -eu; $SINW_SCRIPT" | sudo -i /bin/sh; then

                    log 'error' "Execution with \`sudo\` failed."
                    unset SINW_SCRIPT
                    return 1
                fi
            fi
            unset SINW_SCRIPT
            return 0
        fi
    done
    unset SINW_FILE
    if  ! echo "set -eu; $SINW_SCRIPT" | /bin/sh; then
        unset SINW_SCRIPT
        return 1
    fi
    unset SINW_SCRIPT
}

# Tries to find the file that stores the attributes of the theme ‘hicolor’.
#
# This function expects the $INSTALL_SYSTEM_WIDE and $ICON_DIR variables
# to be set.
#
# If the function terminates successfully, it will set $THEME_ATTRIBUTE_FILE if
# it was empty or unset before.
find_theme_attribute_file() {
    [ -n "${THEME_ATTRIBUTE_FILE:-}" ] && return

    if [ "$INSTALL_SYSTEM_WIDE" = false ]; then
        [ -f "$HOME/.icons/hicolor/index.theme" ] &&\
            THEME_ATTRIBUTE_FILE="$HOME/.icons/hicolor/index.theme" && return
    fi

    # Avoid more fifos
    FTAF_DIRS="${XDG_DATA_DIRS:-"/usr/local/share/:/usr/share/"}"
    while [ -n "$FTAF_DIRS" ]; do
        FTAF_DIR="$(echo "$FTAF_DIRS" | cut -d: -f1)"
        FTAF_DIRS="$(echo "$FTAF_DIRS" | cut -d: -f2-)"
        if [ -f "$FTAF_DIR/icons/hicolor/index.theme" ]; then
            THEME_ATTRIBUTE_FILE="$FTAF_DIR/icons/hicolor/index.theme"
            unset FTAF_DIR FTAF_DIRS
            return
        fi
    done
    unset FTAF_DIR FTAF_DIRS

    [ -f '/usr/share/pixmaps/hicolor/index.theme' ] &&\
        THEME_ATTRIBUTE_FILE='/usr/share/pixmaps/hicolor/index.theme' && return

    if [ "$INSTALL_SYSTEM_WIDE" = false ]; then
        # This is non-specification
        [ -f "${XDG_DATA_HOME:-"$HOME/.local/share"}/icos/hicolor/index.theme" ] &&\
            THEME_ATTRIBUTE_FILE="${XDG_DATA_HOME:-"$HOME/.local/share"}/icos/hicolor/index.theme" && return
    fi
    # Last resort and maybe non-specification
    [ -f "$ICON_DIR/hicolor/index.theme" ] &&\
        THEME_ATTRIBUTE_FILE="$ICON_DIR/hicolor/index.theme" && return
    THEME_ATTRIBUTE_FILE= # Couldn't be found
}

# Read the value of a key from an theme attribute file section.
#
# $1: The data/lines of the section to be read.
# $2: The key to be read. Should only contain 'a-zA-Z-' (as demanded by the
#     specification)
# $3: Whether this key is required. Possible values are 'true' and 'false'.
#     If the key is absent and $3 is 'true', return unsuccessfully.

# This function expects the $THEME_ATTRIBUTE_FILE and $PTAF_SECTION variables
# to be set.
#
# Prints the value of the key to stdout.
read_theme_attribute_file_key() {
    if ! echo "$1" | grep -q "^$2\\s*=" && [ "$3" = true ]; then
        log 'error' "Invalid theme attribute file section ‘$PTAF_SECTION’: '$2'"\
             "key not present (file ‘$THEME_ATTRIBUTE_FILE’)."
        return 1
    fi
    echo "$1" | sed -n "/^$2"'\s*=/{s/^[^=]*=\s*//p;q}'
    return 0
}

# Parses the theme attribute file into shell variables. The variables may be
# empty if their keys weren't present and they key itself not mandatory.
# The following variables will be created:
# Content of ‘Icon Theme’ section: $TAF__Icon_Theme__[KEY NAME]
# Name of directory section:       $TAF__DIR_[NUMBER IN DIR LISTS]__Name
# Content of directory section:    $TAF__DIR_[NUMBER IN DIR LISTS]__[KEY NAME]
# Number of directory sections:    $TAF_NUM_DIRS
# For the ‘Icon Theme’ section only the keys ‘Name’, ‘Comment’, ‘Directories’
# and ‘ScaledDirectories’ are recorded. Directory sections are only regarded
# if they are for application icons and are otherwise not parsed an counted.
#
# This function expects the $THEME_ATTRIBUTE_FILE variable to be set.
#
# If the function returns successfully, the variables above will be set.
# The function will return unsuccessfully if a mandatory key was not set and
# the attribute file is thus not valid.
parse_theme_attribute_file() {
    [ -z "${THEME_ATTRIBUTE_FILE:+!}" ] && return 1
    log 'info' 'Parsing theme attribute file…'
    PTAF_TEMP="$(sed -n '/^\[Icon Theme\]$/,/^\[/{p;/^\[/{/^\[Icon Theme\]$/!q}}' "$THEME_ATTRIBUTE_FILE")"
    PTAF_SECTION='Icon Theme'
    TAF__Icon_Theme__Name="$(read_theme_attribute_file_key "$PTAF_TEMP" 'Name' true)" || return 1
    TAF__Icon_Theme__Comment="$(read_theme_attribute_file_key "$PTAF_TEMP" 'Comment' true)" || return 1
    TAF__Icon_Theme__Directories="$(read_theme_attribute_file_key "$PTAF_TEMP" 'Directories' true)" || return 1
    TAF__Icon_Theme__ScaledDirectories="$(read_theme_attribute_file_key "$PTAF_TEMP" 'ScaledDirectories' false)"

    if has mktemp; then
        PTAF_FIFO="$(mktemp -u)"
    else
        PTAF_FIFO="/tmp/renpy_deskgen_fifo"
    fi
    mkfifo "$PTAF_FIFO"
    TAF_NUM_DIRS=0
    echo "$TAF__Icon_Theme__Directories${TAF__Icon_Theme__ScaledDirectories:+",$TAF__Icon_Theme__ScaledDirectories"}" |\
        sed 's/,/\n/g;s/\\\n/,/' > "$PTAF_FIFO"&
    while read -r PTAF_DIR; do
        if ! echo "$PTAF_DIR" | grep -q 'apps/*$'; then # Only consider directories for application icons
            continue
        fi
        PTAF_TEMP="$(escape_sed_pattern "[$PTAF_DIR]")"
        PTAF_TEMP="$(sed -n '/^'"$PTAF_TEMP"'$/,/^\[/{p;/^\[/{/^'"$PTAF_TEMP"'$/!q}}' "$THEME_ATTRIBUTE_FILE")"
        if  ! echo "$PTAF_TEMP" | grep -qi '^Context\s*=\s*Applications\s*$'; then
            continue
        fi

        PTAF_SECTION="$PTAF_DIR"
        eval "TAF__DIR_${TAF_NUM_DIRS}__Name='$(escape_single_quote "$PTAF_DIR")'"
        PTAF_KEY="$(read_theme_attribute_file_key "$PTAF_TEMP" 'Size' true)" || return 1
        eval "TAF__DIR_${TAF_NUM_DIRS}__Size='$(escape_single_quote "$PTAF_KEY")'"
        eval "TAF__DIR_${TAF_NUM_DIRS}__Scale='$(escape_single_quote "$(read_theme_attribute_file_key "$PTAF_TEMP" 'Scale' false)")'"
        eval "TAF__DIR_${TAF_NUM_DIRS}__Context='$(escape_single_quote "$(read_theme_attribute_file_key "$PTAF_TEMP" 'Context' false)")'"
        eval "TAF__DIR_${TAF_NUM_DIRS}__Type='$(escape_single_quote "$(read_theme_attribute_file_key "$PTAF_TEMP" 'Type' false)")'"
        eval "TAF__DIR_${TAF_NUM_DIRS}__MaxSize='$(escape_single_quote "$(read_theme_attribute_file_key "$PTAF_TEMP" 'MaxSize' false)")'"
        eval "TAF__DIR_${TAF_NUM_DIRS}__MinSize='$(escape_single_quote "$(read_theme_attribute_file_key "$PTAF_TEMP" 'MinSize' false)")'"
        eval "TAF__DIR_${TAF_NUM_DIRS}__Threshold='$(escape_single_quote "$(read_theme_attribute_file_key "$PTAF_TEMP" 'Threshold' false)")'"
        TAF_NUM_DIRS="$((TAF_NUM_DIRS+1))"
    done < "$PTAF_FIFO"
    rm "$PTAF_FIFO"
    if ! echo "$TAF__Icon_Theme__Name" | grep -qiF 'hicolor'; then # I'm totally not doing this to get rid of the ‘unused’ warning…
        log 'warning' "Expected theme name to be ‘hicolor’. (Name: ‘$TAF__Icon_Theme__Name’, Comment: ‘$TAF__Icon_Theme__Comment’)"
    fi
    log 'info' 'Finished parsing theme attribute file.'
    unset PTAF_TEMP PTAF_FIFO PTAF_DIR PTAF_SECTION PTAF_KEY
}

# Tries to find the best matching icon directory from the theme attribute file
# The directory will be saved in the following variables:
# Best matching directory (may be empty): $BEST_MATCH
# Size of matching directory (may be empty): $BEST_MATCH_SIZE
# Distance to best matching directory (may be empty): $BEST_MATCH_DISTANCE
#
# $1: The size of the icon.
#
# This function expects the $THEME_ATTRIBUTE_FILE related variables to be set.
#
# If the function returns successfully, the variables above will be set but may
# be empty if no directory was found
find_best_icon_size_match() {
    BEST_MATCH=
    BEST_MATCH_DISTANCE=
    BEST_MATCH_SIZE=
    FBISM_NO=0
    FBISM_ICON_SIZE="$1"
    while [ "$FBISM_NO" -lt "$TAF_NUM_DIRS" ]; do
        eval 'FBISM_SIZE="$TAF__DIR_'$FBISM_NO'__Size"'
        if [ -z "$BEST_MATCH_DISTANCE" ]; then
            BEST_MATCH_DISTANCE="$((FBISM_ICON_SIZE-FBISM_SIZE))"
            BEST_MATCH_DISTANCE="${BEST_MATCH_DISTANCE#-}"
                BEST_MATCH_SIZE="$FBISM_SIZE"
            eval 'BEST_MATCH="$TAF__DIR_'$FBISM_NO'__Name"'
        else
            FBISM_DIFF="$((FBISM_ICON_SIZE-FBISM_SIZE))"
            FBISM_DIFF="${FBISM_DIFF#-}"
            if [ "$FBISM_DIFF" -lt "$BEST_MATCH_DISTANCE" ]; then
                BEST_MATCH_DISTANCE="$FBISM_DIFF"
                BEST_MATCH_SIZE="$FBISM_SIZE"
                eval 'BEST_MATCH="$TAF__DIR_'$FBISM_NO'__Name"'
            fi
        fi
        if [ "$BEST_MATCH_DISTANCE" = 0 ]; then # Found a perfect match
            break
        else
            FBISM_NO="$((FBISM_NO+1))"
        fi
    done
    unset FBISM_ICON_SIZE FBISM_SIZE FBISM_NO FBISM_DIFF
}

# Tries to extract the configured game name from the game. If $DISPLAY_NAME is
# set use that, otherwise try to search the name for in in the game directory.
# In the case that no name was found the function falls back to $BUILD_NAME.
#
# This function expects the $RENPY_ROOT_DIR, $DISPLAY_NAME and $BUILD_NAME
# related variables to be set.
#
# If the function terminates successfully, it will set $GAME_NAME.
find_game_name() {
    [ -n "$DISPLAY_NAME" ] && GAME_NAME="$DISPLAY_NAME" && return

    # OMG correct file handling in UNIX…
    # This script also parses Ren'Py strings correctly in combination with the
    # sed-commands after the find invocation
    FGN_SEARCH_SCRIPT="$(cat << 'EOF'
    set -eu
    for FGN_FILE do
        if grep -q 'config\.name\s*=[^"'\'']*"[^"]*"' "$FGN_FILE"; then
            sed -n 's/^.*config\.name\s*=[^"'\'']*"\(.*\)".*$/\1/p' "$FGN_FILE" |\
                grep -o . | sed ':a;$be;N;/\\\n"$/ba;/"$/{s/.$//;be};ba;:e;s/\n//g;q'
            break
        elif grep -q "config.name\\s*=[^'\"]*'[^']*'" "$FGN_FILE"; then
            sed -n "s/^.*config\\.name\\s*=[^'\"]*'\\(.*\\)'.*$/\\1/p" "$FGN_FILE" |\
                grep -o . | sed ':a;$be;N;/\\\n'\''$/ba;/'\''$/{s/.$//;be};ba;:e;s/\n//g;q'
            break
        fi
    done
EOF
    )"

    # Search in Ren'Py script files. Most likely contained in options.rpy.
    GAME_NAME="$(find "$RENPY_ROOT_DIR/game" -type f -iname '*.rpy'\
        -exec /bin/sh -c "$FGN_SEARCH_SCRIPT" /bin/sh '{}' + | head -n1 |\
        sed -z 's/\n$//;s/\\n/\n/g;s/\[\[/[/g;s/\\\(['\'' "]\)/\1/g;s/{{/{/g;s/\\\\/\\/g';
        printf '_')"
    GAME_NAME="${GAME_NAME%_}" # Allow new line at end of game names. For some reason…

    # If the creator of the game included .rpy files, the uncompressed portions
    # of an .rpa file may contain the string we're searching for
    [ -z "$GAME_NAME" ] && GAME_NAME="$(find "$RENPY_ROOT_DIR/game" -type f -iname '*.rpa'\
        -exec /bin/sh -c "$FGN_SEARCH_SCRIPT" /bin/sh '{}' + | head -n1 |\
        sed -z 's/\n$//;s/\\n/\n/g;s/\[\[/[/g;s/\\\(['\'' "]\)/\1/g;s/{{/{/g;s/\\\\/\\/g';
        printf '_')"
    GAME_NAME="${GAME_NAME%_}"

    # Use build name as fallback
    if [ -z "$GAME_NAME" ]; then
        GAME_NAME="$BUILD_NAME"
        log 'warning' "Could not extract game name. Defaulting to ‘$GAME_NAME’."
    else
        log 'info' "Extracted game name ‘$GAME_NAME’."
    fi

    unset FGN_SEARCH_SCRIPT FGN_FILE
}

# Uninstalls a previously installed desktop file and icons.
# Tries (and asks the user beforehand if in interactive session) to remove empty
# directories that result from the removal of the icon files.
#
# This function expects the $BUILD_NAME, $VENDOR_PREFIX and $ICON_DIR variables
# to be set. If $UNINSTALL_REMOVE is empty, the script will prompt the user
# interactively with the default being ‘yes.’ The value will determine whether
# empty directories should be removed.
# The theme attribute file will not be updated.
uninstall() {
sudo_if_not_writeable "$INSTALL_DIR/$VENDOR_PREFIX$BUILD_NAME.desktop" << EOSUDO
    rm ${LOG_VERBOSE:+"-v"} '$(escape_single_quote "$INSTALL_DIR/$VENDOR_PREFIX$BUILD_NAME.desktop")'
EOSUDO
    U_ICON_DIR="$(escape_single_quote "$ICON_DIR")"
sudo_if_not_writeable "$ICON_DIR" << EOSUDO
    find  '$U_ICON_DIR' -name '$(escape_single_quote "$VENDOR_PREFIX$BUILD_NAME.png")' -exec rm ${LOG_VERBOSE:+"-v"} {} +
EOSUDO
    if find  "$ICON_DIR" -depth -type d -empty | grep -q .; then
        log 'info' "Empty directories:" "$(find  "$ICON_DIR" -depth -type d -empty)"
        if has zenity && [ "$GUI" = true ] && [ "$LOG_LEVEL_GUI" -lt 3 ]; then
            U_NOTICE=" (shown on GUI log level ‘info’)"
        elif [ "$LOG_LEVEL" -lt 3 ]; then
            U_NOTICE=" (shown on log level ‘info’)"
        fi
        if prompt_user UNINSTALL_REMOVE "Empty directories found${U_NOTICE:-}. Delete them? (The theme will not be updated.)" yes; then
sudo_if_not_writeable "$ICON_DIR" << EOSUDO
            find  '$U_ICON_DIR' -depth -type d -empty -exec rmdir ${LOG_VERBOSE:+"-v"} {} \;
EOSUDO
        fi
    fi
    unset U_ICON_DIR
}

# Determines the correct value for the variable $LOCATION_AGNOSTIC_SEARCH_DIR
# and check whether is value is correct.
#
# This function expects the $LOCATION_AGNOSTIC, $RENPY_ROOT_DIR
# and $LOCATION_AGNOSTIC_SEARCH_DIR variables to be set.
#
# If the function terminates successfully, it will set
# $LOCATION_AGNOSTIC_SEARCH_DIR accordingly.
determine_location_agnostic_search_dir() {
    if [ "$LOCATION_AGNOSTIC" = yes ]; then
        if [ -z "$LOCATION_AGNOSTIC_SEARCH_DIR" ]; then
            LOCATION_AGNOSTIC_SEARCH_DIR="$(dirname "$RENPY_ROOT_DIR")"
        else
            CLASD_TEMP="$PWD"
            cd "$RENPY_ROOT_DIR" || exit 1
            LOCATION_AGNOSTIC_SEARCH_DIR="$(readlink -f "$LOCATION_AGNOSTIC_SEARCH_DIR")"
            [ ! -d "$LOCATION_AGNOSTIC_SEARCH_DIR" ] &&\
                log 'error' "Version search directory must exist!" && exit 1
            case "$RENPY_ROOT_DIR/" in
                "$LOCATION_AGNOSTIC_SEARCH_DIR"/*);;
                *)
                    log 'warning' "Version search directory is not a parent of Ren'Py"
                        "game directory! Game probably will not be found."
            esac

            cd "$CLASD_TEMP" || exit 1
        fi
        unset CLASD_TEMP
    fi
}

# Creates a desktop file in the current directory. The display name entry in the
# file (Name field) will be set to the configured game name and can be
# specifically overwritten with $DISPLAY_NAME. If no name is found $BUILD_NAME
# is used.
# The created file will have the name ‘$VENDOR_PREFIX$BUILD_NAME.desktop.’
#
# This function expects the $BUILD_NAME, $ICON, $RENPY_SCRIPT_PATH,
# $LOCATION_AGNOSTIC,  $LOCATION_AGNOSTIC_SEARCH_DIR, $RENPY_ROOT_DIR,
# $VENDOR_PREFIX, $DESKTOP_FILE and $DISPLAY_NAME variables to be set. The 
# LOCATION_AGNOSTIC_SEARCH_DIR, $VENDOR_PREFIX and $DISPLAY_NAME variables may
# be empty.
#
# If the function terminates successfully, it will set $DESKTOP_FILE to the
# location of the generated file.
create_desktop_file() {
    find_game_name

    CDF_SCRIPT="$RENPY_SCRIPT_PATH"
    if [ "$LOCATION_AGNOSTIC" = yes ]; then
        if has_all base64 env uniq xargs; then
            # Welcome to shell escaping and quoting hell. D:
            # This script tries to find scripts that contain a Python script of the
            # same name in the same directory and then finds the newest of them,
            # which will be executed. The resulting string is then base64
            # encoded to avoid unreliable unescaping by launchers…
            CDF_SCRIPT='/bin/sh -c '"$(escape_desktop_exec "printf $(echo "find '$(escape_single_quote "$LOCATION_AGNOSTIC_SEARCH_DIR")' -type f \\( -name '$(escape_single_quote "$BUILD_NAME").[Ss][Hh]' -o -name '$(escape_single_quote "$BUILD_NAME").[Pp][Yy]' \\) -printf '%C+ %p\\0'  | sed -z 's/..\$/sh/' | sort -zr | sort -szk2 | uniq -zdf1 | sort -zr | head -zn1 | cut -zd' ' -f2- | xargs -r0 env" | base64 -w0 -) | base64 -d | /bin/sh")"
        else
            log 'warning' "\`base64\`, \`env\`, \`uniq\` and \`xargs\` must be installed for current version search to work!"
            CDF_SCRIPT="$(escape_desktop_exec "$CDF_SCRIPT")"
        fi
    else
        CDF_SCRIPT="$(escape_desktop_exec "$CDF_SCRIPT")"
    fi
    if has mktemp; then
        DESKTOP_FILE="$(mktemp -d)/$VENDOR_PREFIX$BUILD_NAME.desktop"
    else
        DESKTOP_FILE="/tmp/$VENDOR_PREFIX$BUILD_NAME.desktop"
    fi
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.1
Type=Application
Terminal=false
Exec=$CDF_SCRIPT
Name=$(escape_desktop_string "$GAME_NAME")
GenericName=Visual Novel
Categories=Game;
Keywords=entertainment;games;visualnovel;$(escape_desktop_string "$(echo "$BUILD_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/;/\\;/')");
EOF
    [ -n "$ICON" ] && echo "Icon=$(escape_desktop_string "$ICON")" >> "$DESKTOP_FILE"
    unset CDF_SCRIPT CDF_TEMP
}

# Tries to to find the correct size directory to install an icon to or if that
# is not possible apply one of the strategies informed by
# ‘--icon-size-not-existing-handling’. (See this option for further
# documentation).
#
# $1: The dimensions of the icon to be installed in `XxY` format. They should
#     be quadratic.
# $2: The path to the source icon that should be installed and/or converted.
#
# This function expects the $ICON_RESIZE_METHOD, $BUILD_NAME, $VENDOR_PREFIX,
# $THEME_ATTRIBUTE_FILE and CII_ERROR to be set. The theme attribute file must
# be parsed.
#
# The function sets the "static" variable $IITBM_PREVIOUS_ENTRIES to keep track
# of the distances from previous directories. It should not be changed.
#
# After execution of this function $BEST_MATCH, $BEST_MATCH_DISTANCE and
# $BEST_MATCH_SIZE will contain the directory the icon was installed, that
# directory's distance to the desired distance $1 and the size of that directory
# respectively.
install_icon_to_best_match() {
    # Some unnecessary checks
    IITBM_SIZE="$(echo "$1" | cut -dx -f1)"
    set_if_unset IITBM_PREVIOUS_ENTRIES ''
    if [ "$(echo "$1" | cut -dx -f2)" != "$IITBM_SIZE" ]; then
        log 'warning' "Icon is not quadratic ($1). Using x-dimension."
    fi

    IITBM_ERROR=false
    IITBM_NEW_DIR=false
    if [ "$CII_ERROR" = false ]; then
        find_best_icon_size_match "$IITBM_SIZE"
    else
        BEST_MATCH=
        BEST_MATCH_SIZE=
        BEST_MATCH_DISTANCE=
        IITBM_ERROR=true
    fi

    # There may have been a previous installation in the same directory that was
    # better. Handle that… and no directories at all…
    case "$ICON_SIZE_HANDLING" in
        convert|move)
            if [ "$IITBM_ERROR" = false ] && [ -z "$BEST_MATCH" ]; then
                log 'warning' "No directory entries in theme attribute file. Executing ‘closest-$ICON_SIZE_HANDLING’ not possible. Defaulting to ‘create-new-threshold’."
                ICON_SIZE_HANDLING='threshold'
            elif [ "$IITBM_ERROR" = false ]; then
                if echo "$IITBM_PREVIOUS_ENTRIES" | grep -qz "$(escape_grep_pattern "$BEST_MATCH")$"; then
                    IITBM_PREVIOUS_DISTANCE="$(echo "$IITBM_PREVIOUS_ENTRIES" | grep "$(escape_grep_pattern "$BEST_MATCH")$" | cut -d' ' -f1)"
                    if [ "$IITBM_PREVIOUS_DISTANCE" -le "$BEST_MATCH_DISTANCE" ]; then
                        log 'warning' "Found a previous icon that had the same best match directory and a better match distance. Not overwriting."
                        return 0
                    else
                        log 'info' "Found a previous icon that had the same best match directory and a worse match distance. Overwriting."
                        IITBM_PREVIOUS_ENTRIES="$(echo "$IITBM_PREVIOUS_ENTRIES" | sed "/$(escape_sed_pattern "$BEST_MATCH")\$/s/^[0-9]*/$BEST_MATCH_DISTANCE/")"
                    fi
                else
                    IITBM_PREVIOUS_ENTRIES="$IITBM_PREVIOUS_ENTRIES$BEST_MATCH_DISTANCE $BEST_MATCH$(printf '\n_')"; IITBM_PREVIOUS_ENTRIES="${IITBM_PREVIOUS_ENTRIES%_}"
                fi
            fi
            ;;
    esac

    IITBM_TARGET_DIR="$(escape_single_quote "$(unescape_desktop_string "$ICON_DIR/hicolor/$BEST_MATCH")")"
    IITBM_FILE_NAME="$(escape_single_quote "$VENDOR_PREFIX$BUILD_NAME.png")"
    IITBM_SOURCE="$(escape_single_quote "$2")"
    # Found a perfect match
    if [ "$IITBM_ERROR" = false ] && [ "$BEST_MATCH_DISTANCE" = 0 ]; then
        log 'debug' "Found perfect match in ‘$BEST_MATCH’ ($BEST_MATCH_SIZE)."
sudo_if_not_writeable "$ICON_DIR" << EOSUDO || IITBM_ERROR=true
        [ -d '$IITBM_TARGET_DIR' ] || mkdir ${LOG_VERBOSE:+"-v"} -p '$IITBM_TARGET_DIR'
        cp ${LOG_VERBOSE:+"-v"} '$IITBM_SOURCE' '$IITBM_TARGET_DIR/$IITBM_FILE_NAME'
EOSUDO
    elif [ "$IITBM_ERROR" != true ]; then
        # Did not find a perfect match. Handle it according to ‘--icon-size-not-existing’ setting
        # Try to execute as little as possible with sudo
        IITBM_TAF="$(escape_single_quote "$THEME_ATTRIBUTE_FILE")"
        IITBM_SED_ESCAPED_DIR="$(escape_sed_replacement "${IITBM_SIZE}x${IITBM_SIZE}/apps")"
        case "$ICON_SIZE_HANDLING" in
            convert) # Convert to closest match
                log 'debug' "Closest match in ‘$BEST_MATCH’ ($BEST_MATCH_SIZE) with distance $BEST_MATCH_DISTANCE."
sudo_if_not_writeable "$ICON_DIR" << EOSUDO || IITBM_ERROR=true
                [ -d '$IITBM_TARGET_DIR' ] || mkdir ${LOG_VERBOSE:+"-v"} -p '$IITBM_TARGET_DIR'
                magick convert '$IITBM_SOURCE' -$ICON_RESIZE_METHOD ${BEST_MATCH_SIZE}x${BEST_MATCH_SIZE} '$IITBM_TARGET_DIR/$IITBM_FILE_NAME'
EOSUDO
                ;;
            move) # Just move to closest match
                log 'debug' "Closest match in ‘$BEST_MATCH’ ($BEST_MATCH_SIZE) with distance $BEST_MATCH_DISTANCE."
sudo_if_not_writeable "$ICON_DIR" << EOSUDO || IITBM_ERROR=true
                [ -d '$IITBM_TARGET_DIR' ] || mkdir ${LOG_VERBOSE:+"-v"} -p '$IITBM_TARGET_DIR'
                cp ${LOG_VERBOSE:+"-v"} '$IITBM_SOURCE' '$IITBM_TARGET_DIR/$IITBM_FILE_NAME'
EOSUDO
                ;;
            scale) # Create new scaled folder
sudo_if_not_writeable "$THEME_ATTRIBUTE_FILE" << EOSUDO || IITBM_ERROR=true
                if grep -q '^ScaledDirectories\\s*=' '$IITBM_TAF'; then
                    sed -i '/^ScaledDirectories\\s*=\\s*./{s/=\\s*/&$IITBM_SED_ESCAPED_DIR,/;be};/^ScaledDirectories\\s*=\\s*$/{s/$/$IITBM_SED_ESCAPED_DIR/;be};:e' '$IITBM_TAF'
                else
                    sed -i '/^Directories\\s*=\\s*/s/$/\\nScaledDirectories=$IITBM_SED_ESCAPED_DIR/' '$IITBM_TAF'
                fi
                cat >> '$IITBM_TAF' << EOF

[${IITBM_SIZE}x${IITBM_SIZE}/apps]
Size=$IITBM_SIZE
Context=Applications
Type=Scalable
MinSize=$THEME_UPDATE_SCALE_MIN
MaxSize=$THEME_UPDATE_SCALE_MAX
EOF
EOSUDO
                IITBM_NEW_DIR=true
                ;;
            threshold) # Create new threshold folder
sudo_if_not_writeable "$THEME_ATTRIBUTE_FILE" << EOSUDO || IITBM_ERROR=true
                sed -i '/^Directories\\s*=\\s*./{s/=\\s*/&$IITBM_SED_ESCAPED_DIR,/;be};/^Directories\\s*=\\s*$/{s/$/$IITBM_SED_ESCAPED_DIR/;be};:e' '$IITBM_TAF'
                cat >> '$IITBM_TAF' << EOF

[${IITBM_SIZE}x${IITBM_SIZE}/apps]
Size=$IITBM_SIZE
Context=Applications
Type=Threshold
Threshold=$THEME_UPDATE_THRESHOLD
EOF
EOSUDO
                IITBM_NEW_DIR=true
                ;;
            fixed) # Create new fixed folder
sudo_if_not_writeable "$THEME_ATTRIBUTE_FILE" << EOSUDO || IITBM_ERROR=true
                sed -i '/^Directories\\s*=\\s*./{s/=\\s*/&$IITBM_SED_ESCAPED_DIR,/;be};/^Directories\\s*=\\s*$/{s/$/$IITBM_SED_ESCAPED_DIR/;be};:e' '$IITBM_TAF'
                cat >> '$IITBM_TAF' << EOF

[${IITBM_SIZE}x${IITBM_SIZE}/apps]
Size=$IITBM_SIZE
Context=Applications
Type=Fixed
EOF
EOSUDO
                IITBM_NEW_DIR=true
                ;;
            raw)
                IITBM_NEW_DIR=true
                ;;
            *)
                log 'error' "Unknown value for ICON_SIZE_HANDLING: '$ICON_SIZE_HANDLING'!" && exit 1
        esac
    fi

    if [ "$IITBM_ERROR" = true ] || [ "$IITBM_NEW_DIR" = true ]; then
        [ "$IITBM_ERROR" = true ] && log 'warning' "Could not execute METHOD. Falling back to ‘only-create’."
        BEST_MATCH_SIZE=$IITBM_SIZE
        BEST_MATCH="${IITBM_SIZE}x${IITBM_SIZE}/apps"
        BEST_MATCH_DISTANCE=0
        IITBM_TARGET_DIR="$(escape_single_quote "$(unescape_desktop_string "$ICON_DIR/hicolor/$BEST_MATCH")")"
        log 'debug' "Creating entry ‘$BEST_MATCH’ ($BEST_MATCH_SIZE) of type $ICON_SIZE_HANDLING."
sudo_if_not_writeable "$ICON_DIR" << EOSUDO
        [ -d '$IITBM_TARGET_DIR' ] || mkdir ${LOG_VERBOSE:+"-v"} -p '$IITBM_TARGET_DIR'
        cp ${LOG_VERBOSE:+"-v"} '$IITBM_SOURCE' '$IITBM_TARGET_DIR/$IITBM_FILE_NAME'
EOSUDO
    fi
    unset IITBM_FILE_NAME IITBM_TARGET_DIR IITBM_SOURCE IITBM_SIZE IITBM_NEW_DIR\
        IITBM_ERROR IITBM_TAF IITBM_SED_ESCAPED_DIR IITBM_INNER_DIR IITBM_PREVIOUS_DISTANCE
}

# Installs the provided icon file locally (in the game's directory) or globally
# (in the provided icon path under $BUILD_NAME) and converts it to ‘.png’ if
# necessary.
# If the icon is installed globally, the icons will be installed as the ‘hicolor’
# theme, otherwise a folder ‘icons’ will be created in the game's directory.
# If the `magick convert` and `identify` programs from the ‘ImageMagick’ suite are
# not installed, the pure icon file will be used.
#
# $1: contains the icon file to be processed. It must be provided and exist.
#     The icon should be quadratic (the dimensions will not be checked
#     by the script).
#
#
# This function expects the $BUILD_NAME, $INSTALL, $ICON_ICNS and
# $VENDOR_PREFIX variables to be set. If $INSTALL is ‘true’ $ICON_DIR has
# to be set, otherwise $LOCATION_AGNOSTIC has to be set. In this case
# $ICON_DOWNLOADED and $RENPY_ROOT_DIR have to be set. If $LOCATION_AGNOSTIC is
# ‘yes’ $LOCATION_AGNOSTIC_SEARCH_DIR additionally ha to be set.
#
# If the function terminates successfully, it will set $ICON accordingly.
convert_install_icon() {
    [ -z "$1" ] && ICON= && return
    [ ! -f "$1" ] && log 'error' 'Icon must exist!' && exit 1

    if [ "$ICON_ICNS" = 'true' ] && has icns2png || has magick; then
        if has mktemp; then
            CII_DIR="$(mktemp -d)"
            # In case the name contains any weird characters like spaces or new lines
            CII_TEMP_ICON_PATH="$(mktemp -u 'renpy_deskgen_iconXXXXXXXXXX' --tmpdir)"
            CII_FIFO="$(mktemp -u)"
        else
            CII_DIR="/tmp/renpy_deskgen_icon_dir"
            [ -d "$CII_DIR" ] || mkdir ${LOG_VERBOSE:+"-v"} "$CII_DIR"
            CII_TEMP_ICON_PATH="/tmp/renpy_deskgen_icon"
            CII_FIFO="/tmp/renpy_deskgen_fifo"
        fi
        ln ${LOG_VERBOSE:+"-v"} -s "$1" "$CII_TEMP_ICON_PATH"
        CII_FILE_TYPE="$(file --extension -b "$CII_TEMP_ICON_PATH" | cut -d/ -f1)"

        if [ "$ICON_ICNS" = true ] && has icns2png; then
            # Handle icns and convert to expected format
            CII_SIZES="$(icns2png -x "$CII_TEMP_ICON_PATH" -o "$CII_DIR" |\
                grep '^\s*Saved' | cut -d' ' -f7)"
            CII_ICON_NO=0
            echo "$CII_SIZES" | while read -r CII_ICON_INFO; do
                CII_ICON_INFO="${CII_ICON_INFO%.}" # icns2png does correct punctuation..
                mv ${LOG_VERBOSE:+"-v"} "$CII_ICON_INFO" "$CII_DIR/$BUILD_NAME-$CII_ICON_NO.png"
                CII_ICON_NO=$((CII_ICON_NO+1))
            done
            CII_SIZES="$(echo "$CII_SIZES" | cut -d'/' -f4 | cut -d'_' -f4 | cut -dx -f1-2)"
        else
            magick convert "$CII_FILE_TYPE:$CII_TEMP_ICON_PATH" "$CII_DIR/$BUILD_NAME.png"
            CII_SIZES="$(magick identify "$CII_FILE_TYPE:$CII_TEMP_ICON_PATH" | cut -d' ' -f3)"
        fi

        # Only parse this if we actually need this
        CII_ERROR=false
        if [ "$INSTALL" = yes ]; then
            find_theme_attribute_file
            if [ -n "$THEME_ATTRIBUTE_FILE" ]; then
                log 'info' "Found theme attribute file ‘$THEME_ATTRIBUTE_FILE’."
                parse_theme_attribute_file || CII_ERROR=true
            else
                log 'error' "Could not find theme attribute file."
                CII_ERROR=true
            fi
            if [ "$CII_ERROR" = true ]; then
                log 'error' "Could not parse theme attribute file${THEME_ATTRIBUTE_FILE:+" ‘$THEME_ATTRIBUTE_FILE’"}."
            fi
        fi

        CII_ICON_NO=0 # .ico/.icns files may contain multiple files, that are created with a number suffix by `magick convert`
        CII_BEST_48x48_MATCH=
        mkfifo "$CII_FIFO"
        [ -f  "$CII_DIR/$BUILD_NAME.png" ] && mv  "$CII_DIR/$BUILD_NAME.png"  "$CII_DIR/$BUILD_NAME-0.png" # force suffix for easier processing
        # create a folder for each resolution according to the specification
        echo "$CII_SIZES" > "$CII_FIFO"&
        while read -r CII_ICON_INFO; do
            if [ "$INSTALL" = yes ]; then
                install_icon_to_best_match "$CII_ICON_INFO" "$CII_DIR/$BUILD_NAME-$CII_ICON_NO.png"
                if [ -z "$CII_BEST_48x48_MATCH" ]; then
                    CII_BEST_48x48_MATCH=$CII_ICON_NO
                    CII_BEST_48x48_MATCH_DISTANCE="$((48-BEST_MATCH_SIZE))"
                    CII_BEST_48x48_MATCH_DISTANCE="${CII_BEST_48x48_MATCH_DISTANCE#-}"
                else
                    BEST_MATCH_DISTANCE="$((48-BEST_MATCH_SIZE))" #  Misuse this variable to avoid creating new ones
                    BEST_MATCH_DISTANCE="${BEST_MATCH_DISTANCE#-}"
                    if [ "$BEST_MATCH_DISTANCE" -lt "$CII_BEST_48x48_MATCH_DISTANCE" ]; then
                        rm ${LOG_VERBOSE:+"-v"} "$CII_DIR/$BUILD_NAME-$CII_BEST_48x48_MATCH.png"
                        CII_BEST_48x48_MATCH=$CII_ICON_NO
                        CII_BEST_48x48_MATCH_DISTANCE="$BEST_MATCH_DISTANCE"
                    else
                        rm ${LOG_VERBOSE:+"-v"} "$CII_DIR/$BUILD_NAME-$CII_ICON_NO.png"
                    fi
                fi
            else
                if [ "$LOCATION_AGNOSTIC" = yes ]; then
                    CII_ICON_OUT_DIR="$LOCATION_AGNOSTIC_SEARCH_DIR/icons/$CII_ICON_INFO"
                else
                    CII_ICON_OUT_DIR="$RENPY_ROOT_DIR/icons/$CII_ICON_INFO"
                fi
                CII_ICON_OUT_DIR="$(escape_single_quote "$CII_ICON_OUT_DIR")"
sudo_if_not_writeable "$CII_ICON_OUT_DIR" << EOSUDO
                [ -d '$CII_ICON_OUT_DIR' ] || mkdir ${LOG_VERBOSE:+"-v"} -p '$CII_ICON_OUT_DIR'
                mv ${LOG_VERBOSE:+"-v"} '$(escape_single_quote "$CII_DIR/$BUILD_NAME-$CII_ICON_NO.png")'\
                    '$CII_ICON_OUT_DIR$(escape_single_quote "/$VENDOR_PREFIX$BUILD_NAME.png")'
EOSUDO
            fi
            CII_ICON_NO=$((CII_ICON_NO+1))
        done < "$CII_FIFO"
        rm "$CII_FIFO"

        if [ "$INSTALL" = yes ]; then
            ICON="$VENDOR_PREFIX$BUILD_NAME"
            if [ "$ICON_CREATE_48x48" = true ] && [ "$CII_BEST_48x48_MATCH_DISTANCE" != 0 ]; then
                log 'info' 'Default icon size 48×48 not found. Creating it.'
                magick convert "$CII_DIR/$BUILD_NAME-$CII_BEST_48x48_MATCH.png" -"$ICON_RESIZE_METHOD" '48x48'\
                    "$CII_DIR/$BUILD_NAME-$CII_BEST_48x48_MATCH.png" # This overwrites the old icon with the new one
                install_icon_to_best_match '48x48' "$CII_DIR/$BUILD_NAME-$CII_BEST_48x48_MATCH.png"
            fi
            rm ${LOG_VERBOSE:+"-v"} "$CII_DIR/$BUILD_NAME-$CII_BEST_48x48_MATCH.png"
        else
            CII_CURR="$PWD"
            if [ "$LOCATION_AGNOSTIC" = yes ]; then
                cd "$LOCATION_AGNOSTIC_SEARCH_DIR" || exit 1
            else
                cd "$RENPY_ROOT_DIR" || exit 1
            fi
            ICON="$PWD/$(find . 'icons' -iname '*.png' | sort -nr -t/ -k2 | head -n1)"
            cd "$CII_CURR" || exit 1
        fi
        rmdir ${LOG_VERBOSE:+"-v"} "$CII_DIR"
        rm ${LOG_VERBOSE:+"-v"} "$CII_TEMP_ICON_PATH"
    else
        if [ "$(dirname "$1")" = "$RENPY_ROOT_DIR" ] && [ "$LOCATION_AGNOSTIC" = yes ]; then
            CII_ICON_OUT_DIR="$(escape_single_quote "$LOCATION_AGNOSTIC_SEARCH_DIR/.${VENDOR_PREFIX}icons")"
sudo_if_not_writeable "$LOCATION_AGNOSTIC_SEARCH_DIR" << EOSUDO
            [ -d '$CII_ICON_OUT_DIR' ] || mkdir ${LOG_VERBOSE:+"-v"} '$CII_ICON_OUT_DIR'
EOSUDO
            if [ "$ICON_DOWNLOADED" = true ]; then
sudo_if_not_writeable "$RENPY_ROOT_DIR" "$LOCATION_AGNOSTIC_SEARCH_DIR" << EOSUDO
                mv ${LOG_VERBOSE:+"-v"} '$(escape_single_quote "$1")'\
                    '$CII_ICON_OUT_DIR/$(escape_single_quote "$BUILD_NAME-downloaded-icon.png")'
EOSUDO
                ICON="$LOCATION_AGNOSTIC_SEARCH_DIR/.${VENDOR_PREFIX}icons/$BUILD_NAME-downloaded-icon.png"
            else
sudo_if_not_writeable "$RENPY_ROOT_DIR" "$LOCATION_AGNOSTIC_SEARCH_DIR" << EOSUDO
                cp ${LOG_VERBOSE:+"-v"} '$(escape_single_quote "$1")'\
                    '$CII_ICON_OUT_DIR/$(escape_single_quote "$BUILD_NAME.png")'
EOSUDO
                ICON="$LOCATION_AGNOSTIC_SEARCH_DIR/.${VENDOR_PREFIX}icons/$BUILD_NAME.png"
            fi
        else
            ICON="$1"
        fi
    fi
    unset CII_DIR CII_ICON_NO CII_ICON_INFO CII_ICON_OUT_DIR CII_CURR CII_TEMP_ICON_PATH CII_SIZES CII_FILE_TYPE
}

# Checks whether the provided directory is a Ren'Py game directory and sets
# $RENPY_ROOT_DIR, $RENPY_SCRIPT_PATH and $BUILD_NAME accordingly if they were
# unset previously.
# Essentially this function checks whether the directory contains ‘renpy/’,
# ‘game/’, ‘$BUILD_NAME.py’ and ‘$BUILD_NAME.sh.’
#
# $1: contains the directory to be checked. It is expected to be a existing
#     directory.
#
# If the function terminates successfully, it will set $RENPY_ROOT_DIR,
# $RENPY_SCRIPT_PATH and $BUILD_NAME accordingly if they were unset previously.
check_renpy_root_dir() {
    [ ! -d "$1" ] && log 'error' 'Directory must exist!' && exit 1
    if [ -d "$1/renpy" ] && [ -d "$1/game" ] &&\
        find "$1" -maxdepth 1 -type f -iname '*.py' | grep -q . &&\
        find "$1" -maxdepth 1 -type f -iname '*.sh' | grep -q .; then

        CRRD_SCRIPT="$(find "$1" -maxdepth 1 -type f -iname '*.sh' | sort | head -n1)"
        CRRD_PYTHON="$(find "$1" -maxdepth 1 -type f -iname '*.py' | sort | head -n1)"
        if file -b "$CRRD_SCRIPT" | grep -qi '^POSIX shell script'; then
            [ -z "${RENPY_ROOT_DIR+a}" ] && RENPY_ROOT_DIR="$1"
            [ -z "${RENPY_SCRIPT_PATH+m}" ] && RENPY_SCRIPT_PATH="$CRRD_SCRIPT"
            [ -z "${BUILD_NAME+e}" ] && BUILD_NAME="$(basename "$CRRD_SCRIPT" '.sh')"
        else
            unset CRRD_SCRIPT CRRD_PYTHON
            return 1
        fi
        if file -b "$CRRD_PYTHON" |  grep -qi '^Python script'; then
            [ "$BUILD_NAME" != "$(basename "$CRRD_PYTHON" '.py')" ] &&\
                log 'warning' "Found potential Ren'Py game directory, but file names"\
                     "of first shell and Python scripts (‘$CRRD_SCRIPT’,"\
                     "‘$CRRD_PYTHON’) do not match."
        else
            unset CRRD_SCRIPT CRRD_PYTHON
            return 1
        fi
    else
        unset CRRD_SCRIPT CRRD_PYTHON
        return 1
    fi
    unset CRRD_SCRIPT CRRD_PYTHON
    return 0
}

# Tries to find a Ren'Py game directory from a given starting point (see
# documentation of `check_renpy_root_dir`). The search spans over all parent
# directories and only  stops if the directory is found or ‘/’ is reached
# (unsuccessfully).
#
# $1: contains the starting point. It may be a file or directory but must exist.
#
# If the function terminates and the directory is found, $RENPY_ROOT_DIR,
# $RENPY_SCRIPT_PATH and $BUILD_NAME will be set if they were unset previously.
find_renpy_root_dir() {
    [ ! -e "$1" ] && log 'error' 'Start point must exist!' && exit 1
    FRRD_CURR_DIR="$1"
    [ -d "$FRRD_CURR_DIR" ] || FRRD_CURR_DIR="$(dirname "$FRRD_CURR_DIR")"

    while ! check_renpy_root_dir "$FRRD_CURR_DIR" && [ "$FRRD_CURR_DIR" != '/' ]; do
        FRRD_CURR_DIR="$(dirname "$FRRD_CURR_DIR")"
    done
    unset FRRD_CURR_DIR
}

# Tries to find an icon file in the given directory and the given (case
# insensitive) glob pattern for search
#
# $1: contains the directory to be checked. It is expected to be a existing
#     directory.
# $2: contains glob pattern used for the search. It will be given as an argument
#     for `find`'s `-iname` option.
# $3: Additionally check whether this command is installed.
#     (Optional. Defaults to 'magick' if installed or 'file' otherwise)
#     If 'magick' additionally check whether ImageMagick can handle it.
#     If 'file' additionally check if MIME type is an image.
#
# If the function terminates successfully, it will set $RAW_ICON accordingly to the
# first found file.
find_icon_file_glob() {
    [ ! -d "$1" ] && log 'error' 'Directory must exist!' && exit 1
    if [ -z "${3:-}" ]; then
        if has magick; then
            set -- "$1" "$2" 'magick'
        else
            set -- "$1" "$2" 'file'
        fi
    fi
    FIFG_ESCAPE="$(escape_single_quote "$3")"

    # OMG correct file handling in UNIX…
    RAW_ICON="$(find "$1" -type f -iname "$2" -exec /bin/sh -c "$(cat << EOF
    set -eu
    has() { # Documentation above
        command -v "\$1" > /dev/null
    }
    if ! has '$FIFG_ESCAPE'; then # Die immediately
        exit
    fi
    for FIFG_FILE; do
        case '$FIFG_ESCAPE' in
            magick)
                FIFG_TYPE="\$(file --extension -b "\$FIFG_FILE" | cut -d/ -f1)"
                if [ "\$FIFG_TYPE" = '???' ]; then
                    FIFG_TYPE=''
                else
                    FIFG_TYPE="\$FIFG_TYPE:"
                fi
                if magick identify "\$FIFG_TYPE\$FIFG_FILE" >/dev/null 2>&1; then
                    printf '%s' "\$FIFG_FILE"
                    break
                fi
                ;;
            file)
                if file -b --mime-type "\$FIFG_FILE" | grep -qi '^image/'; then
                    printf '%s' "\$FIFG_FILE"
                    break
                fi
                ;;
            icns2png)
                if icns2png -l "\$FIFG_FILE" >/dev/null 2>&1; then
                    printf '%s' "\$FIFG_FILE"
                    break
                fi
                ;;
            *)
                if file -b --mime-type "\$FIFG_FILE" | grep -qi '^image/'; then
                    printf '%s' "\$FIFG_FILE"
                    break
                fi
                ;;
        esac
    done
EOF
    )" /bin/sh '{}' +; printf '_')"
    RAW_ICON="${RAW_ICON%_}"
    unset FIFG_FILE FIFG_TYPE FIFG_ESCAPE
}

# Tries to find a game icon in the game's directory.
# May also try to download RAPT's (https://github.com/renpy/rapt/) default icon
# if the user desires to do so.
#
# This function expects the $RENPY_ROOT_DIR, $BUILD_NAME,
# $ICON_DOWNLOAD_DEFAULT, $ICON_DOWNLOAD_DEFAULT_URL and $ICON_BROAD_SEARCH
# variables to be set.
#
# If the function terminates successfully, it will set $RAW_ICON, $ICON_ICNS and
# $ICON_DOWNLOADED accordingly.
find_icon_file() {
    ICON_ICNS='false'
    ICON_DOWNLOADED='false'
    [ "$ICON_DISABLED" = true ] && RAW_ICON='' && return
    # Search for common Ren'Py icon names in descending order of complexity
    [ -z "${RAW_ICON:+s}" ] && find_icon_file_glob "$RENPY_ROOT_DIR" 'icon.*'
    [ -z "${RAW_ICON:+h}" ] && find_icon_file_glob "$RENPY_ROOT_DIR" 'window_icon.*'
    [ -z "${RAW_ICON:+d}" ] && find_icon_file_glob "$RENPY_ROOT_DIR" '*.ico' # Windows
    if [ -z "${RAW_ICON:+r}" ]; then # Mac
        find_icon_file_glob "$RENPY_ROOT_DIR" '*.icns' 'icns2png'
        [ -n "${RAW_ICON:+e}" ] && ICON_ICNS='true'
    fi
    [ -z "${RAW_ICON:+l}" ] && find_icon_file_glob "$RENPY_ROOT_DIR" "android-icon_foreground.*"
    [ -z "${RAW_ICON:+l}" ] && find_icon_file_glob "$RENPY_ROOT_DIR" "$BUILD_NAME.*" # Hopefully the name is not too generic…
    [ -z "${RAW_ICON:+y}" ] && [ "$ICON_BROAD_SEARCH" = true ] &&\
        find_icon_file_glob "$RENPY_ROOT_DIR" '*icon*.*' # This may produce undesired results
    if [ -z "${RAW_ICON:+v}" ] && [ "$ICON_DOWNLOAD_DEFAULT" = true ] && has wget; then
        if has magick && has mktemp; then
            FIF_DL_FILE="$(mktemp --suffix=.png)" # Only needed temporarily
        elif has mktemp; then
            FIF_DL_FILE="$(mktemp -p "$RENPY_ROOT_DIR" --suffix=.png 'icon-XXXXXXXXXX')" # May has to be moved later
        else
            FIF_DL_FILE="$RENPY_ROOT_DIR/renpydeskgen-downloaded-icon.png" # May has to be moved later
        fi

        log 'info' "Downloading default icon to ‘$FIF_DL_FILE’."
sudo_if_not_writeable "$(dirname "$FIF_DL_FILE")" << EOSUDO
        wget ${LOG_VERBOSE:+"-v"} ${LOG_VERBOSE:-"-q"} '$(escape_single_quote "$ICON_DOWNLOAD_DEFAULT_URL")' -O '$(escape_single_quote "$FIF_DL_FILE")'
EOSUDO
        RAW_ICON="$FIF_DL_FILE"
        ICON_DOWNLOADED='true'
    fi
    [ -z "${RAW_ICON:+s}" ] && RAW_ICON='' # Set an empty string signalling that no icon was found
    unset FIF_DL_FILE
}

# Sets the values of $INSTALL_DIR (…/applications) and $ICON_DIR (…/icons) to
# their default values according to the specification if they are unset or empty.
# Using the value of $INSTALL_SYSTEM_WIDE the value of $XDG_DATA_DIRS or
# $XDG_DATA_HOME will be used respectively.
#
# This function expects the $INSTALL_SYSTEM_WIDE variable to be set.
#
# If the function terminates successfully, it will set $INSTALL_DIR and
# $ICON_DIR accordingly.
determine_storage_dirs() {
    if [ "$INSTALL_SYSTEM_WIDE" = true ]; then
        if [ -z "${XDG_DATA_DIRS+t}" ] || [ -z "$XDG_DATA_DIRS" ]; then
            DSD_DATA_DIR="/usr/local/share/"
        else
            # It behaves like $PATH so no escaping possible?
            DSD_DATA_DIR="$(echo "$XDG_DATA_DIRS" | cut -d: -f1)"
        fi
    else
        if [ -z "${XDG_DATA_HOME+m}" ] || [ -z "$XDG_DATA_HOME" ]; then
            DSD_DATA_DIR="$HOME/.local/share/"
        else
            DSD_DATA_DIR="$XDG_DATA_HOME"
        fi
    fi

    if [ -z "${ICON_DIR+o}" ] || [ -z "$ICON_DIR" ]; then
        ICON_DIR="$DSD_DATA_DIR/icons"
    fi
    if [ -z "${INSTALL_DIR+m}" ] || [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="$DSD_DATA_DIR/applications"
    fi
    unset DSD_DATA_DIR
}

# Checks whether the script is run from a terminal and enables/disables the GUI
# and system logging accordingly (if they are empty). If no GUI is available
# some good(?) defaults for user prompts will be set so that the script can
# sill run without interaction.
#
# This function expects the $GUI, $LOG_SYSTEM, $INSTALL, $UNINSTALL_REMOVE,
# $UNINSTALL and $LOCATION_AGNOSTIC variable to be set.
#
# If the function returns successfully, the variables above will be set
# appropriately.
check_user_interactable() {
    if [ ! -t 0 ]; then
        if has zenity && [ -z "$GUI" ]; then
            GUI=true
        elif ! has zenity || [ "$GUI" = false ]; then
            # set some default values
            [ -z "$INSTALL" ]           && INSTALL=no  # This hopefully prevents having to use sudo
            [ -z "$UNINSTALL" ]         && UNINSTALL=no
            [ -z "$UNINSTALL_REMOVE" ]  && UNINSTALL_REMOVE=no
            [ -z "$LOCATION_AGNOSTIC" ] && LOCATION_AGNOSTIC=yes
        fi
        if has logger && [ -z "$LOG_SYSTEM" ]; then
            LOG_SYSTEM=true
        fi
    else
        if [ -z "$GUI" ]; then
            GUI=false
        fi
        if [ -z "$LOG_SYSTEM" ]; then
            LOG_SYSTEM=false
        fi
    fi
}

# Parses a command line argument that is no an option or switch and is used by
# `parse_command_line_arguments`.
#
# $1: The argument to parse
#
# Tries to interpret argument as $RENPY_SCRIPT_PATH or $RAW_ICON respectively
# or will set the searching directory ($START_DIR) as an alternative
# and set the variables accordingly.
parse_non_option_command_line_argument() {
    if ! PNOCLA_TEMP="$(readlink -f "$1")"; then
        log 'error' 'File path must not be empty!' && exit 1
    fi
    if [ -d "$PNOCLA_TEMP"  ]; then
        if [ -z "${START_DIR:-}" ]; then
            START_DIR="$PNOCLA_TEMP"
        else
            log 'warning' "Starting directory already set! Not overwriting."
        fi
        return
    fi
    if [ -f "$PNOCLA_TEMP" ]; then
        if file -b --mime-type "$PNOCLA_TEMP" | grep -qi '^image/'; then
            if [ -z "${RAW_ICON:-}" ]; then
                RAW_ICON="$PNOCLA_TEMP"
                if has icns2png && icns2png -l "$RAW_ICON" >/dev/null 2>&1; then
                    ICON_ICNS='true'
                    return
                elif has magick; then
                    PNOCLA_TEMP="$(file --extension -b "$RAW_ICON" | cut -d/ -f1)"
                    if [ "$PNOCLA_TEMP" = '???' ]; then
                        PNOCLA_TEMP=''
                    else
                        PNOCLA_TEMP="$PNOCLA_TEMP:"
                    fi
                    if magick identify "$PNOCLA_TEMP$RAW_ICON" >/dev/null 2>&1; then
                        return
                    fi
                else
                    return
                fi
                PNOCLA_TEMP="$RAW_ICON"
                RAW_ICON='' # Wasn't a correct icon
            else
                log 'warning' "Icon already set! Not overwriting."
                return
            fi
        fi
        if file -b "$PNOCLA_TEMP" | grep -qi '^POSIX shell script'; then
            if [ -z "${RENPY_SCRIPT_PATH:-}" ]; then
                if ! check_renpy_root_dir "$(dirname "$PNOCLA_TEMP")"; then
                    log 'error' "Provided script is not contained in a Ren'Py game directory!" && exit 1
                fi
            else
                log 'warning' "Script already set! Not overwriting."
                return
            fi
        else
            log 'warning' "Expected script, icon or directory: ‘$PNOCLA_TEMP’. Using directory of file as starting directory…"
            if [ -z "${START_DIR:-}" ]; then
                START_DIR="$(dirname "$PNOCLA_TEMP")"
            else
                log 'warning' "Starting directory already set! Not overwriting."
            fi
        fi
    else
        log 'error' "No such file or directory: ‘$PNOCLA_TEMP’!" && exit 1
    fi
    unset PNOCLA_TEMP
}

# Parses the command line arguments of the script and sets the options
# accordingly. Short, long and key=value arguments are supported.
#
# $@: The arguments to parse
#
# Arguments that do not belong to an option are interpreted as $RENPY_SCRIPT_PATH
# or $RAW_ICON respectively or will set the searching directory
# ($START_DIR) as an alternative.
parse_command_line_arguments() {
    PCLA_END_OF_OPTIONS='false'
    while [ $# -gt 0 ]; do
        if [ "$PCLA_END_OF_OPTIONS" = true ]; then
            parse_non_option_command_line_argument "$1"
            shift
            continue
        fi
        case "$1" in
            -i|--install)
                INSTALL=yes
                ;;
            -I|--no-install)
                INSTALL=no
                ;;
            -u|--uninstall)
                UNINSTALL=yes
                ;;
            -U|--no-uninstall)
                UNINSTALL=no
                ;;
            --remove-empty-dirs)
                UNINSTALL_REMOVE=yes
                ;;
            --no-remove-empty-dirs)
                UNINSTALL_REMOVE=no
                ;;
            -a|--install-all-users)
                INSTALL_SYSTEM_WIDE=true
                ;;
            -A|--no-install-all-users)
                INSTALL_SYSTEM_WIDE=false
                ;;
            --version)
                if [ "$GUI" = true ] && has zenity; then
                    zenity --info --text="$VERSION_INFO" --title "Version: ${THIS_NAME%.sh}"  --no-wrap || true
                else
                    echo "$VERSION_INFO"
                fi
                exit 0
                ;;
            --icon-dir|--icon-dir=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--icon-dir’!"}"
                    shift
                fi
                [ -n "$PCLA_TEMP" ] && [ ! -d "$PCLA_TEMP" ] &&\
                    log 'error' 'Icon directory must exist!' && exit 1
                ICON_DIR="$(readlink -f "$PCLA_TEMP" || echo '')"
                ;;
            --installation-dir|--installation-dir=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--installation-dir’!"}"
                    shift
                fi
                [ -n "$PCLA_TEMP" ] && [ ! -d "$PCLA_TEMP" ] &&\
                    log 'error' 'Install directory must exist!' && exit 1
                INSTALL_DIR="$(readlink -f "$PCLA_TEMP" || echo '')"
                ;;
            -N|--display-name|-N=*|--display-name=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--display-name’!"}"
                    shift
                fi
                DISPLAY_NAME="$PCLA_TEMP"
                ;;
            -p|--vendor-prefix|-p=*|--vendor-prefix=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--vendor-prefix’!"}"
                    shift
                fi
                if ! echo "$PCLA_TEMP" | grep -q '^[a-zA-Z]*$'; then
                    log 'warning' 'A vendor prefix should only contain alpha'
                    'characters ([a-zA-Z]).'
                fi
                DISPLAY_NAME="$PCLA_TEMP"
                ;;
            --theme-attribute-file|--theme-attribute-file=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--theme-attribute-file’!"}"
                    shift
                fi
                [ -n "$PCLA_TEMP" ] && [ ! -f "$PCLA_TEMP" ] &&\
                    log 'error' 'Theme attribute file must exist!' && exit 1
                THEME_ATTRIBUTE_FILE="$(readlink -f "$PCLA_TEMP" || echo '')"
                ;;
            --icon-resize-method|--icon-resize-method=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--icon-resize-method’!"}"
                    shift
                fi
                PCLA_TEMP="$(echo "$PCLA_TEMP" | tr '[:upper:]' '[:lower:]')"
                case "$PCLA_TEMP" in
                    resize);; scale);; sample);;
                    *) log 'error' "Expected value ‘resize’, ‘scale’ or ‘sample’!" && exit 1
                esac
                ICON_RESIZE_METHOD="$PCLA_TEMP"
                ;;
            -H|--icon-size-not-existing-handling|-H=*|--icon-size-not-existing-handling=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--icon-size-not-existing-handling’!"}"
                    shift
                fi
                PCLA_TEMP="$(echo "$PCLA_TEMP" | tr '[:upper:]' '[:lower:]')"
                case "$PCLA_TEMP" in
                    c|closest-covert)
                        ICON_SIZE_HANDLING='convert'
                        ;;
                    m|closest-move)
                        ICON_SIZE_HANDLING='move'
                        ;;
                    f|create-new-fixed)
                        ICON_SIZE_HANDLING='fixed'
                        ;;
                    o|only-create)
                        ICON_SIZE_HANDLING='raw'
                        ;;
                    s*|create-new-scaled|create-new-scaled=*)
                        ICON_SIZE_HANDLING='scale'
                        if echo "$PCLA_TEMP" | grep -Fq '='; then
                            PCLA_TEMP="$(echo "$PCLA_TEMP" | cut -d= -f2)"
                        elif echo "$PCLA_TEMP" | grep -iq '^s.'; then
                            PCLA_TEMP="$(echo "$PCLA_TEMP" | cut -c2-)"
                        else
                            break
                        fi

                        if echo "$PCLA_TEMP" | grep -qE '^[0-9]+,[0-9]+$'; then
                            THEME_UPDATE_SCALE_MIN="$(echo "$PCLA_TEMP" | cut -d, -f1)"
                            THEME_UPDATE_SCALE_MAX="$(echo "$PCLA_TEMP" | cut -d, -f2)"
                        elif echo "$PCLA_TEMP" | grep -qE '^[0-9]+$'; then
                            THEME_UPDATE_SCALE_MAX="$PCLA_TEMP"
                        else
                            log 'error' "Invalid arguments. Not in format '^([0-9]+,)?[0-9]+$'!" && exit 1
                        fi
                        ;;
                    t*|create-new-threshold|create-new-threshold=*)
                        ICON_SIZE_HANDLING='threshold'
                        if echo "$PCLA_TEMP" | grep -Fq '='; then
                            PCLA_TEMP="$(echo "$PCLA_TEMP" | cut -d= -f2)"
                        elif echo "$PCLA_TEMP" | grep -iq '^t.'; then
                            PCLA_TEMP="$(echo "$PCLA_TEMP" | cut -c2-)"
                        else
                            break
                        fi

                        if echo "$PCLA_TEMP" | grep -qE '^[0-9]+$'; then
                            THEME_UPDATE_THRESHOLD="$PCLA_TEMP"
                        else
                            log 'error' "Invalid arguments. Not in format '^[0-9]+$'!" && exit 1
                        fi
                        ;;
                    *)
                        log 'error' "Unknown value for METHOD: ‘$PCLA_TEMP’!" && exit 1
                        ;;
                esac
                ;;
            -f|--create-default-icon-size)
                ICON_CREATE_48x48=true
                ;;
            -F|--no-create-default-icon-size)
                ICON_CREATE_48x48=false
                ;;
            --broad-icon-search)
                ICON_BROAD_SEARCH=true
                ;;
            --no-broad-icon-search)
                ICON_BROAD_SEARCH=false
                ;;
            --download-fallback-icon)
                ICON_DOWNLOAD_DEFAULT=true
                ! has wget && log 'warning' "Fallback icon won't be downloaded"\
                    "because \`wget\` is not installed."
                ;;
            --no-download-fallback-icon)
                ICON_DOWNLOAD_DEFAULT=false
                ;;
            --fallback-icon-url|--fallback-icon-url=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--fallback-icon-url’!"}"
                    shift
                fi
                ICON_DOWNLOAD_DEFAULT_URL="$PCLA_TEMP" # Wget will check it...
                ;;
            -c|--icon|-c=*|--icon=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--icon’!"}"
                    shift
                fi
                if ! PCLA_TEMP="$(readlink -f "$PCLA_TEMP")"; then
                    log 'error' 'Icon path must not be empty!' && exit 1
                fi
                if [ -f "$PCLA_TEMP" ] && file -b --mime-type "$PCLA_TEMP" | grep -qi '^image/'; then
                    RAW_ICON="$PCLA_TEMP"
                    if has icns2png && icns2png -l "$RAW_ICON" >/dev/null 2>&1; then
                        ICON_ICNS='true'
                    elif has magick; then
                        PCLA_TEMP="$(file --extension -b "$RAW_ICON" | cut -d/ -f1)"
                        if [ "$PCLA_TEMP" = '???' ]; then
                            PCLA_TEMP=''
                        else
                            PCLA_TEMP="$PCLA_TEMP:"
                        fi
                        if ! magick identify "$PCLA_TEMP$RAW_ICON" >/dev/null 2>&1; then
                            log 'error' 'Provided icon cannot be read by ImageMagick!'"$(\
                                ! has icns2png && echo " (Try installing \`icns2png\` if it is an Apple Icon Image. (\`.icns\`))" || true)" && exit 1
                        fi
                    fi
                else
                    log 'error' 'Provided icon is not an image!' && exit 1
                fi
                ;;
            -C|--no-icon)
                ICON_DISABLED=true
                ;;
            --no-no-icon) # Yes, this is a (semi-undocumented) thing.
                ICON_DISABLED=false
                ;;
            -s|--script|-s=*|--script=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--script’!"}"
                    shift
                fi
                if ! PCLA_TEMP="$(readlink -f "$PCLA_TEMP")"; then
                    log 'error' 'Script path must not be empty!' && exit 1
                fi
                unset BUILD_NAME RENPY_SCRIPT_PATH RENPY_ROOT_DIR # So they can be reset by `check_renpy_root_dir`
                if [ ! -f "$PCLA_TEMP" ] || ! file -b "$PCLA_TEMP" | grep -qi '^POSIX shell script'; then
                    log 'error' 'Provided script is not a POSIX shell script!' && exit 1
                elif ! check_renpy_root_dir "$(dirname "$PCLA_TEMP")"; then
                    log 'error' "Provided script is not contained in a Ren'Py game directory!" && exit 1
                fi
                ;;
            -d|--starting-dir|-d=*|--starting-dir=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--starting-dir’!"}"
                    shift
                fi
                if ! PCLA_TEMP="$(readlink -f "$PCLA_TEMP")"; then
                    log 'error' 'Directory path must not be empty!' && exit 1
                fi
                [ ! -d "$PCLA_TEMP" ] && log 'error' 'Starting directory must exist!' && exit 1
                START_DIR="$PCLA_TEMP"
                ;;
            --interactive)
                INSTALL=
                UNINSTALL=
                UNINSTALL_REMOVE=
                LOCATION_AGNOSTIC=
                ;;
            --non-interactive)
                INSTALL=yes
                UNINSTALL=no
                UNINSTALL_REMOVE=yes
                LOCATION_AGNOSTIC=yes
                ;;
            -y|--yes)
                INSTALL=yes
                UNINSTALL=yes
                UNINSTALL_REMOVE=yes
                LOCATION_AGNOSTIC=yes
                ;;
            -n|--no)
                INSTALL=no
                UNINSTALL=no
                UNINSTALL_REMOVE=no
                LOCATION_AGNOSTIC=no
                ;;
            -v|--current-version-search)
                LOCATION_AGNOSTIC=yes
                ;;
            -V|--no-current-version-search)
                LOCATION_AGNOSTIC=no
                ;;
            -S|--current-version-search-dir|-S=*|--current-version-search-dir=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--current-version-search-dir’!"}"
                    shift
                fi
                LOCATION_AGNOSTIC_SEARCH_DIR="$PCLA_TEMP" # Will be checked later
                ;;
            -l|--log-level|-l=*|--log-level=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--log-level’!"}"
                    shift
                fi
                PCLA_TEMP="$(echo "$PCLA_TEMP" | tr '[:upper:]' '[:lower:]')"
                case "$PCLA_TEMP" in
                    0|q|quiet)
                        LOG_LEVEL=0
                        ;;
                    1|e|error)
                        LOG_LEVEL=1
                        ;;
                    2|w|warning)
                        LOG_LEVEL=2
                        ;;
                    3|i|info)
                        LOG_LEVEL=3
                        ;;
                    4|d|debug)
                        LOG_LEVEL=4
                        LOG_VERBOSE='-v'
                        ;;
                    *)
                        log 'error' 'Unknown log level.'
                        ;;
                esac
                ;;
            -L|--gui-log-level|-L=*|--gui-log-level=*)
                if echo "$1" | grep -Fq '='; then
                    PCLA_TEMP="$(echo "$1" | cut -d= -f2-)"
                else
                    PCLA_TEMP="${2?"Expected an argument for ‘--gui-log-level’!"}"
                    shift
                fi
                PCLA_TEMP="$(echo "$PCLA_TEMP" | tr '[:upper:]' '[:lower:]')"
                case "$PCLA_TEMP" in
                    0|q|quiet)
                        LOG_LEVEL_GUI=0
                        ;;
                    1|e|error)
                        LOG_LEVEL_GUI=1
                        ;;
                    2|w|warning)
                        LOG_LEVEL_GUI=2
                        ;;
                    3|i|info)
                        LOG_LEVEL_GUI=3
                        ;;
                    4|d|debug)
                        LOG_LEVEL_GUI=4
                        ;;
                    *)
                        log 'error' 'Unknown GUI log level.'
                        ;;
                esac
                if [ "$LOG_LEVEL" -lt "$LOG_LEVEL_GUI" ]; then
                    LOG_LEVEL_GUI="$LOG_LEVEL"
                    log 'warning' 'GUI log level cannot be bigger than console'\
                        'log level.'
                fi
                ;;
            -g|--gui)
                GUI=true
                ! has zenity && log 'warning' "GUI will not be shown"\
                    "because \`zenity\` is not installed."
                ;;
            -G|--no-gui)
                GUI=false
                ;;
            --log-system)
                LOG_SYSTEM=true
                ;;
            --no-log-system)
                LOG_SYSTEM=false
                ;;
            -h|--help)
                if [ "$GUI" = true ] && has zenity; then
                    PCLA_TEMP="zenity --text-info --height=$GUI_HELP_HEIGHT --width=$GUI_HELP_WIDTH --title='Help: $(escape_single_quote "${THIS_NAME%.sh}")'"
                else
                    PCLA_TEMP="${PAGER:-$(has less && echo 'less' || echo 'cat'))}"
                    [ "$PCLA_TEMP" = 'less' ] && PCLA_TEMP='less -F'
                fi
                /bin/sh -c "$PCLA_TEMP" << EOF || true
$THIS_NAME Help:
A script to generate a desktop file for a given Ren'Py game according to the
freedesktop.org specification 1.1.  The user may choose whether they want to
install the generated desktop file or place it in the current directory.

Usage:
 $THIS_NAME [OPTION...] [FILE...]

Operation:
 The script at least needs a path to the start script for the game (usually
 called NAME.sh), a path to the icon to use or a directory to start the search
 for the Ren'Py game directory from.
 If multiple of these are given the script will first use the start script,
 then the directory, the icon and last the current directory to search for the
 game directory.
 Additionally, if the icon or start script are not given, the script will try
 to find them in the game directory.

 The script tries to install the desktop file and the icon to the standardised
 directories and create any needed directories. The icon will be converted to
 PNG and saved as NAME.

 By default, the desktop file will not execute the script directly but contain
 a script that tries to find the newest of them. For more details, see option
 ‘--current-version-search’.

 If any of the given paths contain ‘unusual characters’ like new lines, a
 launcher may behave not as expected. In this case it may be best to create
 hard links to the files that do not contain these characters in their path.
 For the current version search to work, the directory that contains the game
 script must also contain a Python script of the same name.
 There may also be problems for the script if the paths end with one or more
 new line characters because these get stripped by most shells. If problems
 occur, the same methods as above may be used when possible.
 If the game name contains new lines and lauchers misbehave, the option
 ‘--display-name’ can be used to force a better name.

 This script expects ‘/tmp’ to be writeable.

 The only optional dependency that should be installed regardless is the
 ImageMagick suite. If it is not, the whole icon handling part of the script
 will not execute and the direct path to the icon will be used. Because the
 format of the image could not be supported by the specification, it may be
 unusable. Also, because the path is absolute reinstalling the game may lead to
 the icon not being found, even if the desktop file was installed.

 Some more specific behaviour is documented in the appropriate options.

Options:
 All options support long names some also short names. Short options can be
 concatenated (e.g. ‘-iv’). If an option has an argument it can be provided as
 an additional argument or in \`-[-]KEY=VALUE\` format for both short and long
 options. These arguments are mostly case-sensitive. Additionally, all options
 can also be set via variables at the start of the script.
 The opposite effect of some options can be archived by inverting the case of a
 short option character or toggling the ‘no-’ prefix.

 Installation settings:
  Determines whether and how the desktop file should be installed. If settings
  are interactive and not set, the script will ask what to do interactively.
  -i, --install
        Install the generated desktop file to the INSTALLATION_DIR
        (see --installation-dir) and install the found icon to ICON_DIR
        (see --icon-dir). [interactive default]
  -I, --no-install
        Place the generated desktop file in the current directory and place the
        icon(s) in the game or current version search directory.
  -u, --uninstall
        Uninstall a previously installed desktop file and icon file(s). This
        has priority over an installation and quits the script afterwards.
  -U, --no-uninstall
        Do not uninstall. [interactive default]
  --remove-empty-dirs
        If empty directories are created while the icon file(s) are
        uninstalled, remove them too. [interactive default]
  --no-remove-empty-dirs
        Do not remove empty directories.
  -a, --install-all-users
        Install the desktop file and icon file(s) system wide, instead of only
        for the current user. This affects the automatic determination of
        INSTALL_DIR and ICON_DIR if they are empty.
        This does not move the game directory so it and the version search
        directory should still be readable by all users.
        [default if executed as super user]
  -A, --no-install-all-users
        Only install the desktop file and icon file(s) for the current user.
        This affects the automatic determination of INSTALL_DIR and ICON_DIR if
        they are empty. [default if not executed as super user]

 Start script, Icon and search directory settings:
  Set the parameters that are otherwise determined by context if given as a
  non-option explicitly. These take priority over the non-explicit versions.
  The evaluation order still applies.
  -s FILE, --script=FILE
        Set the game start script. It is usually called NAME.sh and must be a
        valid POSIX shell script and contained in a Ren'Py game directory.
  -d DIR, --starting-dir=DIR
        Set the directory from which to start the search for the Ren'Py game
        directory.
  -c FILE, --icon=FILE
        The file to use for the icon. The script will try to check whether
        ImageMagick can process the file if it is installed. To process the
        Apple Icon Image format, \`icns2png\` must be installed. If an Apple
        Icon Image format file should be found automatically, it must have the
        correct file extension \`.icns\`.

 Generation settings:
  -v, --current-version-search
        The generated desktop file will try to search for the newest installed
        version of the game (from the SEARCH_DIR). This may be a good option if
        the user installs a new version by unpacking the archive without
        ensuring that the path to the game start script stays the same.
        This may still not be fool proof in the case the name of the game
        (start script) changes, the change times of scripts do not reflect
        their versions or the user has two files NAME.sh and NAME.py in the
        same directory in the search space that do not belong to the game. It
        may also be relatively slow to find the script depending on how big the
        search space is.
        In these cases the user should re-run this script, use a direct path
        (see below) or update the ctime of the appropriate files using
        \`touch\`. [interactive default]
  -V, --no-current-version-search
        Use the direct path to the game start script in the desktop file.
  -S SEARCH_DIR, --current-version-search-dir=SEARCH_DIR
        Set the directory from which to search for the current version of the
        game. It is relative to the Ren'Py game directory so that arguments
        like three directories above the game directory (‘../../..’) are
        possible. If the value is empty, the directory defaults to the direct
        parent of the game directory (‘..’), so if all versions are unpacked to
        the same directory they should be found.
  -N STRING, --display-name=STRING
        Set a separate name for the desktop file (\`Name\` field in it) instead
        of trying to extract the configured name from the game files or using
        NAME if no name was found. This may be intersting if the game name
        contains unusual characters or no name was found.
 -p PREFIX, --vendor-prefix=PREFIX
        Set the vendor prefix. This is useful to prevent name conflicts and is
        used for the desktop file and installed icons. PREFIX defaults to
        ‘$VENDOR_PREFIX’ if unset. An empty value can be used to disable the
        vendor prefix.

 Storage settings:
  Set where and which files are created. If the set location is not accessible
  by the user $USER, this script will ask for the appropriate credentials.
  The script may also be executed as super user in that case.
  --icon-dir=ICON_DIR
        The directory that should be used to store the icon(s) when installing.
        This should be one of the standardised XDG icon directories, e.g.
        ‘\$XDG_DATA_HOME/icons’ to be findable by launchers. If this value is
        empty, an appropriate directory will be chosen automatically.
  --installation-dir=INSTALLATION_DIR
        The directory that should be used to store the desktop file when
        installing.  This should be one of the standardised XDG icon
        directories, e.g. ‘\$XDG_DATA_HOME/applications’ to be findable by
        launchers. If this value is empty, an appropriate directory will be
        chosen automatically.
  -f, --create-default-icon-size
        The specification strongly recommends to at least install an icon of
    size 48×48. Create this icon if it is not already present and install
        it.  What is actually done with the icon once it is created is affected
        by the setting of ‘--theme-update-handling’. [default]
        (Mnemonic: [f]ourty-eight)
  -F, --no-create-default-icon-size
        Do not create a 48×48 icon. (Mnemonic: [F]ourty-eight)
  -H METHOD, --icon-size-not-existing-handling=METHOD
        Set how to act if it is detected that an icon may not be recognised
        because it has dimensions that are not registered in the ‘hicolor’
        theme.  METHOD can be one of the following values:
        C, closest-convert
            Find the closest matching size and convert the icon to that size if
            necessary.
        M, closest-move
            Find the closest matching size and pretend that the icon has that
            size without converting it. This may not be compatible with some
            launchers, so they may not display the icon correctly.
        S[[MIN,]MAX], create-new-scaled[=[MIN,]MAX]
            Register the icon as a new scaled file size with a size range of
            MIN to MAX and update the attributes.
            MIN and MAX default to $THEME_UPDATE_SCALE_MIN and $THEME_UPDATE_SCALE_MAX respectively if not given.
            The values MIN and MAX determine the sizes the icons in this
            directory are allowed to be scaled to.
            If the configuration is located in a system directory, additional
            authorisation may be required. If the change is not recognised by
            the launcher the user may try setting the theme configuration
            manually with ‘--theme-attribute-file’ or try another METHOD.
        T[THRESHOLD], create-new-threshold[=THRESHOLD]
            Register the icon as a new threshold file size with a given
            THRESHOLD and update the theme attributes.
            THRESHOLD defaults to $THEME_UPDATE_THRESHOLD if not given.
            The value THRESHOLD determines the sizes icons in this directory
            are allowed to over or under the directory size.
            Has the same requirements as ‘create-new-scaled’.
        F, create-new-fixed
            Register the icon a new file size with exact dimension and update
            the theme attributes.
            Has the same requirements as ‘create-new-scaled’.
        O, only-create
            Only create the appropriate directories without registering them in
            the theme. This may result in the icon not being found.
            This is the fallback behaviour if the other METHODs fail.
        [default: ‘closest-convert’]
  --theme-attribute-file=FILE
        The theme configuration file to work with and potentially update. If
        the user does not have the permissions to edit the file, they must
        provide the appropriate credentials.
        If this is not set, the first file in the order dictated by the
        specification will be used to search for the ‘hicolor’ configuration.
        In the case that no file is found or the file is invalid
        ‘--icon-size-not-existing-handling’ will default to ‘only-create’.
  --icon-resize-method=METHOD
        Sets the method which is used by ‘--create-default-icon-size’ and
        ‘--icon-size-not-existing-handling=closest-convert’ to resize the
        icon(s).
        METHOD can be one of the following values:
        (These are all options of \`magick convert\`)
        resize
            Resize the icon using Lanczos or Mitchell interpolation.
        scale
            Resize the icon by averaging or replacing the pixels when shrinking
            or enlarging the image respectively.
            (Same as ‘-resize WxH -filter box’ in \`magick convert\`.)
        sample
            Resize the icon by skipping over or finding the nearest neighbour
            of pixels when shrinking or enlarging the image respectively.
            (Same as ‘-resize WxH -filter point’ in \`magick convert\`.)
        [default: ‘resize’]

 Icon settings:
  -C, --no-icon
        Do not use an icon. This option overwrites the ‘--icon’ option
        regardless of whether it was set implicitly or explicitly.
  --broad-icon-search
        Use the glob pattern ‘*icon*.*’ when searching for icons. This is very
        general and may match undesired results like ‘silicon-form.png’.
  --no-broad-icon-search
        Do not use ‘*icon*.*’ when searching. [default]
  --download-fallback-icon
        Download a default icon if no icon was found in the game directory.
        For the download the program \`curl\` must be installed.
  --no-download-fallback-icon
        Do not download a default icon, instead opting for using no icon at
        all.  [default]
  --fallback-icon-url=URL
        The URL of the default icon to download from. This defaults to the
        foreground of the Android icon from RAPT.

 Interaction settings:
  Sets what happens with INSTALL, UNINSTALL, REMOVE DIRECTORIES and CURRENT
  VERSION SEARCH and how the user interacts with the script.
  --interactive
        Force interactiveness by clearing the values.
  --non-interactive
        Force non-interactiveness by setting the defaults for all values. The
        switches ‘--[no-]install’, ‘--[no-]uninstall’,
        ‘--[no-]remove-empty-dirs’ and ‘--[no-]current-version-search’ can be
        used for a more fine-grain configuration.
  -y, --yes
        Assume ‘yes’ for all interactive prompts.
  -n, --no
        Assume ‘no’ for all interactive prompts.
  -g, --gui
        Explicitly enable a rudimentary GUI using \`zenity\`. If not explicitly
        enabled the script will try to turn this setting on if it detects that
        it is not run from a terminal.
        In the case that a GUI is not available (because \`zenity\` is not
        installed or the GUI is disabled explicitly before execution by setting
        the defaults at the start of the file), the script will set some
        reasonable defaults for the interactive prompts to make running it
        still possible. This may still fail if the user has to authenticate to
        access some files.
  -G, --no-gui
        Explicitly disable the rudimentary GUI.

 Miscellaneous:
  -h, --help
        Print this help to \`${PAGER:-$(has less && echo less || echo cat)}\` or to the GUI and exit.
  --version
        Print version information and exit.
  -l LEVEL, --log-level=LEVEL
        Possible values for LEVEL:
            quiet (0), error (1), warning (2), info (3), debug (4)
        If the log level is ‘debug’, all file system changing operations will
        be verbose and code executed with \`sudo\` will be printed before
        execution. [default: ‘info’]
  -L LEVEL, --gui-log-level=LEVEL
        Set for which log LEVELs to create extra GUI dialogues. The GUI LEVEL
        has the same possible values than the console LEVEL and must not be
        bigger than it. [default: ‘warning’]
  --log-system
        Also write logs to the system logs. This is the default when the script
        is not run from a terminal.
  --no-log-system
        Do not write logs to the system logs. This is the default when the
        script is run from a terminal.
  --    Do not treat following arguments as options.
EOF
                exit
                ;;
            --)
                PCLA_END_OF_OPTIONS='true'
                ;;
            -?|-?=*)
                log 'error>' "Unknown switch or option ‘$1’. Use ‘--’ to stop option parsing or prepend ‘./’ to files."
                log 'error>' "Valid short options: -[acdfghilnpsuvyACFGHINSUV]."
                log 'error'  "Try ‘-h’ for information about valid options."
                exit 1
                ;;
            --*)
                log 'error>' "Unknown switch or option ‘$1’. Use ‘--’ to stop option parsing or prepend ‘./’ to files."
                log 'error'  "Try ‘--help’ for information about valid options."
                exit 1
                ;;
            -*)
                # Split concatenated arguments. This is very simple so weird
                # behaviour in some constructed edge case is possible.
                PCLA_TEMP="$1"
                shift
                set -- '' "$(echo "$PCLA_TEMP" | cut -c1-2)" "$(echo "$PCLA_TEMP" | cut -c1,3-)" "$@"
                ;;
            *)
                parse_non_option_command_line_argument "$1"
                ;;
        esac
        shift
    done
    unset PCLA_TEMP PCLA_END_OF_OPTIONS
}

# Tries to determine the game directory it wasn't set by command line arguments
#and print it to the user.
#
# If the function terminates successfully, it will set $RENPY_ROOT_DIR,
# $RENPY_SCRIPT_PATH, and $BUILD_NAME.
determine_game_directory() {
    if [ -z "${RENPY_ROOT_DIR+m}" ] && [ -n "${START_DIR:-}" ]; then
        find_renpy_root_dir "$START_DIR"
    fi
    if [ -z "${RENPY_ROOT_DIR+´}" ] && [ -n "${RAW_ICON:-}" ]; then
        find_renpy_root_dir "$RAW_ICON"
    fi
    if [ -z "${RENPY_ROOT_DIR+b}" ] && has zenity && [ "$GUI" = true ]; then
        find_renpy_root_dir "$(zenity --file-selection --directory --filename '.' --title\
            "Select Ren'Py game directory (or starting point for search): ${THIS_NAME%.sh}"\
            ||  echo "$PWD")"
    fi
    if [ -z "${RENPY_ROOT_DIR+o}" ]; then # If everything fails, use current working directory
        find_renpy_root_dir "$PWD"
    fi

    [ -z "${RENPY_ROOT_DIR:+y}" ] && log 'error' "Could not find Ren'Py game"\
        "directory (root directory reached)." && exit 1
    log 'info' "Found Ren'Py game directory ‘$RENPY_ROOT_DIR’."

}

# Tries to determine the icon file if it wasn't set by command line arguments
# and print it to the user.
#
# If the function terminates successfully, it will set $RAW_ICON.
determine_icon_file() {
    find_icon_file
    if [ -n "$RAW_ICON" ]; then
        log 'info' "Found icon ‘$RAW_ICON’."
    else
        log 'info' "No icon found."
    fi
}

# Do the actual work of crating the desktop file and converting the icon if it
# is given. Prompt the user for interactive settings if they are not set. When
# a (presumably) previously installed desktop file with the correct name is
# found, uninstallation may also be possible.
#
# This function expects the $INSTALL_DIR, $BUILD_NAME, $RENPY_SCRIPT_PATH,
# $LOCATION_AGNOSTIC_SEARCH_DIR, $VENDOR_PREFIX and $RAW_ICON and variables to
# be set.
work() {
    [ -n "$VENDOR_PREFIX" ] && VENDOR_PREFIX="$VENDOR_PREFIX-"

    if [ -f "$INSTALL_DIR/$VENDOR_PREFIX$BUILD_NAME.desktop" ]; then
        if [ "$INSTALL" != yes ] || [ "$UNINSTALL" = yes ]; then
            [ "$UNINSTALL" = yes ] && log 'info' 'Found previously installed desktop file. Uninstalling and exiting.'
            [ "$UNINSTALL_REMOVE" = yes ] && log 'info' 'Removing resulting empty directories.'
            if prompt_user UNINSTALL 'Found previously installed desktop file. Uninstall and exit?' no; then
                uninstall
                exit
            fi
        fi
    fi

    determine_icon_file

    prompt_user LOCATION_AGNOSTIC 'Create a desktop file that searches for the current version?' yes || true
    prompt_user INSTALL 'Install the desktop file and icon(s)?' yes || true

    determine_location_agnostic_search_dir

    convert_install_icon "$RAW_ICON"

    create_desktop_file

    if [ "$INSTALL" = yes ]; then
        if has desktop-file-install; then
sudo_if_not_writeable "$INSTALL_DIR" << EOSUDO
            desktop-file-install --dir '$(escape_single_quote "$INSTALL_DIR")'\
                --delete-original '$(escape_single_quote "$DESKTOP_FILE")'
EOSUDO
        else
sudo_if_not_writeable "$INSTALL_DIR" << EOSUDO
            mv ${LOG_VERBOSE:+"-v"} '$(escape_single_quote "$DESKTOP_FILE")'\
                '$(escape_single_quote "$INSTALL_DIR/$VENDOR_PREFIX$BUILD_NAME.desktop")'
EOSUDO
            if has update-desktop-database; then
sudo_if_not_writeable "$INSTALL_DIR" << EOSUDO
                update-desktop-database ${LOG_VERBOSE:+"-v"} '$(escape_single_quote "$INSTALL_DIR")'
EOSUDO
            else
                log 'info' 'The desktop file database may has to be undated.'
            fi
        fi
    else
sudo_if_not_writeable "$PWD" << EOSUDO
        mv ${LOG_VERBOSE:+"-v"} '$(escape_single_quote "$DESKTOP_FILE")'\
            '$(escape_single_quote "$PWD/$VENDOR_PREFIX$BUILD_NAME.desktop")'
EOSUDO
        log 'info' "Created file '$PWD/$VENDOR_PREFIX$BUILD_NAME.desktop'."
    fi

    if [ "$LOCATION_AGNOSTIC" = no ]; then
        log 'info' "This script must be re-run if the path to ‘$RENPY_SCRIPT_PATH’ changes."
    else
        log 'info' "This script must be re-run if a new version is not installed somewhere in ‘$LOCATION_AGNOSTIC_SEARCH_DIR’."
    fi
}

# Cleans up function overarching changes and files that should be temporary.
# This function should be executed after the main bulk of work for the script is
# done or if the script is exited unexpectedly.
cleanup() {
    # Sudo stuff
    if [ -n "${SINW_ASKPASS+c}" ]; then
        [ -f "$SINW_ASKPASS" ]     && rm "$SINW_ASKPASS"
        [ -n "${SINW_ASKPASS:-}" ] && unset SUDO_ASKPASS
        unset SINW_ASKPASS
    fi
    
    # Other temporary files that may have not been removed
    if [ -n "${DESKTOP_FILE:+a}" ]; then
        [ -f "$DESKTOP_FILE" ] && rm ${LOG_VERBOSE:+"-v"} "$DESKTOP_FILE"
        if [ "$(dirname "$DESKTOP_FILE")" != '/tmp' ]; then
            rmdir ${LOG_VERBOSE:+"-v"} "$(dirname "$DESKTOP_FILE")"
        fi
    fi
    [ -n "${CII_DIR:+k}" ] && [ -d "$CII_DIR" ] && rm ${LOG_VERBOSE:+"-v"} -r "$CII_DIR"
    [ -n "${CII_TEMP_ICON_PATH:+e}" ] && [ -f "$CII_TEMP_ICON_PATH" ] && rm ${LOG_VERBOSE:+"-v"} "$CII_TEMP_ICON_PATH"
    [ -n "${CII_FIFO:+l}" ] && [ -p "$CII_FIFO" ] && rm ${LOG_VERBOSE:+"-v"} "$CII_FIFO"
    [ -n "${FIF_DL_FILE:+i}" ] && [ -f "$FIF_DL_FILE" ] && rm ${LOG_VERBOSE:+"-v"} "$FIF_DL_FILE"
    [ -n "${PTAF_FIFO:+e}" ] && [ -p "$PTAF_FIFO" ] && rm ${LOG_VERBOSE:+"-v"} "$PTAF_FIFO"
}

# Execute all the functions in the correct order.
main() {
    check_dependencies
    [ ! -w '/tmp' ] && log 'error' "The ‘/tmp’ directory must be existent and writeable! Try executing as super user." && exit 1
    check_user_interactable

    trap cleanup EXIT

    parse_command_line_arguments "$@"

    determine_storage_dirs
    determine_game_directory

    work
}

# It's nice to only call one function.
if [ "$IS_SOURCED" != true ]; then main "$@"; fi
