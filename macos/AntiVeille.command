#!/bin/bash
# AntiVeille (macOS) - empêche la mise en veille du Mac pendant une durée donnée.
# Double-clic sur ce fichier, ou : ./AntiVeille.command 1h24min
# Formats : 1h24min | 1h24 | 2h | 45min | 84 (minutes) | 1:24 | 30s
# Compatible bash 3.2 (celui fourni par macOS). Utilise caffeinate (inclus dans macOS).

parse_duree() {
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

CAFF_PID=""

cleanup() {
    [[ -n "$CAFF_PID" ]] && kill "$CAFF_PID" 2>/dev/null
}

fmt_reste() {
    printf '%02d:%02d:%02d' $(( $1 / 3600 )) $(( ($1 % 3600) / 60 )) $(( $1 % 60 ))
}

main() {
    local saisie secs="" fin now reste

    echo "=== AntiVeille - garde le Mac éveillé ==="
    echo "Exemples de durée : 1h24min | 1h24 | 2h | 45min | 84 (minutes) | 1:24"
    echo

    if ! command -v caffeinate >/dev/null 2>&1; then
        echo "caffeinate introuvable (ce script est prévu pour macOS)." >&2
        exit 1
    fi

    if [[ $# -ge 1 ]]; then
        secs=$(parse_duree "$*") || { echo "Format non reconnu : $*" >&2; exit 1; }
    else
        while [[ -z "$secs" ]]; do
            read -r -p "Combien de temps ? " saisie || exit 1
            secs=$(parse_duree "$saisie") || { echo "Format non reconnu, réessaie."; secs=""; }
        done
    fi

    trap cleanup EXIT
    trap 'echo; echo "Arrêté."; exit 130' INT TERM

    # -d : écran allumé, -i : pas de veille par inactivité, -m : disque actif
    caffeinate -d -i -m -t "$secs" &
    CAFF_PID=$!

    fin=$(( $(date +%s) + secs ))
    printf 'Actif pendant %s - fin prévue à %s\n' "$(fmt_reste "$secs")" "$(date -r "$fin" +%H:%M:%S)"
    echo "Ctrl+C pour arrêter (ou ferme la fenêtre)."
    echo

    while :; do
        now=$(date +%s); reste=$(( fin - now ))
        (( reste <= 0 )) && break
        printf '\rTemps restant : %s   ' "$(fmt_reste "$reste")"
        sleep 1
    done

    printf '\rTemps restant : 00:00:00   \n\nTerminé ! Le Mac peut de nouveau se mettre en veille.\n'
    sleep 3
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
