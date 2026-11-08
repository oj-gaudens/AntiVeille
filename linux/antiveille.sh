#!/usr/bin/env bash
# AntiVeille (Linux) - empêche la mise en veille du PC pendant une durée donnée.
# Usage : ./antiveille.sh            (demande la durée)
#         ./antiveille.sh 1h24min    (durée en argument)
# Formats : 1h24min | 1h24 | 2h | 45min | 84 (minutes) | 1:24 | 30s

parse_duree() {
    # Affiche la durée en secondes, ou retourne 1 si le format est inconnu.
    local t h m s
    t=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    [[ -z "$t" ]] && return 1
    if [[ "$t" =~ ^([0-9]+):([0-9]{1,2})$ ]]; then
        s=$(( 10#${BASH_REMATCH[1]} * 3600 + 10#${BASH_REMATCH[2]} * 60 ))
    elif [[ "$t" =~ ^([0-9]+)h(([0-9]+)(min|m)?)?$ ]]; then
        h=${BASH_REMATCH[1]}; m=${BASH_REMATCH[3]:-0}
        s=$(( 10#$h * 3600 + 10#$m * 60 ))
    elif [[ "$t" =~ ^([0-9]+)(min|m)?$ ]]; then
        s=$(( 10#${BASH_REMATCH[1]} * 60 ))
    elif [[ "$t" =~ ^([0-9]+)s(ec)?$ ]]; then
        s=$(( 10#${BASH_REMATCH[1]} ))
    else
        return 1
    fi
    (( s > 0 )) || return 1
    echo "$s"
}

PIDS=""
XSET_CHANGED=0

cleanup() {
    local p
    for p in $PIDS; do kill "$p" 2>/dev/null; done
    if (( XSET_CHANGED )); then xset s on +dpms 2>/dev/null; fi
}

fmt_reste() {
    printf '%02d:%02d:%02d' $(( $1 / 3600 )) $(( ($1 % 3600) / 60 )) $(( $1 % 60 ))
}

main() {
    local saisie secs="" fin now reste actifs=0 x11=0 jiggle=0

    echo "=== AntiVeille - garde le PC éveillé (Linux) ==="
    echo "Exemples de durée : 1h24min | 1h24 | 2h | 45min | 84 (minutes) | 1:24"
    echo

    if [[ $# -ge 1 ]]; then
        secs=$(parse_duree "$*") || { echo "Format non reconnu : $*" >&2; exit 1; }
    else
        while [[ -z "$secs" ]]; do
            read -r -p "Combien de temps ? " saisie || exit 1
            secs=$(parse_duree "$saisie") || { echo "Format non reconnu, réessaie."; secs=""; }
        done
    fi

    [[ -n "${DISPLAY:-}" && "${XDG_SESSION_TYPE:-}" != "wayland" ]] && x11=1

    trap cleanup EXIT
    trap 'echo; echo "Arrêté."; exit 130' INT TERM

    # 1) logind : bloque la veille système et l'inactivité
    if command -v systemd-inhibit >/dev/null 2>&1; then
        systemd-inhibit --what=idle:sleep --who="AntiVeille" \
            --why="Garde le PC éveillé" --mode=block sleep "$secs" &
        PIDS="$PIDS $!"; actifs=$((actifs + 1))
    fi

    # 2) GNOME : bloque l'écran de veille / verrouillage automatique
    if command -v gnome-session-inhibit >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        gnome-session-inhibit --inhibit idle:suspend --reason "AntiVeille" sleep "$secs" &
        PIDS="$PIDS $!"; actifs=$((actifs + 1))
    fi

    # 3) X11 : désactive l'économiseur d'écran / DPMS (restauré à la fin)
    if (( x11 )) && command -v xset >/dev/null 2>&1; then
        xset s off -dpms 2>/dev/null && { XSET_CHANGED=1; actifs=$((actifs + 1)); }
    fi

    # 4) X11 : petit mouvement de souris (1 pixel) toutes les 30 s
    if (( x11 )) && command -v xdotool >/dev/null 2>&1; then
        jiggle=1; actifs=$((actifs + 1))
    fi

    if (( actifs == 0 )); then
        echo "Aucune méthode disponible. Installe systemd (systemd-inhibit) ou xdotool." >&2
        exit 1
    fi

    fin=$(( $(date +%s) + secs ))
    printf 'Actif pendant %s - fin prévue à %s\n' "$(fmt_reste "$secs")" "$(date -d "@$fin" +%H:%M:%S 2>/dev/null)"
    echo "Ctrl+C pour arrêter."
    echo

    local tick=0
    while :; do
        now=$(date +%s); reste=$(( fin - now ))
        (( reste <= 0 )) && break
        if (( jiggle && tick % 30 == 0 )); then
            xdotool mousemove_relative -- 1 0 2>/dev/null
            sleep 0.1
            xdotool mousemove_relative -- -1 0 2>/dev/null
        fi
        printf '\rTemps restant : %s   ' "$(fmt_reste "$reste")"
        sleep 1; tick=$((tick + 1))
    done

    printf '\rTemps restant : 00:00:00   \n\nTerminé ! Le PC peut de nouveau se mettre en veille.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
