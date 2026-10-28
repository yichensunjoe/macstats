<div align="center">

[简体中文](../../README.md) · [English](README_en.md) · [繁體中文](README_zh-TW.md) · [日本語](README_ja.md) · [한국어](README_ko.md) · [Deutsch](README_de.md) · [Español](README_es.md) · **Français** · [Русский](README_ru.md) · [Português (Brasil)](README_pt-BR.md)

# MacStats Panel

### Le Moniteur d'activité, épinglé sur le bureau.

**CPU, mémoire, GPU, énergie, disque et réseau d'un coup d'œil, chaque valeur alignée sur le Moniteur d'activité.**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#installation)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#fonctionnement)
[![tests](https://img.shields.io/badge/tests-176%20passing-3fb950?style=flat-square)](#commandes)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#fonctionnement)

[Installation](#installation) · [Ce qui est affiché](#ce-qui-est-affiché) · [Deux surfaces](#deux-surfaces) · [Précision](#quel-point-de-précision-face-au-moniteur-dactivité) · [FAQ](#faq) · [Limites](#limites-connues)

**[Télécharger MacStats.zip](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)** · glissez-le dans `/Applications`, puis autorisez-le au premier lancement via Réglages Système → « Ouvrir quand même »

</div>

---

## Installation

[**Télécharger MacStats.zip**](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip) (environ 2,4 Mo, macOS 15+ sur Apple Silicon)

1. Décompressez et glissez `MacStats.app` dans `/Applications`
2. Le premier lancement est bloqué (**non notarisé**) : cliquez sur « OK » dans l'alerte, puis Réglages Système → Confidentialité et sécurité → « Ouvrir quand même » ; ou supprimez l'attribut de quarantaine en terminal. La raison et les deux voies sont dans les [notes d'installation](../install.md)
3. Le panneau apparaît sur le bureau. Pour le widget WidgetKit : clic droit sur le bureau → « Modifier les widgets » → recherchez « 系统监视 » (le nom du widget dans la galerie)

```bash
# Facultatif : retirez une fois l'attribut de quarantaine, ensuite un double-clic suffit
xattr -dr com.apple.quarantine /Applications/MacStats.app

# Ou via Homebrew
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats      # Homebrew 5+ exige de faire confiance explicitement aux taps tiers
brew install --cask macstats
```

Vérifiez le téléchargement avec `shasum -a 256 -c MacStats.zip.sha256` (l'empreinte est jointe à la release).

**Si l'installation échoue**

1. **Gatekeeper bloque l'ouverture** : utilisez l'une des voies ci-dessus (Réglages Système → « Ouvrir quand même », ou suppression de l'attribut de quarantaine). Si macOS indique que l'app est endommagée, le téléchargement est généralement incomplet : vérifiez le sha256 et retéléchargez ; si l'empreinte est bonne, essayez la suppression de l'attribut de quarantaine.
2. **Mauvaise architecture** : le paquet est réservé à Apple Silicon (arm64) ; il ne fonctionne pas sur Mac Intel et il n'existe pas de version Rosetta. `uname -m` doit afficher `arm64`.
3. **macOS trop ancien** : macOS 15 (Sequoia) ou ultérieur est requis. Vérifiez avec `sw_vers -productVersion`.
4. **Le widget n'apparaît pas** : vérifiez que l'app est dans `/Applications` (pas dans Téléchargements ni `~/Applications`) et qu'elle a été lancée au moins une fois, puis exécutez `killall chronod NotificationCenter` et rouvrez l'app. Une seule copie doit être enregistrée par Mac.
5. **Le widget reste sur l'ancienne version après mise à jour** : remplacer `MacStats.app` dans `/Applications` ne rafraîchit pas l'enregistrement de l'extension, qui peut continuer à charger l'ancienne compilation. Quittez l'app puis rouvrez-la ; si cela ne suffit pas, réenregistrez l'extension de force (`lsregister` + `pluginkit`, commandes dans les [notes d'installation](../install.md)). Si la version est bonne mais que le widget affiche encore l'ancien aspect, retirez-le via « Modifier les widgets » puis ajoutez-le de nouveau.
6. **Homebrew signale un untrusted tap** : depuis Homebrew 5, un tap tiers exige une confiance explicite : `brew trust yichensunjoe/macstats` avant `brew install --cask macstats` ; `brew untrust yichensunjoe/macstats` l'annule. Homebrew ne supprime pas la quarantaine : le premier lancement demande toujours l'autorisation ci-dessus.

<p align="center">
  <img src="../live-window.png" alt="Panneau MacStats : CPU, mémoire, GPU, énergie, disque, réseau et les trois processus les plus gourmands en mémoire" width="460" />
</p>

Le Moniteur d'activité affiche déjà tout. Le problème, c'est que c'est une fenêtre : il faut l'ouvrir, choisir un onglet, la ramener au premier plan. MacStats transforme ces mêmes six métriques en un panneau sombre qui reste sur le bureau, échantillonne chaque seconde, réorganise sa mise en page quand on le redimensionne, et fournit en plus un widget WidgetKit pour ceux qui préfèrent en poser un petit dans la grille du bureau.

Ce n'est volontairement pas un tableau de bord plus gros. Les métriques sont les cinq du Moniteur d'activité plus l'utilisation du GPU et la mémoire unifiée, ainsi qu'une courbe de 90 secondes, la charge par cœur, la répartition de la mémoire et les trois processus les plus gourmands. Le travail intéressant n'est pas le dessin, c'est **de faire sortir chaque chiffre identique à celui du Moniteur d'activité** : comparés côte à côte au même instant, la mémoire reste à moins de 0,2 Go et les compteurs cumulés de disque et de réseau concordent à l'octet près.

<p align="center">
  <img src="../compact-strip.png" alt="Bande large : CPU, mémoire, GPU, énergie, disque et réseau sur une ligne" width="620" />
  <br />
  <img src="../compact-strip-narrow.png" alt="Bande étroite : les mêmes six métriques se replient en grille 3 × 2" width="330" />
</p>

**Réduit à une bande, le panneau passe en mise en page minimale.** Sans cartes ni courbes : six métriques alignées, comme un témoin sous la barre des menus. Quand le panneau devient trop étroit pour une seule ligne, il se replie en grille 3 × 2 et les six restent visibles. À un rafraîchissement par seconde, l'app occupe environ 1 % d'un cœur et 80 Mo de mémoire résidente (mesuré sur arm64, macOS 26), et c'est le palier le plus léger à dessiner. C'est la forme par défaut à l'installation ; clic droit → « Déployer en panneau standard » ouvre le panneau complet, et le même élément le replie.

> [!NOTE]
> Le panneau flottant fonctionne sans configuration. La copie présente dans la galerie de widgets du système exige une signature Apple Development valide et une installation dans `/Applications` : ce sont des contraintes de `chronod`, pas des préférences. Voir [Extension de widget](#extension-de-widget).

## Compiler depuis les sources

Nécessite macOS 15 ou plus récent et les outils de ligne de commande Xcode (Swift 6). Aucune dépendance tierce, aucun projet Xcode.

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # compilation + paquet + installation dans /Applications + enregistrement du widget
open /Applications/MacStats.app
```

Au premier lancement, une petite valeur `CPU · Mémoire` apparaît dans la barre des menus et le panneau s'affiche sur le bureau.

- Clic gauche sur l'icône de la barre des menus : afficher ou masquer le panneau
- Clic droit sur le panneau : toujours au premier plan, épingler au bureau, traverser les clics, intervalle de rafraîchissement (1 / 2 / 5 s), nouvelle instance
- Glisser une zone vide pour le déplacer, la poignée en bas à droite pour le redimensionner ; la mise en page bascule entre Minimal / Compact / Standard / Détaillé
- Les préférences sont stockées dans le domaine `com.macstats.app` de l'app, la position et la taille survivent à un redémarrage

## Ce qui est affiché

| Métrique | Sur le panneau | Mesure |
|---|---|---|
| CPU | Grand total + utilisateur/système + courbe de 90 s + barres par cœur | Différences `host_processor_info`, même source que le Moniteur d'activité |
| Mémoire | Utilisée / totale, barre de pression, répartition App / Wired / compressée, cache | `vm_statistics64`, voir [Précision](#quel-point-de-précision-face-au-moniteur-dactivité) |
| Énergie | Watts dérivés du compteur d'énergie CPU, niveau et état de la batterie | Différences `ri_energy_nj` ; sans compteur, une estimation basée sur la charge est utilisée et signalée |
| Disque | Débit lecture/écriture, espace libre | Différences d'octets cumulés de `IOBlockStorageDriver` |
| Réseau | Débit montant/descendant, interface principale | Compteurs 64 bits de `NET_RT_IFLIST2` ; les débits excluent `lo0` |
| GPU | Grand chiffre d'utilisation + courbe de 90 s + mémoire unifiée utilisée / nombre de cœurs | `PerformanceStatistics` de `IOAccelerator` (`Device Utilization %`, `In use system memory`), même source que l'onglet GPU du Moniteur d'activité |
| Processus | Les 3 plus gourmands en mémoire (5 dans le grand widget) | `ri_phys_footprint` via `proc_pid_rusage` |

<p align="center">
  <img src="../widget-medium.png" alt="Widget moyen : CPU avec barres par cœur, plus des tuiles mémoire, disque, réseau, énergie et GPU si disponible" width="620" />
  <img src="../widget-small.png" alt="Petit widget : grand chiffre CPU avec courbe" width="280" />
</p>

## Historique sur 24 heures et alertes de charge prolongée

Les panneaux standard et détaillé comportent une ligne « Dernières 24 heures » : courbes du CPU, de la mémoire et du GPU, chacune avec son pic sur 24 heures. Le pic est cliquable : il ouvre l'heure et la valeur de ce pic, ainsi que **les trois processus les plus gourmands en CPU à cet instant** (nom, % CPU, mémoire, chacun avec une phrase en langage clair). L'échantillonnage reste à une fois par seconde ; les points sont moyennés par minute et écrits en JSONL sous `~/Library/Application Support/MacStats/history/` — chaque point de minute enregistre aussi les trois processus les plus actifs du moment, environ 0,4 Mo par jour, conservés 30 jours par défaut. Réglages → Suivi permet de passer à 7 / 30 / 90 jours, ou de tout effacer.

Deux limites assumées : **les pics GPU ne listent pas de processus** (l'échantillonnage actuel ne fournit pas d'usage GPU fiable par processus), et **l'historique écrit avant cette version ne contient pas de processus** — un clic affiche « Aucun processus enregistré à ce moment » plutôt que de reprendre la liste actuelle.

« Alertes de charge prolongée » est désactivé par défaut. Une fois activé, le CPU ≥ 90 %, la mémoire ≥ 85 % ou le disque ≥ 90 % doivent tenir pendant **trois échantillons consécutifs** avant qu'une notification parte, et chaque indicateur se répète au plus toutes les dix minutes — un pic isolé ne vous interrompt jamais. Le texte nomme le processus responsable : l'événement CPU prend le premier en CPU, l'événement mémoire le premier en mémoire (classements séparés) ; les événements disque n'ont pas d'attribution de processus et n'annoncent que la valeur.

## Nettoyage en un clic des processus d'arrière-plan inactifs

Barre des menus (ou panneau) → « Nettoyer les processus d'arrière-plan inactifs… ». Seuls les **orphelins abandonnés** sont visés : lancés par vous, parent déjà terminé, aucun terminal de contrôle, aucun enfant, aucune socket, et aucune activité CPU depuis 10 minutes. Vous voyez d'abord la liste et l'empreinte annoncée de ces processus (pas ce que macOS récupérera réellement) ; ce n'est qu'après confirmation qu'il envoie `SIGTERM`, et tout ce qui tourne encore après 3 secondes est laissé tranquille — jamais de passage à `SIGKILL`.

Toujours épargnés : les processus système (`/System`, `/usr`, `/Library`, …), les apps et leurs assistants (`.app/` dans le chemin), les commandes rattachées à un tty, l'app au premier plan, les enfants d'un parent vivant, tout ce qui détient une socket TCP/UDP/Unix, les enfants du processus lui-même, et les noms de votre liste blanche (menu → « Liste blanche de nettoyage », comparée au nom de l'exécutable et à `argv[0]`). Les noms cochés restent dans ce sous-menu avec un ✓ pour être décochés plus tard ; « Vider la liste blanche » la réinitialise.

### Chaque processus est expliqué en langage clair

La confirmation indique, pour chaque processus, ce qu'il est et ce que son arrêt change — par exemple `npm run dev` « serveur de développement local ; l'arrêter coupe la page locale et le rechargement à chaud », ou `github-mcp-server` « fournit des outils supplémentaires aux assistants IA ; l'arrêter en retire un jusqu'à la réouverture de cette app ». Les processus inconnus le disent franchement (« une commande d'arrière-plan nommée X, sans fenêtre ni icône ») au lieu de deviner. Les textes vivent dans `ProcessGlossary.swift`, une fonction pure qui associe `argv[0]` → nom de l'exécutable → chemin d'installation.

Sur une machine chargée, il signale souvent qu'il n'y a rien à nettoyer. C'est le fonctionnement prévu, pas une panne : ce qu'il attrape vraiment, ce sont les `node`, `python` ou scripts orphelins laissés par un plantage. Les zombies (état `Z`) sont hors champ — ils ont déjà terminé et seul leur parent peut les récolter.

Vérification en lecture seule (ne tue rien) :

```bash
cd src && .build/debug/macstatsDiag --cleanup-dry-run
```

## Fenêtre des Réglages

Barre des menus → « Réglages… » (ou ⌘,) ouvre une fenêtre de réglages standard à cinq onglets :

| Onglet | Contenu |
|---|---|
| Général | Langue (suivre le système / 简体中文 / English), affichage dans la barre des menus, ouvrir à la connexion, masquer au démarrage, son et notification de nettoyage, alerte de pression mémoire |
| Apparence et panneau | Thème (système / sombre / clair), accent (vif / monochrome), afficher le widget de bureau, forme du panneau (bandeau / compact / standard / détaillé), toujours au premier plan, clic à travers |
| Suivi | Intervalle d'actualisation, fenêtre de lissage (1 / 3 / 5 s), nombre de processus principaux (3 / 5 / 8), historique avec conservation 7 / 30 / 90 jours et effacement, alertes de charge prolongée |
| Nettoyage | Seuils d'inactivité et de mémoire, liste de processus recherchable avec explications, cocher pour protéger, saisie manuelle d'un nom, actualiser et vider |
| À propos | Version, architecture de compilation, source des données, déclaration de précision, ouvrir le Moniteur d'activité, lancer un diagnostic |

Le menu contextuel ne garde que les actions quotidiennes : afficher/masquer, déployer/replier, ajouter un widget, nettoyer, liste blanche, Moniteur d'activité, réglages, quitter.

## Deux surfaces

Une seule couche d'échantillonnage, deux hôtes :

| | Panneau de bureau | Widget système (WidgetKit) |
|---|---|---|
| Rafraîchissement | Redessiné chaque seconde | Planifié par le système, environ une fois par minute |
| Position | Déplaçable partout, plusieurs instances | Grille du bureau, suit le système |
| Accès | Icône de la barre des menus / `open MacStats.app` | Clic droit sur le bureau → « Modifier les widgets » → chercher « MacStats » |
| Taille | Redimensionnement libre, quatre paliers | Petit / moyen / grand / très grand |
| Prérequis | Aucun | Signature valide + installation dans `/Applications` + point d'entrée `_NSExtensionMain` |

Pour quelque chose qui bouge visiblement, prenez le panneau ; pour l'aligner avec vos autres widgets, le widget système. Les deux lisent le même instantané, ils ne peuvent donc pas se contredire.

## Quel point de précision face au Moniteur d'activité

La méthode : placer le Moniteur d'activité et le panneau sur le même écran, lire les valeurs du Moniteur via l'API d'accessibilité et les comparer à un échantillon pris au même instant.

| Élément | Résultat |
|---|---|
| Mémoire : utilisée / cache / App / Wired / compressée | À moins de 0,2 Go (le Moniteur lui-même fige son affichage 5 secondes) |
| Disque : cumul lu / écrit | Identique à l'octet près |
| Réseau : cumul reçu / envoyé | Identique à l'octet près (Go décimaux) |
| Mémoire des processus | 0,0 Mo pour le même PID |
| CPU | 1 à 3 points de pourcentage sous charge stable (décalage de la fenêtre d'échantillonnage) |

<p align="center">
  <img src="../monitor-compare.png" alt="En haut : l'onglet mémoire du Moniteur d'activité. En bas : le panneau MacStats au même instant" width="700" />
</p>

Pour y arriver, il a fallu corriger trois évidences :

- **Le trafic réseau cumulé doit venir des compteurs IFMIB 64 bits.** `ifi_ibytes` dans `NET_RT_IFLIST2` ne remplit que les 32 bits de poids faible ; après le rebouclage, les 122,9 Go de `lo0` de cette machine se lisaient comme 2,6 Go. Les totaux incluent `lo0` (le Moniteur le compte aussi), les colonnes de débit l'excluent, sinon le trafic de bouclage gonfle le débit d'un facteur soixante.
- **« Utilisée » n'est pas « App + Wired + compressée ».** La mémoire utilisée du Moniteur vaut physique − (libre − spéculative) − cache de fichiers, et les fichiers en cache valent cache de fichiers + pages purgeables. Il faut implémenter sa définition, pas l'intuitive.
- **L'énergie n'est pas l'« Impact sur l'énergie ».** Cette colonne est un score relatif sans dimension, impossible à reproduire. Le panneau affiche des watts physiques et étiquette la tuile « compteur d'énergie CPU » au lieu de mélanger les unités.

## Fonctionnement

Trois couches, aucune ne dépend de l'interface :

```
MacStatsCore  échantillonnage et conversions (logique pure, testée unitairement)
      ↓
WidgetData    instantané + historique circulaire de 90 points
      ↓
Vues SwiftUI partagées par le panneau et l'extension WidgetKit
```

- **Échantillonnage** : Mach (`host_processor_info`, `host_statistics64`), IOKit (statistiques de disque, sources d'énergie), `sysctl(NET_RT_IFLIST2)`, `sysctl(vm.swapusage)`, libproc (`proc_listpids` / `proc_pid_rusage`). API publiques uniquement : pas de sudo, pas de SIP désactivé, pas de framework privé.
- **Les métriques de débit sont une moyenne glissante des cinq derniers échantillons**, pour coller à la fenêtre de 5 secondes du Moniteur et lisser le scintillement.
- **Le panneau est un `NSPanel` de niveau bureau** : non activant, présent sur tous les Spaces, ne prend jamais le focus, donc cliquer dessus ne relègue pas votre fenêtre active.
- **Les données ne quittent pas la machine** : aucune requête réseau, aucune télémétrie, aucun compte, aucun fichier utilisateur lu. Seuls des compteurs système sont lus via des API publiques, et un JSON local est écrit pour l'extension.

## Commandes

| Objectif | Commande |
|---|---|
| Compiler, empaqueter, installer | `bash scripts/bundle.sh` |
| Tests unitaires | `cd src && swift test` |
| Autotest de l'échantillonnage | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| Afficher les compteurs bruts | `cd src && .build/debug/macstatsDiag --raw` |
| Instantané JSON | `cd src && .build/debug/macstatsDiag --json` |
| Rendu hors écran du panneau | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| Rendu des quatre tailles de widget | `bash scripts/preview-widget.sh` |

## Structure du projet

```
src/Sources/MacStatsCore/    échantillonnage, calcul mémoire, historique circulaire, formatage (sans UI)
src/Sources/MacStats/        panneau SwiftUI, app de barre des menus, menu contextuel, rendu hors écran
src/Sources/MacStatsWidget/  extension WidgetKit : fournisseur de timelines + quatre vues
src/Sources/MacStatsDiag/    CLI de diagnostic (--json / --raw / --self-check)
src/Tests/                   XCTest, 176 cas
scripts/bundle.sh            build release, assemblage de l'appex, signature, installation, enregistrement
docs/                        notes de comparaison, architecture, exigences, captures
```

## Extension de widget

L'extension est empaquetée dans `MacStats.app/Contents/PlugIns/MacStatsWidget.appex`, avec une mise en page par taille. Trois conditions sont nécessaires pour qu'elle apparaisse dans la galerie, toutes apprises à la dure :

1. **L'extension doit avoir une signature valide et être sandboxée.** `pkd` refuse les signatures ad-hoc, et même avec un vrai certificat un appex sans `com.apple.security.app-sandbox` est ignoré silencieusement avec `rejecting; … plug-ins must be sandboxed`. Un certificat gratuit d'équipe personnelle (Xcode → Settings → Accounts → connexion avec un Apple ID) suffit.
2. **L'app doit être dans `/Applications`, et une seule copie peut être enregistrée.** `chronod` ne découvre les hôtes que dans le dossier des applications du système ; lancée depuis le dossier du projet ou un dossier Applications utilisateur, elle journalise `Ignoring restricted or unknown extension`. Deux enregistrements du même identifiant de bundle font créer deux instances XPC par launchd, et `chronod` n'atteint plus le vrai processus. `bundle.sh` installe et nettoie les anciens enregistrements en conséquence.
3. **Le point d'entrée de l'appex doit être `_NSExtensionMain`.** C'est la valeur par défaut de `LD_ENTRY_POINT` chez Xcode ; avec celui de SwiftPM, le processus démarre, affiche `main [WidgetBundle]`, n'établit jamais la session XPC avec l'hôte et est déclaré mort au bout d'environ 15 ms, sans rapport de plantage. `src/Package.swift` le fixe via `linkerSettings`.

Une extension sandboxée ne peut pas lire les `UserDefaults` de l'app hôte, donc les données passent par un instantané JSON : l'app le réécrit toutes les 2 secondes dans son dossier Application Support et le duplique dans le conteneur de l'extension lorsqu'il existe ; si l'extension ne trouve pas d'instantané récent, elle échantillonne elle-même une fois.

Si `security find-identity -v -p codesigning` renvoie `0 valid identities`, il manque généralement le certificat intermédiaire WWDR G3 d'Apple dans le trousseau : importez `AppleWWDRCA-2030.cer` depuis les ressources de Xcode.

Après modification de l'extension, incrémentez `CFBundleVersion` : `chronod` met en cache les descripteurs par version et continuera sinon d'afficher l'ancien.

## FAQ

<details>
<summary><strong>Pourquoi le widget ne se met-il à jour qu'une fois par minute ?</strong></summary>

WidgetKit n'est pas une boucle de rendu mais un instantané planifié : une timeline fournit une entrée, le système demande la suivante à l'expiration. Bien que l'app appelle `reloadAllTimelines()` toutes les 15 secondes, `chronod` applique un budget (le journal indique `budgeted-1`). Les widgets tiers ne peuvent pas rafraîchir chaque seconde ; l'horloge du système est un privilège du système, pas des extensions.

Pour des chiffres en direct, utilisez le panneau de bureau, redessiné chaque seconde.

</details>

<details>
<summary><strong>Pourquoi WindowServer est-il absent des processus les plus gourmands ?</strong></summary>

Les processus des autres utilisateurs (comme `_windowserver`) ne sont pas lisibles : `proc_pid_rusage` renvoie EPERM et `proc_pidinfo` zéro octet. Le Moniteur d'activité dispose d'un entitlement Apple qui lui permet de tout voir. C'est une frontière de permissions, pas une erreur de calcul.

</details>

<details>
<summary><strong>Une valeur diffère encore légèrement.</strong></summary>

Le Moniteur d'activité se rafraîchit toutes les 5 secondes et affiche l'instantané du rafraîchissement précédent ; le panneau, chaque seconde. Comparés au même instant, la mémoire peut différer de 0,2 Go et les débits et le CPU du décalage de fenêtre. Recomparez après un cycle : ils concordent.

</details>

<details>
<summary><strong>Des données sont-elles envoyées quelque part ?</strong></summary>

Non. Aucune requête réseau, aucune télémétrie, aucun compte, aucun fichier utilisateur lu. Seuls des compteurs système sont lus via des API publiques, et un JSON local est écrit pour l'extension.

</details>

<details>
<summary><strong>Cela fonctionne-t-il sur Mac Intel ?</strong></summary>

Non. La version publiée est réservée à Apple Silicon (arm64) : pas de build Intel, pas de chemin Rosetta ; elle ne fonctionne pas sur Mac Intel.

</details>

## Limites connues

- **Le widget système avance environ toutes les 60 secondes.** C'est la limite de planification de WidgetKit ; aucune app ne peut la contourner.
- **L'énergie correspond à des watts physiques**, pas au score « Impact sur l'énergie » du Moniteur. Les deux n'ont pas d'équivalence d'unité.
- **La liste des processus ne couvre que l'utilisateur courant**, triée par mémoire : le panneau en affiche trois, la couche d'échantillonnage en garde jusqu'à 24.
- **L'historique reste local et s'arrête à la minute** : agrégé par minute et écrit en JSONL, conservé 7 / 30 / 90 jours au choix. Pas de synchronisation cloud ni de relecture à la seconde.
- **Les alertes ne portent que sur trois valeurs** : CPU / mémoire / disque, après trois mesures consécutives au-dessus du seuil, désactivées par défaut. Ni température, ni ventilateurs, ni processus isolé.
- **Pas de supervision à distance** : toutes les mesures et l'historique restent sur ce Mac et ne partent pas sur le réseau.

## Documentation

Les notes détaillées sont en chinois.

- [Notes de comparaison](../monitor-alignment.md) : comment chaque valeur est alignée sur le Moniteur d'activité, mesures à l'appui.
- [Architecture](../architecture.md) : couches, flux de données et arbitrages.
- [Exigences](../requirements.md) : périmètre, non-objectifs et critères d'acceptation.

## Licence

Publié sous [licence MIT](../../LICENSE). Utilisation, modification et distribution — y compris commerciales — sont libres, à condition de conserver la mention de copyright et le texte de la licence.
