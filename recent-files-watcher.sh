#!/bin/bash

# ============================================================================
# 🔧 KONFIGURATION UND DATEIPFADE
# ============================================================================

XBEL="$HOME/.local/share/recently-used.xbel"
DESKTOP_FILE="$HOME/.local/share/applications/recent-files.desktop"
ICON_PATH="$HOME/.local/share/icons/recent-files-custom.svg"
NAME="Zuletzt verwendet"
MAX_FILES=15

# ============================================================================
# 🎨 SVG-Icon schreiben (eingebettet)
# ============================================================================
write_embedded_icon() {
    mkdir -p "$(dirname "$ICON_PATH")"

    cat > "$ICON_PATH" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" version="1.1">
 <rect style="opacity:0.2" width="50" height="32" x="7" y="24" rx="2.5" ry="2.5"/>
 <path style="fill:#4877b1" d="M 7,44.5 C 7,45.885 8.115,47 9.5,47 H 54.5 C 55.885,47 57,45.885 57,44.5 V 17.5 C 57,16.115 55.885,15 54.5,15 H 29 V 12.5 C 29,11.115 27.885,10 26.5,10 H 9.5 C 8.115,10 7,11.115 7,12.5"/>
 <rect style="opacity:0.2" width="50" height="32" x="7" y="22" rx="2.5" ry="2.5"/>
 <rect style="fill:#e4e4e4" width="44" height="20" x="10" y="18" rx="2.5" ry="2.5"/>
 <rect style="fill:#5294e2" width="50" height="32" x="7" y="23" rx="2.5" ry="2.5"/>
 <path style="opacity:0.1;fill:#ffffff" d="M 9.5,10 C 8.115,10 7,11.115 7,12.5 V 13.5 C 7,12.115 8.115,11 9.5,11 H 26.5 C 27.885,11 29,12.115 29,13.5 V 12.5 C 29,11.115 27.885,10 26.5,10 Z M 29,15 V 16 H 54.5 C 55.89,16 57,17.115 57,18.5 V 17.5 C 57,16.115 55.89,15 54.5,15 Z"/>
 <path style="fill:#1d344f" d="M 32 27 A 12 12 0 0 0 20 39 A 12 12 0 0 0 32 51 A 12 12 0 0 0 44 39 A 12 12 0 0 0 32 27 z M 32 30 A 9 9 0 0 1 41 39 A 9 9 0 0 1 32 48 A 9 9 0 0 1 23 39 A 9 9 0 0 1 32 30 z M 30 33 L 30 41 L 38 41 L 38 38 L 33 38 L 33 33 L 30 33 z"/>
</svg>
EOF
}

# ============================================================================
# 🔓 URL-Decoding für file:// Pfade
# ============================================================================
url_decode() {
    printf '%b' "${1//%/\\x}"
}

