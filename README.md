# Dockyard — foldere de aplicații în Dock

Pune în Dock „foldere” care conțin mai multe aplicații, fiecare cu iconița pe care o alegi.
Folderele există **doar cât timp Dockyard rulează**: când închizi aplicația (⌘Q), dispar din Dock,
iar la următoarea pornire revin exact unde erau, cu aceleași aplicații.

## Instalare
1. Descarcă [**Dockyard.zip**](https://github.com/LupulSalbatic/Dockyard/releases/latest/download/Dockyard.zip) (din [Releases](https://github.com/LupulSalbatic/Dockyard/releases/latest)) și deschide-l: se dezarhivează în Descărcări.
2. Trage **Dockyard.app** în dosarul **Aplicații**.
3. Pornește Dockyard. Prima dată, macOS spune că nu poate verifica aplicația (nu e semnată de un dezvoltator Apple înregistrat):
   apasă **Gata**, apoi mergi în **Setări sistem → Confidențialitate și securitate**, apasă **Deschide oricum** și confirmă.
   De atunci încolo pornește normal, ca orice aplicație.
   Alternativ, în Terminal: `xattr -dr com.apple.quarantine /Applications/Dockyard.app`

Dacă îl pornești direct din Descărcări, fără să-l muți, Dockyard se oferă să se mute singur în Aplicații.
Necesită macOS 15 sau mai nou (Apple Silicon sau Intel).

**Dezinstalare:** închide Dockyard (⌘Q), apoi șterge `Dockyard.app` și dosarul `Dockyard Data` de lângă el.

## Cum îl folosești
1. Deschide Dockyard.
2. **Folder nou** (⌘N), apoi **Adaugă aplicații** sau trage aplicații din Finder.
3. Alege iconița: **Mozaic** (iconițele aplicațiilor), **Simbol** (simbol + gradient) sau **Imagine** (orice poză, inclusiv trasă cu mouse-ul).
4. Folderul apare în Dock. Un click deschide panoul cu aplicațiile, iar click-dreapta afișează un meniu rapid.
5. Mută-l cu **Stânga/Dreapta** din aplicație sau trage-l direct în Dock: poziția e memorată.

**Redenumire:** dublu-click pe nume în listă, creionul de lângă titlu, ⌘R sau click-dreapta pe folder (în listă sau în Dock).
**Ștergere:** butonul „Șterge folderul”, ⌘⌫ sau click-dreapta. Ștergerea cere confirmare și nu șterge aplicațiile de pe Mac.

## Două feluri de a închide
- **Ascunde din Dock**: butonul din sidebar, butonul roșu al ferestrei sau ⌘W. Dockyard dispare din Dock, dar rulează în fundal, iar folderele rămân. Apare o iconiță în bara de meniu (sus), de unde îl redeschizi sau deschizi un folder. Îl readuci și pornindu-l din nou (Spotlight, Finder) sau din meniul unui folder („Editează în Dockyard…”).
- **Închide complet**: butonul din sidebar, ⌘Q sau „Închide complet Dockyard” din bara de meniu. Totul se oprește, iar folderele dispar din Dock până la următoarea pornire.

Comutatorul „Live în Dock” scoate temporar folderele din Dock fără să închidă aplicația.

## Unde se salvează
Totul stă lângă aplicație, în dosarul `Dockyard Data/` (de exemplu `/Applications/Dockyard Data/`, sau `dist/Dockyard Data/` când rulezi build-ul local):
- `folders.json`: folderele, aplicațiile, iconițele și pozițiile din Dock
- `Icons/`: imaginile alese ca iconiță
- `Tiles/`: mini-aplicațiile care apar în Dock, câte una pentru fiecare folder

În afara folderului, Dockyard modifică doar lista din Dock, cât timp rulează. La închidere o pune la loc și șterge fișierele pe care macOS le creează automat pentru aplicație.

## Build
```sh
./scripts/build-app.sh          # creează dist/Dockyard.app (universal, necesită Xcode)
./scripts/build-app.sh --zip    # și dist/Dockyard.zip
```
La fiecare modificare pe `main`, GitHub Actions (`.github/workflows/build.yml`) compilează aplicația pe macOS
și actualizează `Dockyard.zip` din Releases.
Cache-urile de compilare rămân în `.build/`, iar urmele inevitabile ale compilatorului din afara proiectului sunt șterse automat.

## Testare fără a atinge Dock-ul
`open dist/Dockyard.app --env DOCKYARD_DRY_RUN=1` pornește interfața și folderele fără să modifice lista din Dock.
