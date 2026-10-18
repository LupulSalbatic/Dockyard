# Dockyard — context pentru AI

Aplicație macOS (Swift 6 toolchain, mod de limbaj Swift 5, SwiftUI + AppKit, macOS 15+) care pune în Dock **„foldere” cu mai multe aplicații**.
Fiecare folder are iconița lui (mozaic din iconițele aplicațiilor, simbol SF + gradient sau o imagine aleasă).
Un click pe folderul din Dock deschide un panou cu aplicațiile, iar click-dreapta deschide un meniu rapid.
Folderele există în Dock **doar cât timp Dockyard rulează**. La închidere dispar, iar la repornire revin pe aceleași poziții.

Interfața, comentariile din cod și README-ul sunt în **română**. Păstrează limba română în textele vizibile și în comentarii.

## Cum funcționează (ideea de bază)
macOS nu permite foldere de aplicații „reale” în Dock, așa că:
1. Pentru fiecare folder, Dockyard generează o **mini-aplicație** (`Dockyard Data/Tiles/<uuid fără cratime>.app`). Ea conține o copie a binarului helper `DockyardFolder`, un `Info.plist` (cu `DYFolderID`, `DYDataDir`, `DYMainApp`) și iconița `.icns` randată. Bundle-ul e semnat ad-hoc cu `codesign`.
2. Dockyard scrie aceste `.app`-uri în lista Dock-ului: `com.apple.dock` → `persistent-apps`, prin `CFPreferences`. Apoi repornește Dock-ul cu `killall Dock`.
3. Fiecare mini-aplicație rulează ca proces separat. La click în Dock (`applicationShouldHandleReopen`) deschide un `NSPanel` cu aplicațiile. Helper-ul rulează ca aplicație de fundal (`LSUIElement` + `.accessory`), ca Dock-ul să nu afișeze bulina de „pornită” sub folder. Din acest motiv, la click-dreapta Dock-ul arată meniul lui standard, nu `applicationDockMenu`.
4. Procesele comunică prin `DistributedNotificationCenter` (`Signal.changed/quit/edit/show` în `Models.swift`).
5. La ieșire (⌘Q), Dockyard salvează pozițiile din Dock, scoate folderele din Dock, oprește helperele și șterge urmele din `~/Library` (`LeaveNoTrace`).
6. Dacă Dockyard moare brusc, un helper face curățenia de urgență (cu `flock` pe `.cleanup.lock`). Dacă un helper e pornit fără Dockyard, pornește Dockyard și se închide.

Dockyard are două moduri de închidere:
- **„Ascunde din Dock”** (⌘W): rulează în fundal, cu o iconiță `MenuBarExtra` în bara de meniu.
- **„Închide complet”** (⌘Q).

## Structura codului
- `Package.swift`: 3 target-uri SwiftPM:
  - `DockyardCore` (bibliotecă comună)
  - `Dockyard` (aplicația principală)
  - `DockyardFolder` (helper-ul din fiecare folder)
- `Sources/DockyardCore/`
  - `Models.swift`: `AppRef`, `FolderIcon`/`IconStyle`, `DockFolder`, `LibraryState`; `Paths` (căile de date), `StateIO` (JSON), `Signal` (notificări între procese), `LeaveNoTrace`.
  - `Dock.swift`: `TileFactory` (generează și semnează bundle-urile din `Tiles/`), `DockController` (citește și scrie `persistent-apps`, inserează folderele la `dockIndex`, repornește Dock-ul), `AppCatalog` (lista aplicațiilor instalate: dosarele standard + `mdfind`).
  - `IconRenderer.swift`: randează iconița folderului (PNG/ICNS).
- `Sources/Dockyard/` (UI principal, SwiftUI)
  - `DockyardApp.swift`: `@main`, `AppDelegate`, meniurile/comenzile, `BackgroundMenu` din bara de meniu.
  - `Library.swift`: `@Observable` cu toată starea și logica (pornire/oprire, aplicare în Dock cu debounce, sincronizarea pozițiilor din Dock la 2 s, adăugare/ștergere/redenumire, imagini, toast-uri).
  - `ContentView.swift`: sidebar, comutatorul „Live în Dock”, confirmarea ștergerii, starea goală.
  - `FolderEditor.swift`: editorul folderului (iconiță, aplicații, poziția în Dock).
  - `AppPicker.swift`: alegerea aplicațiilor.
  - `Theme.swift`: stilul vizual (glass, butoane, fundal „aurora”).
  - `AppLocation.swift`: la pornire verifică dacă Dockyard poate scrie lângă el (nu rulează din „App Translocation”, adică direct din Descărcări). Dacă nu, oferă mutarea în `/Applications` (sau `~/Applications`), scoate carantina de pe copie și repornește de acolo.
- `Sources/DockyardFolder/`
  - `main.swift`: delegate-ul helper-ului (reîncărcare, meniu Dock, curățenie de urgență).
  - `FolderPanel.swift`: panoul plutitor cu aplicațiile, poziționat în funcție de marginea Dock-ului.
- `scripts/build-app.sh`: compilează (release, universal arm64 + x86_64) și asamblează `dist/Dockyard.app` (cu `--zip` creează și `dist/Dockyard.zip`). Helper-ul ajunge în `Contents/Helpers/`. Generează iconița cu `scripts/make-icon.swift` și semnează ad-hoc. Ține cache-urile în `.build/local` și șterge urmele compilatorului din afara proiectului.

- `.github/workflows/build.yml`: compilează pe `macos-15` la fiecare push. Pe ramura principală publică release-ul `latest` cu `Dockyard.zip` (link: `releases/latest/download/Dockyard.zip`).

## Distribuire
Utilizatorul descarcă `Dockyard.zip` din Releases, trage aplicația în Aplicații și o pornește. Aplicația e semnată doar ad-hoc (fără Developer ID / notarizare), așa că la prima pornire trebuie „Deschide oricum” din Setări sistem. Binarul helper din bundle poartă carantina descărcării: `TileFactory` o scoate de pe copia din fiecare folder, altfel Gatekeeper ar bloca folderele din Dock.

## Date
Toate datele stau **lângă aplicație**, în `Dockyard Data/` (de ex. `/Applications/Dockyard Data/` sau `dist/Dockyard Data/` la build local), nu în `~/Library`:
- `folders.json`: `LibraryState` (folderele, aplicațiile, iconițele, `dockIndex`, `enabled`)
- `Icons/`: imaginile alese ca iconiță
- `Tiles/`: mini-aplicațiile din Dock

`dist/` și `.build/` sunt în `.gitignore`: se generează la build.

## Build și testare
```sh
./scripts/build-app.sh                              # necesită Xcode
open dist/Dockyard.app --env DOCKYARD_DRY_RUN=1     # UI fără să modifice Dock-ul
```
Alte variabile de mediu pentru teste:
- `DOCKYARD_TEST=delete|rename|title|background`: declanșează acțiunea pe primul folder.
- `DOCKYARD_SHOW_PANEL=1`: în helper, afișează panoul la pornire.

Nu există teste automate.

## Reguli de respectat
- Proiectul nu lasă urme în afara folderului său. Nu adăuga scrieri în `~/Library`, `UserDefaults` persistente etc.
- Orice modificare a Dock-ului trece prin `DockController.apply` (compară semnăturile și repornește Dock-ul doar la nevoie). Respectă `dryRun`.
- Bundle ID-uri: `com.andrei.dockyard` (aplicația principală) și `com.andrei.dockyard.folder.<shortID>` (folderele).