# ============================================================================
# 🧠 Emoji je nach MIME-Typ
# ============================================================================
get_mime_icon() {
    local file="$1"
    local mime
    mime=$(xdg-mime query filetype "$file" 2>/dev/null)

    case "$mime" in
        text/plain) echo "📝" ;;
        application/pdf) echo "📕" ;;
        application/json|application/xml) echo "🧾" ;;
        application/zip|application/x-tar|application/x-compressed-tar) echo "📦" ;;
        inode/directory) echo "📁" ;;

        text/x-python|text/python) echo "🐍" ;;
        text/x-shellscript|application/x-shellscript|text/shellscript) echo "📜" ;;
        text/x-yaml|application/x-yaml|text/yaml|application/yaml) echo "⚙️" ;;
        text/x-csrc|text/x-c++src|text/x-c++|text/x-c) echo "🔧" ;;
        text/x-java) echo "☕" ;;
        text/x-javascript|application/javascript|text/javascript) echo "📟" ;;
        text/css) echo "🎨" ;;
        text/html) echo "🌐" ;;
        application/x-php) echo "🐘" ;;
        application/x-perl|text/x-perl) echo "🧬" ;;
        text/markdown) echo "📝" ;;
        application/sql|text/x-sql) echo "🗄️" ;;

        application/vnd.oasis.opendocument.text) echo "📝" ;;
        application/vnd.oasis.opendocument.spreadsheet) echo "📊" ;;
        application/vnd.oasis.opendocument.presentation) echo "📽️" ;;
        application/vnd.oasis.opendocument.graphics) echo "🎨" ;;
        application/vnd.oasis.opendocument.database) echo "🗃️" ;;
        application/vnd.oasis.opendocument.formula) echo "➗" ;;

        image/*) echo "🖼️" ;;
        video/*) echo "🎞️" ;;
        application/vnd.ms-excel|text/csv) echo "📊" ;;

        *) echo "📄" ;;
    esac
}

# ============================================================================
# 📂 Dateien nach 'modified' eindeutig und absteigend sortieren
# ============================================================================
parse_recent_files() {
    [[ -s "$XBEL" ]] || return

    awk '
        /<bookmark / {
            match($0, /href="file:\/\/([^"]+)"/, h)
            match($0, /modified="([^"]+)"/, m)
            if (h[1] && m[1]) {
                key = h[1]
                time = m[1]
                if (!(key in latest) || time > latest[key]) {
                    latest[key] = time
                }
            }
        }
        END {
            for (k in latest) {
                print latest[k] " " k
            }
        }
    ' "$XBEL" | sort -r | awk '{ print $2 }' | while read -r path; do
        file_path=$(url_decode "$path")
        if [[ -e "$file_path" ]]; then
            echo "$path"
            ((count++))
            [[ "$count" -ge "$MAX_FILES" ]] && break
        fi
    done
}

# ============================================================================
# 🧾 .desktop-Datei mit Actions generieren
# ============================================================================
generate_desktop_file() {
    local files=("$@")
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    {
        echo "[Desktop Entry]"
        echo "Name=$NAME"
        echo "Comment=Zuletzt aktualisiert: $timestamp"
        echo "Exec=nautilus recent:///"
        echo "Icon=$ICON_PATH"
        echo "Terminal=false"
        echo "Type=Application"
        echo "Categories=Utility;"
        echo -n "Actions="
        for i in "${!files[@]}"; do
            echo -n "file$i;"
        done
        echo ""
        echo ""

        for i in "${!files[@]}"; do
            local encoded="${files[$i]}"
            local file
            file=$(url_decode "$encoded")
            local icon
            icon=$(get_mime_icon "$file")
            local fname="$icon $(basename "$file")"

            echo "[Desktop Action file$i]"
            echo "Name=$fname"
            echo "Exec=sh -c 'xdg-open \"\$0\"' \"$file\""
            echo "OnlyShowIn=GNOME;"
            echo ""
        done
    } > "$DESKTOP_FILE"
}

# ============================================================================
# 👀 Überwache Änderungen an der XBEL-Datei
# ============================================================================
watch_recent_changes() {
    local last_mod
    last_mod=$(stat -c %Y "$XBEL")
    while true; do
        sleep 2
        local current_mod
        current_mod=$(stat -c %Y "$XBEL")
        if [[ "$current_mod" != "$last_mod" ]]; then
            echo "🔄 Änderung erkannt – aktualisiere Kontextmenü ..."
            recent_files=($(parse_recent_files))
            generate_desktop_file "${recent_files[@]}"
            last_mod="$current_mod"
        fi
    done
}

# ============================================================================
# ▶️ Initiale Ausführung
# ============================================================================
echo "🖼️  Schreibe eingebettetes Icon ..."
write_embedded_icon

echo "⚙️  Erstelle initiale .desktop-Datei ..."
recent_files=($(parse_recent_files))
generate_desktop_file "${recent_files[@]}"

echo "👀 Starte Überwachung von $XBEL ..."
watch_recent_changes

