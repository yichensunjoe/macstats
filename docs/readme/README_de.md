<div align="center">

[简体中文](../../README.md) · [English](README_en.md) · [繁體中文](README_zh-TW.md) · [日本語](README_ja.md) · [한국어](README_ko.md) · **Deutsch** · [Español](README_es.md) · [Français](README_fr.md) · [Русский](README_ru.md) · [Português (Brasil)](README_pt-BR.md)

# MacStats Panel

### Die Aktivitätsanzeige, fest auf dem Schreibtisch.

**CPU, Speicher, GPU, Energie, Festplatte und Netzwerk auf einen Blick – jede Zahl an die Aktivitätsanzeige angeglichen.**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#installation)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#funktionsweise)
[![tests](https://img.shields.io/badge/tests-176%20passing-3fb950?style=flat-square)](#befehle)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#funktionsweise)

[Installation](#installation) · [Was angezeigt wird](#was-angezeigt-wird) · [Zwei Oberflächen](#zwei-oberflächen) · [Genauigkeit](#wie-genau-ist-der-vergleich-mit-der-aktivitätsanzeige) · [FAQ](#faq) · [Bekannte Einschränkungen](#bekannte-einschränkungen)

**[MacStats.zip herunterladen](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)** · nach `/Applications` ziehen, beim ersten Start in den Systemeinstellungen über „Trotzdem öffnen“ erlauben

</div>

---

## Installation

[**MacStats.zip herunterladen**](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip) (ca. 2,5 MB, macOS 15+ auf Apple Silicon)

1. Entpacken und `MacStats.app` nach `/Applications` ziehen
2. Der erste Start wird blockiert (**nicht notarisiert**): im Dialog „Fertig“ klicken, dann Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“; alternativ das Quarantäne-Attribut im Terminal entfernen. Warum, und beide Wege, stehen in den [Installationshinweisen](../install.md)
3. Das Panel erscheint auf dem Schreibtisch. Für das WidgetKit-Widget: Schreibtisch rechtsklicken → „Widgets bearbeiten“ → nach „系统监视“ suchen (der Name des Widgets in der Galerie)

```bash
# Optional: die Quarantäne-Attribute einmal entfernen, danach genügt ein Doppelklick
xattr -dr com.apple.quarantine /Applications/MacStats.app

# Oder über Homebrew
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats      # Homebrew 5+ verlangt explizites Vertrauen für Fremd-Taps
brew install --cask macstats
```

Download prüfen: `shasum -a 256 -c MacStats.zip.sha256` (die Prüfsumme liegt beim Release).

<p align="center">
  <img src="../live-window.png" alt="MacStats-Panel: CPU, Speicher, GPU, Energie, Festplatte, Netzwerk und die drei speicherhungrigsten Prozesse" width="460" />
</p>

Die Aktivitätsanzeige zeigt schon alles. Das Problem ist, dass sie ein Fenster ist: öffnen, Tab wählen, in den Vordergrund holen. MacStats macht aus denselben sechs Werten ein dunkles Panel, das auf dem Schreibtisch bleibt, einmal pro Sekunde abtastet, sein Layout beim Größenändern neu aufbaut und zusätzlich ein WidgetKit-Widget mitbringt – für alle, die lieber ein kleines im Schreibtischraster hätten.

Es soll bewusst kein größeres Dashboard sein. Die Messwerte sind die fünf der Aktivitätsanzeige plus GPU-Auslastung und belegtem Unified Memory, dazu eine 90-Sekunden-Kurve, die Last pro Kern, die Speicheraufteilung und die drei Prozesse mit dem größten Speicherbedarf. Die eigentliche Arbeit steckt nicht im Zeichnen, sondern darin, **jede Zahl identisch zur Aktivitätsanzeige zu machen**: im selben Moment nebeneinander gestellt bleibt der Speicher innerhalb von 0,2 GB, und die kumulierten Festplatten- und Netzwerkzähler stimmen byteweise.

<p align="center">
  <img src="../compact-strip.png" alt="Breiter Streifen: CPU, Arbeitsspeicher, GPU, Energie, Festplatte und Netzwerk in einer Zeile" width="620" />
  <br />
  <img src="../compact-strip-narrow.png" alt="Schmaler Streifen: dieselben sechs Werte fallen in ein 3 × 2-Raster" width="330" />
</p>

**Zieht man das Panel zu einem Streifen, greift das minimale Layout.** Keine Karten, keine Kurven – sechs Werte in einer Reihe, wie eine Anzeige unter der Menüleiste. Wird das Panel zu schmal für eine Reihe, faltet es sich in ein 3 × 2-Raster, sodass alle sechs sichtbar bleiben. Bei Aktualisierung im Sekundentakt kostet die App rund 1 % eines Kerns und etwa 80 MB Arbeitsspeicher (gemessen auf arm64, macOS 26); gezeichnet wird hier am wenigsten. Bei einer frischen Installation ist das die Standardform; Rechtsklick → „Zum Standard-Panel erweitern“ öffnet das volle Panel, derselbe Eintrag faltet es wieder zusammen.

> [!NOTE]
> Das schwebende Panel funktioniert sofort. Die Kopie in der System-Widgetgalerie braucht eine gültige Apple-Development-Signatur und muss in `/Applications` installiert sein – beides sind harte Anforderungen von `chronod`, keine Vorlieben. Siehe [System-Widget](#system-widget).

## Aus dem Quellcode bauen

Vorausgesetzt werden macOS 15 oder neuer und die Xcode-Kommandozeilentools (Swift 6). Keine Fremdabhängigkeiten, kein Xcode-Projekt.

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # bauen + bündeln + nach /Applications installieren + Widget registrieren
open /Applications/MacStats.app
```

Beim ersten Start erscheint in der Menüleiste ein kleiner `CPU · Speicher`-Wert und das Panel zeigt sich auf dem Schreibtisch.

- Linksklick auf das Menüleisten-Symbol: Panel ein- oder ausblenden
- Rechtsklick auf das Panel: immer im Vordergrund, am Schreibtisch fixieren, Klicks durchreichen, Aktualisierungsintervall (1 / 2 / 5 s), neue Instanz
- Leere Fläche ziehen bewegt das Panel, der Griff unten rechts ändert die Größe; das Layout wechselt automatisch zwischen Minimal / Kompakt / Standard / Detailliert
- Einstellungen liegen in der Einstellungsdomäne `com.macstats.app`, Position und Größe überleben einen Neustart

## Was angezeigt wird

| Messwert | Im Panel | Erfassung |
|---|---|---|
| CPU | Große Gesamtzahl + Nutzer/System + 90-s-Kurve + Balken pro Kern | `host_processor_info`-Differenzen, gleiche Quelle wie die Aktivitätsanzeige |
| Speicher | Belegt / gesamt, Druckskalierung, Aufteilung App / Wired / komprimiert, Dateicache | `vm_statistics64`, siehe [Genauigkeit](#wie-genau-ist-der-vergleich-mit-der-aktivitätsanzeige) |
| Energie | Aus dem CPU-Energiezähler abgeleitete Watt, Batteriestand und Ladezustand | `ri_energy_nj`-Differenzen; fehlt der Zähler, wird eine lastbasierte Schätzung genutzt und als solche markiert |
| Festplatte | Lese-/Schreibrate, freier Speicher | Kumulierte Byte-Differenzen aus `IOBlockStorageDriver` |
| Netzwerk | Up-/Down-Rate, primäre Schnittstelle | 64-Bit-Zähler aus `NET_RT_IFLIST2`; Raten ohne `lo0` |
| GPU | Große Auslastungszahl + 90-s-Kurve + belegter Unified Memory / Kernzahl | `PerformanceStatistics` aus `IOAccelerator` (`Device Utilization %`, `In use system memory`), gleiche Quelle wie der GPU-Tab der Aktivitätsanzeige |
| Prozesse | Die drei mit dem größten Speicher (fünf im großen Widget) | `ri_phys_footprint` aus `proc_pid_rusage` |

<p align="center">
  <img src="../widget-medium.png" alt="Mittleres Widget: CPU mit Balken pro Kern sowie Kacheln für Speicher, Festplatte, Netzwerk, Energie und – falls vorhanden – GPU" width="620" />
  <img src="../widget-small.png" alt="Kleines Widget: große CPU-Zahl mit Kurve" width="280" />
</p>

## Zwei Oberflächen

Eine Erfassungsschicht, zwei Wirte:

| | Schreibtisch-Panel | System-Widget (WidgetKit) |
|---|---|---|
| Aktualisierung | Neuzeichnen im Sekundentakt | Vom System geplant, etwa einmal pro Minute |
| Position | Frei verschiebbar, beliebig viele Instanzen | Schreibtischraster, folgt dem System |
| Einstieg | Menüleisten-Symbol / `open MacStats.app` | Rechtsklick auf den Schreibtisch → „Widgets bearbeiten“ → „MacStats“ suchen |
| Größe | Frei skalierbar, vier Layoutstufen | Klein / mittel / groß / extragroß |
| Voraussetzung | keine | Gültige Signatur + Installation in `/Applications` + Einstiegspunkt `_NSExtensionMain` |

Wer sichtbare Bewegung will, nimmt das Panel; wer es neben andere Widgets legen will, das System-Widget. Beide lesen denselben Schnappschuss, daher können sie sich nie widersprechen.

## Wie genau ist der Vergleich mit der Aktivitätsanzeige

Die Methode: Aktivitätsanzeige und Panel auf denselben Bildschirm, die Werte der Aktivitätsanzeige über die Bedienungshilfen-Schnittstelle auslesen und mit einer Probe aus demselben Moment vergleichen.

| Punkt | Ergebnis |
|---|---|
| Speicher: belegt / Cache / App / Wired / komprimiert | innerhalb 0,2 GB (die Aktivitätsanzeige selbst hält ihre Anzeige 5 Sekunden lang) |
| Festplatte: kumuliert gelesen / geschrieben | byteweise identisch |
| Netzwerk: kumuliert empfangen / gesendet | byteweise identisch (dezimales GB) |
| Prozessspeicher | 0,0 MB bei gleicher PID |
| CPU | 1–3 Prozentpunkte bei gleichmäßiger Last (Versatz des Messfensters) |

<p align="center">
  <img src="../monitor-compare.png" alt="Oben: Speicher-Tab der Aktivitätsanzeige. Unten: das MacStats-Panel im selben Moment" width="700" />
</p>

Dafür waren drei Annahmen zu korrigieren:

- **Kumulierter Netzwerkverkehr muss aus den 64-Bit-IFMIB-Zählern kommen.** `ifi_ibytes` in `NET_RT_IFLIST2` füllt nur die unteren 32 Bit; nach dem Überlauf wurden aus 122,9 GB `lo0`-Verkehr auf diesem Rechner 2,6 GB. Summen enthalten `lo0` (die Aktivitätsanzeige zählt es mit), die Raten-Spalten nicht – sonst bläht Loopback-Verkehr die Rate um etwa das Sechzigfache auf.
- **„Belegt“ ist nicht „App + Wired + komprimiert“.** Der belegte Speicher der Aktivitätsanzeige ist physisch − (frei − spekulativ) − Dateicache, und zwischengespeicherte Dateien sind Dateicache + auslagerbare Seiten. Man muss ihre Definition umsetzen, nicht die naheliegende.
- **Energie ist nicht „Energiebeeinflussung“.** Diese Spalte ist ein dimensionsloser relativer Wert und lässt sich nicht nachbilden. Das Panel zeigt physikalische Watt und beschriftet die Kachel mit „CPU-Energiezähler“, statt beides zu vermischen.

## Funktionsweise

Drei Schichten, keine davon hängt von der UI ab:

```
MacStatsCore  Erfassung und Umrechnung (reine Logik, unit-getestet)
      ↓
WidgetData    Schnappschuss + Ringhistorie mit 90 Punkten
      ↓
SwiftUI-Ansichten, gemeinsam genutzt von Panel und WidgetKit-Erweiterung
```

- **Erfassung**: Mach (`host_processor_info`, `host_statistics64`), IOKit (Festplattenstatistik, Energiequellen), `sysctl(NET_RT_IFLIST2)`, `sysctl(vm.swapusage)`, libproc (`proc_listpids` / `proc_pid_rusage`). Nur öffentliche APIs – kein sudo, keine SIP-Änderungen, keine privaten Frameworks.
- **Ratenwerte sind ein gleitender Mittelwert der letzten fünf Proben**, passend zum standardmäßigen 5-Sekunden-Fenster der Aktivitätsanzeige, und glätten das Flackern.
- **Das Panel ist ein `NSPanel` auf Schreibtischebene**: nicht aktivierend, auf allen Spaces, nimmt keinen Fokus, sodass ein Klick das aktuelle Fenster nicht nach hinten schiebt.
- **Daten verlassen den Rechner nicht**: keine Netzwerkanfragen, keine Telemetrie, keine Konten, keine Benutzerdateien. Es werden Systemzähler über öffentliche APIs gelesen und eine lokale JSON-Datei für die Widget-Erweiterung geschrieben, sonst nichts.

## Befehle

| Ziel | Befehl |
|---|---|
| Bauen, bündeln, installieren | `bash scripts/bundle.sh` |
| Unit-Tests | `cd src && swift test` |
| Selbsttest der Erfassung | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| Rohzähler ausgeben | `cd src && .build/debug/macstatsDiag --raw` |
| JSON-Schnappschuss | `cd src && .build/debug/macstatsDiag --json` |
| Panel offline rendern | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| Alle vier Widget-Größen rendern | `bash scripts/preview-widget.sh` |

## Projektstruktur

```
src/Sources/MacStatsCore/    Erfassung, Speicherumrechnung, Ringhistorie, Formatierung (ohne UI)
src/Sources/MacStats/        SwiftUI-Panel, Menüleisten-App, Kontextmenü, Offline-Rendering
src/Sources/MacStatsWidget/  WidgetKit-Erweiterung: Timeline-Provider + vier Ansichten
src/Sources/MacStatsDiag/    Diagnose-CLI (--json / --raw / --self-check)
src/Tests/                   XCTest, 176 Fälle
scripts/bundle.sh            Release-Build, appex-Zusammenbau, Signierung, Installation, Registrierung
docs/                        Abgleich, Architektur, Anforderungen, Screenshots
```

## System-Widget

Die Erweiterung liegt in `MacStats.app/Contents/PlugIns/MacStatsWidget.appex`, mit eigenem Layout pro Größe. Drei Dinge sind nötig, damit sie in der Galerie erscheint – alle drei wurden schmerzhaft gelernt:

1. **Die Erweiterung braucht eine gültige Signatur und eine Sandbox.** `pkd` lehnt Ad-hoc-Signaturen ab, und selbst mit echtem Zertifikat wird ein appex ohne `com.apple.security.app-sandbox` stillschweigend mit `rejecting; … plug-ins must be sandboxed` verworfen. Ein kostenloses Zertifikat eines persönlichen Teams (Xcode → Settings → Accounts → mit Apple ID anmelden) genügt.
2. **Die App muss in `/Applications` liegen, und nur eine Kopie darf registriert sein.** `chronod` findet Wirte nur im System-Programmordner; aus dem Projektordner oder einem benutzerweiten Applications-Ordner gestartet erscheint `Ignoring restricted or unknown extension` im Log. Zwei Registrierungen derselben Bundle-ID lassen launchd zwei XPC-Instanzen anlegen, und `chronod` erreicht den echten Prozess nicht mehr. `bundle.sh` installiert entsprechend und räumt alte Registrierungen auf.
3. **Der Einstiegspunkt des appex muss `_NSExtensionMain` sein.** Das ist Xcodes Standard für `LD_ENTRY_POINT`; mit dem Standard-Einstiegspunkt von SwiftPM startet der Prozess, gibt `main [WidgetBundle]` aus, baut aber nie eine XPC-Sitzung zum Wirt auf und wird nach rund 15 ms für tot erklärt – ohne Crash-Report. `src/Package.swift` legt das über `linkerSettings` fest.

Eine sandboxed Erweiterung kann die `UserDefaults` der Host-App nicht lesen, deshalb laufen die Daten als JSON-Schnappschuss: Die App schreibt ihn im Application-Support-Ordner alle 2 Sekunden neu und spiegelt ihn in den Container der Erweiterung, wenn dieser existiert; findet die Erweiterung keinen frischen Schnappschuss, erfasst sie selbst einmal.

Meldet `security find-identity -v -p codesigning` `0 valid identities`, fehlt im Schlüsselbund meist Apples WWDR-G3-Zwischenzertifikat – `AppleWWDRCA-2030.cer` aus den Xcode-Ressourcen importieren.

Nach Änderungen an der Erweiterung `CFBundleVersion` erhöhen: `chronod` cached Descriptors pro Version und zeigt sonst weiter die alte Ansicht.

## FAQ

<details>
<summary><strong>Warum aktualisiert sich das Widget nur etwa einmal pro Minute?</strong></summary>

WidgetKit ist keine Rendering-Schleife, sondern ein geplanter Schnappschuss: Eine Timeline liefert einen Eintrag, nach Ablauf fragt das System den nächsten an. Obwohl die App alle 15 Sekunden `reloadAllTimelines()` anfordert, drosselt `chronod` über ein Budget – im Log steht `budgeted-1`. Fremde Widgets dürfen nicht sekündlich aktualisieren; die Systemuhr ist ein Privileg des Systems, nicht von Erweiterungen.

Für Live-Zahlen das Panel nutzen, das jede Sekunde neu zeichnet.

</details>

<details>
<summary><strong>Warum fehlt WindowServer in den Top-Prozessen?</strong></summary>

Prozesse anderer Benutzer (etwa `_windowserver`) sind nicht lesbar: `proc_pid_rusage` liefert EPERM, `proc_pidinfo` null Bytes. Die Aktivitätsanzeige hat ein Apple-Entitlement und sieht alles. Das ist eine Berechtigungsgrenze, kein Rechenfehler.

</details>

<details>
<summary><strong>Eine Zahl weicht trotzdem leicht ab.</strong></summary>

Die Aktivitätsanzeige aktualisiert alle 5 Sekunden und zeigt den Stand der letzten Aktualisierung, das Panel jede Sekunde. Im selben Moment verglichen kann der Speicher bis 0,2 GB abweichen, Raten und CPU um den Versatz des Messfensters. Nach einer Aktualisierungsperiode stimmen sie überein.

</details>

<details>
<summary><strong>Werden Daten hochgeladen?</strong></summary>

Nein. Keine Netzwerkanfragen, keine Telemetrie, keine Konten, keine Benutzerdateien. Es werden Systemzähler über öffentliche APIs gelesen und eine lokale JSON-Datei für die Widget-Erweiterung geschrieben.

</details>

<details>
<summary><strong>Läuft es auf Intel-Macs?</strong></summary>

Der Code nutzt nur öffentliche APIs und sollte portabel sein, getestet wurde er aber nur auf arm64 (macOS 26). Für die CPU- und Energieumrechnung gibt es auf Intel keine Kalibrierdaten. Issues mit eigenen Vergleichswerten sind willkommen.

</details>

## Bekannte Einschränkungen

- **Das System-Widget springt etwa alle 60 Sekunden.** Das ist die Grenze der WidgetKit-Planung; keine App kann sie umgehen.
- **Energie sind physikalische Watt**, nicht der Wert „Energiebeeinflussung“ der Aktivitätsanzeige. Zwischen beiden besteht keine Einheitenbeziehung.
- **Die Prozessliste umfasst nur den aktuellen Benutzer** und ist nach Speicher sortiert: Das Panel zeigt drei, die Erfassungsschicht hält bis zu 24.
- **Der Verlauf bleibt lokal und geht nur bis zur Minute**: pro Minute aggregiert und als JSONL geschrieben, wahlweise 7 / 30 / 90 Tage aufbewahrt. Keine Cloud-Synchronisierung, keine sekundengenaue Wiedergabe.
- **Warnungen betreffen nur drei Werte**: CPU / Speicher / Festplatte, erst nach drei aufeinanderfolgenden Überschreitungen, standardmäßig aus. Temperatur, Lüfter und einzelne Prozesse werden nicht überwacht.
- **Keine Fernüberwachung**: Alle Messwerte und der Verlauf bleiben auf diesem Mac und gehen nicht ins Netz.

## Dokumentation

Die ausführlichen Notizen sind auf Chinesisch.

- [Abgleich](../monitor-alignment.md): wie jeder Wert an die Aktivitätsanzeige angeglichen wurde, mit Messwerten.
- [Architektur](../architecture.md): Schichten, Datenfluss und die Abwägungen dahinter.
- [Anforderungen](../requirements.md): Umfang, Nicht-Ziele, Abnahmekriterien.

## Lizenz

Veröffentlicht unter der [MIT-Lizenz](../../LICENSE). Nutzung, Änderung und Weitergabe – auch kommerziell – sind frei, solange Copyright-Hinweis und Lizenztext erhalten bleiben.
