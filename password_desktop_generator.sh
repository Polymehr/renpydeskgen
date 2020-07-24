#!/bin/sh
[ ! -f  './PASSWORD.sh' ] && echo 'Execute this script in the directory that contains PASSWORD.sh.' >&2 && exit 1
cat > 'PASSWORD.desktop' << EOF
[Desktop Entry]
Version=1.1
Type=Application
Terminal=false
Exec=$PWD/PASSWORD.sh
Name=PASSWORD
GenericName=Visual Novel
Categories=Game
Keywords=entertainment;games;visualnovel
EOF

echo "Install desktop file to '$HOME/.local/share/applications'? (Y/n)"
read -r INSTALL
echo "$INSTALL" | grep -iq '^$\|^\s*ye\?s\?\s*$' && INSTALL=true || INSTALL=

if command -v identify > /dev/null && command -v convert > /dev/null; then
    convert  'game/gui/PASSWORD.ico' '/tmp/PASSWORD.png'
    ICONNO=0
    [ -f '/tmp/PASSWORD.png' ] && mv '/tmp/PASSWORD.png' '/tmp/PASSWORD-0.png'
    identify 'game/gui/PASSWORD.ico' |\
        while read -r ICON; do
            if [ "$INSTALL" ]; then
                ICONDIR="$HOME/.local/share/icons/hicolor/$(echo "$ICON" | cut -d' ' -f3)/apps"
            else
                ICONDIR="icons/$(echo "$ICON" | cut -d' ' -f3)"
            fi
            [ -d "$ICONDIR" ] || mkdir -vp "$ICONDIR"
            mv -v "/tmp/PASSWORD-$ICONNO.png" "$ICONDIR/PASSWORD.png"
            ICONNO=$((ICONNO+1))
    done
    if [ "$INSTALL" ]; then
        echo 'Icon=PASSWORD' >> 'PASSWORD.desktop'
    else
        echo "Icon=$PWD/$(find 'icons' -iname '*.png' | sort -nr -t/ -k2 | head -n1)" >> 'PASSWORD.desktop'
    fi
else
    echo "Icon=$PWD/game/gui/PASSWORD.ico" >> 'PASSWORD.desktop'
fi
[ "$INSTALL" ] &&\
    if command -v desktop-file-install > /dev/null; then
        desktop-file-install --dir "$HOME/.local/share/applications" --delete-original 'PASSWORD.desktop'
    else
        mv -v 'PASSWORD.desktop' "$HOME/.local/share/applications"
    fi
