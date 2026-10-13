<div align="center">

# Vialet

**Toutes les apps vialet.app, à portée de clic.**

[![Dernière version](https://img.shields.io/github/v/release/avialet/vialet?color=6A6E75&label=version)](https://github.com/avialet/vialet/releases/latest)
[![macOS 26](https://img.shields.io/badge/macOS-26%20Tahoe-F0A020)](#installation)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-2E9D6E)](LICENSE)

[**Télécharger le DMG**](https://github.com/avialet/vialet/releases/latest) · [Site](https://vialet.vialet.app)

</div>

## Ce que fait Vialet

Une seule icône dans la barre des menus pour toutes les apps vialet.app : un clic, et chaque app
est là avec sa plaque, ses actions rapides et ses mises à jour.

- **Toutes vos apps, un clic.** Chaque app installée, dans l'ordre du catalogue de vialet.app :
  un clic l'ouvre, ses actions rapides (« Nouvelle tâche », « Dicter »…) sont à côté.
- **Les mises à jour en un coup d'œil.** Un point corail sur l'icône quand une app a une nouvelle
  version ; « Mise à jour X.Y.Z disponible » l'ouvre et lui laisse l'installer.
- **Une barre des menus dégagée.** Les apps vialet.app masquent leur propre icône quand Vialet est
  installée (réglable dans chaque app). Aucune liste à tenir : une nouvelle app apparaît d'elle-même.

## Installation

**Prérequis :** un Mac Apple Silicon sous macOS 26 (Tahoe) ou plus récent.

1. Téléchargez `Vialet-X.Y.Z.dmg` depuis la [dernière version](https://github.com/avialet/vialet/releases/latest).
2. Ouvrez le DMG et glissez **Vialet** dans **Applications**, puis double-cliquez.
3. Au premier lancement, macOS indique qu'il n'a pas pu vérifier l'app (elle est signée
   sans certificat Apple Developer). Cliquez **Terminé** (pas « Placer dans la corbeille »),
   ouvrez **Réglages Système › Confidentialité et sécurité**, descendez jusqu'à
   « Vialet a été bloqué… », cliquez **Ouvrir quand même**, authentifiez-vous, puis **Ouvrir**.
   Cette étape n'a lieu qu'une fois par téléchargement. Dans le Terminal :

   ```bash
   xattr -d com.apple.quarantine /Applications/Vialet.app
   ```

Pour vérifier le fichier téléchargé, comparez son empreinte avec celle publiée dans la même version :

```bash
shasum -a 256 -c Vialet-X.Y.Z.dmg.sha256
```

### Mises à jour

Vialet consulte au lancement, puis toutes les 6 heures, la dernière version publiée sur GitHub de
Vialet et de chaque app installée. Pour Vialet, un clic dans son menu la télécharge, **vérifie son
empreinte SHA-256**, contrôle l'application qu'elle contient, la remplace et relance l'app. Pour les
autres apps, Vialet signale la version et l'app s'en charge elle-même. La recherche automatique se
désactive dans **Réglages › Mises à jour**.

## Notice

- **L'icône** : la plaque de vialet.app (un secteur par app) en tons de gris, comme les symboles
  du système. Un point corail signale une mise à jour en attente.
- **Le menu** : une ligne par app installée (sa plaque, son nom, sa version) ; un clic sur la ligne
  ouvre l'app, un clic sur une pastille lance son action rapide. Sous « À découvrir », les apps du
  catalogue pas encore installées (réglable). Échap ou un clic ailleurs le ferme.
- **Raccourci global** facultatif (⌃⌥⇧Espace par défaut, à activer dans les Réglages) : ouvre le menu.
- **Ordre des apps** : celui du catalogue de vialet.app (lu une fois par jour), puis alphabétique.
- Le lien `vialet://` ouvre le menu. Vialet n'a ni fenêtre principale ni icône dans le Dock :
  **Quitter Vialet** est dans son menu.

### Comment Vialet trouve les apps

Vialet lit les apps `fr.vialet.*` de `/Applications` et `~/Applications` (et leurs sous-dossiers
directs), puis la fiche que chaque app publie à son lancement dans
`~/Library/Application Support/Vialet/apps/<bundle id>.json` : teintes, glyphe, actions rapides
(format décrit dans le README de [VialetKit](https://github.com/avialet/vialetkit)). Une app jamais
lancée apparaît avec sa seule entrée « Ouvrir ». Le catalogue est gardé en cache dans
`~/Library/Application Support/Vialet/catalog.json`.

## Compiler depuis les sources

Il faut Swift 6.3 ou plus récent (les Command Line Tools suffisent, Xcode n'est pas nécessaire).

```bash
git clone https://github.com/avialet/vialet.git
cd vialet
make test      # tests du noyau
make run       # construit et lance l'app
make install   # installe dans /Applications
make release   # fabrique build/Vialet-X.Y.Z.dmg et son empreinte
```

L'icône et l'habillage du DMG viennent de l’outillage commun des apps vialet.app
(`scripts/plaque.swift`), cloné à côté de l'app (sinon `VIALETAPPS_PATH=<chemin>`) :

```bash
make icon         # icône : la plaque du hub (un secteur par app du catalogue ../apps-site)
make dmg-layout   # fond et disposition de la fenêtre du DMG, dans scripts/dmg (à committer)
```

| Dossier | Contenu |
|---|---|
| `Packages/VialetCore` | Noyau sans interface : catalogue, apps installées, liste du menu, mises à jour, icônes |
| `Vialet` | L'application (AppKit et SwiftUI) ; `App/Brand.swift` porte son identité |
| `scripts` | Assemblage de l'app et du DMG ; `scripts/dmg` : fond et disposition de sa fenêtre |
| `docs` | [Publier une version](docs/publier-une-version.md), [tests](docs/tests.md), notes de version |

Le socle commun (mises à jour, thème, raccourci global, panneau flottant) vient de
[VialetKit](https://github.com/avialet/vialetkit). Publier une version ne demande que de
modifier `VERSION` puis de pousser un tag `vX.Y.Z` : la CI construit et publie le DMG, et
les utilisateurs reçoivent la mise à jour dans l'app.

## Confidentialité

Vialet ne collecte rien et n'envoie aucune donnée. Ses seules requêtes réseau sont la lecture des
dernières versions publiées sur GitHub (Vialet et vos apps vialet.app) et celle du catalogue de
vialet.app, une fois par jour ; **Réglages › Mises à jour › Rechercher automatiquement** les coupe.

## Licence

[MIT](LICENSE) © 2026 Aurélien Vialet
