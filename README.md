# PullTheTimer Pro Plus 3000 💧

Minuteur élégant dans la barre de menu macOS, réglé par un geste : tu tires une forme
fine qui s'étire, la durée s'affiche à côté.

## Le geste
Clique sur l'icône dans la barre de menu **et maintiens**, puis **tire vers le bas**.
Un fuseau lumineux s'étire — fin et fluide ; plus tu tires vite, plus il s'affine
(on sent l'étirement). La durée en minutes s'affiche à côté. Relâche : la forme se
rétracte, s'amincit en un fil et se dissout, puis le minuteur démarre.

- Sensibilité ~8 px = 1 min, jusqu'à 3 h.
- Pendant le décompte : l'icône est un fuseau qui **se vide** au fil du temps,
  avec le temps restant en `m:ss`.
- À la fin : alarme + notification + déclencheurs configurés.

## Menu (clic simple ou clic droit)
- Temps restant / Annuler le minuteur
- Préréglages : 5, 10, 15, 25, 45 minutes
- **Options…** (⌘,)
- Quitter

## Options
- **Ouvrir au démarrage** (login item via `SMAppService`).
- **Alarme** : choix d'un son système (ou aucun), bouton Tester.
- **Déclencheurs en fin de minuteur** (cumulables) :
  - Lancer une application (choisie via un sélecteur de fichiers).
  - Jouer de la musique — **Apple Music** (titre/playlist, ou vide = lecture) ou
    **Spotify** (URI `spotify:…` pour un titre précis, sinon reprend la lecture).
  - Ouvrir une page web (URL).
  - Fermer une application (par nom).
  - Mettre l'ordinateur en veille.
  - Éteindre l'ordinateur.

  Les actions système (veille/extinction) déclenchent une demande d'autorisation
  d'automatiser « System Events » au premier usage.

## Build
```bash
./build.sh          # → Dist/PullTheTimer Pro Plus 3000.app (universel arm64+x86_64, signé ad-hoc)
open Dist/PullTheTimer Pro Plus 3000.app
```
Cible : macOS 13+ (requis pour `SMAppService`).

## Architecture
- AppKit + SwiftUI (fenêtre Options hébergée via `NSHostingView`), un seul fichier
  `Sources/main.swift`, compilé avec `swiftc` (pas de Xcode).
- `LSUIElement` / `.accessory` : pas d'icône dans le Dock.
- `spindlePath(top:bottom:halfWidth:bias:)` : le fuseau (4 courbes de Bézier), réutilisé
  pour l'icône et l'overlay.
- `OverlayView` : boucle 60 fps, suivi lissé (sans rebond), la vitesse affine la forme
  et allonge la pointe basse ; au relâcher, dissolution en fil.
- Déclencheurs via `NSWorkspace` (apps/URL) et `osascript` (musique, quitter, veille,
  extinction).
- `preview.swift` : rend la forme/animation/icône en PNG (`swift preview.swift`) pour
  itérer sans cliquer dans la barre de menu.
