# AntiVeille

Empêche la mise en veille de l'ordinateur pendant une durée donnée.
Tu tapes une durée (ex. `1h24min`), le PC reste éveillé, et il redevient normal à la fin. Rien à installer.

| Système | Dossier | Lancement |
|---|---|---|
| Windows 11 | [`windows/`](windows) | double-clic sur `Lancer_AntiVeille.bat` |
| Linux | [`linux/`](linux) | `./antiveille.sh` |
| macOS | [`macos/`](macos) | double-clic sur `AntiVeille.command` |

## Formats de durée

`1h24min` · `1h24` · `2h` · `45min` · `84` (minutes) · `1:24`

Sous Linux et macOS, on peut aussi passer la durée en argument : `./antiveille.sh 2h`.
`Ctrl+C` arrête le programme à tout moment.

## Comment ça marche

- **Windows** : `SetThreadExecutionState` + un micro-mouvement de souris.
- **Linux** : `systemd-inhibit` (veille et inactivité), `gnome-session-inhibit` si dispo, et sous X11 `xset` (économiseur d'écran) et `xdotool` (micro-mouvement). Le script utilise ce qui est présent sur la machine. Sous Wayland, `xdotool` ne marche pas, mais `systemd-inhibit` suffit en général.
- **macOS** : `caffeinate`, déjà inclus dans le système.

## Installation

```bash
git clone <url-du-depot>
cd AntiVeille
```

Linux :

```bash
chmod +x linux/antiveille.sh
./linux/antiveille.sh
```

macOS :

```bash
chmod +x macos/AntiVeille.command
./macos/AntiVeille.command
```

Si macOS bloque le double-clic (fichier téléchargé) : `xattr -d com.apple.quarantine macos/AntiVeille.command`.

## Limites

- Fermer le capot d'un portable peut quand même mettre en veille (réglage système).
- Le script ne contourne pas le verrouillage d'écran imposé par une politique d'entreprise.

## Licence

MIT, voir [LICENSE](LICENSE).
