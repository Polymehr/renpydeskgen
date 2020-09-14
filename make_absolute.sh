#!/bin/sh
set -eu
# A companion script to renpy_desktop_generator.sh.
# If you want to configuere it, you have to set the variables using the
# enviroment.

# I'll reuse some functions to save some space
THIS_DIR="$(dirname "$(readlink -f "$0")")" # The directory this script is contained in
export IS_SOURCED='true'
# shellcheck source=./renpy_desktop_generator.sh
. "$THIS_DIR/renpy_desktop_generator.sh"

set_if_unset SCRIPT_DESKTOP_FILE 'renpy_desktop_generator.desktop' # The desktop file make absolute
set_if_unset SCRIPT_NAME 'renpy_desktop_generator.sh' # The script name to replace

# Makes all the references to renpy_desktop_generator.sh in
# renpy_desktop_generator.desktop absolute so that can be used by some file
# managers.
#
# This function expects the $THIS_DIR, $SCRIPT_NAME and $SCRIPT_DESKTOP_FILE
# variables to be set and the file nam in $SCRIPT_DESKTOP_FILE to exist in the
# same directory.
main() {
    check_user_interactable # This will maybe set some variables we don't care about
    CHECK_OPTIONAL_DEPENDENCIES='false'
    check_dependencies # If the user can't run the main script, running this is pointless

    [ ! -f "$THIS_DIR/$SCRIPT_DESKTOP_FILE"  ] && log 'error' 'No desktop file in directory.' && exit 1

    cp ${LOG_VERBOSE:+"-v"} "$THIS_DIR/$SCRIPT_DESKTOP_FILE" "$THIS_DIR/$SCRIPT_DESKTOP_FILE.bak"
    sed -i "/Exec\\s*=/s/$(escape_sed_pattern "./$SCRIPT_NAME")\\b/$(escape_sed_replacement "$THIS_DIR/$SCRIPT_NAME")/"\
        "$THIS_DIR/$SCRIPT_DESKTOP_FILE"

    log 'info' "Made desktop file absolute. Backup saved to ‘$THIS_DIR/$SCRIPT_DESKTOP_FILE.bak’."
}

# Call main function (this has no source filter, so be aware)
main "$@"
