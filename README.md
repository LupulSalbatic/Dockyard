# Dockyard — foldere de aplicații în Dock

Pune în Dock „foldere” care conțin mai multe aplicații, fiecare cu iconița pe care o alegi.
Folderele există **doar cât timp Dockyard rulează**: când închizi aplicația (⌘Q), dispar din Dock,
iar la următoarea pornire revin exact unde erau, cu aceleași aplicații.

## Cum îl folosești
1. Deschide `dist/Dockyard.app`.
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
Totul stă în folderul aplicației, în `dist/Dockyard Data/`:
- `folders.json`: folderele, aplicațiile, iconițele și pozițiile din Dock
- `Icons/`: imaginile alese ca iconiță
- `Tiles/`: mini-aplicațiile care apar în Dock, câte una pentru fiecare folder

În afara folderului, Dockyard modifică doar lista din Dock, cât timp rulează. La închidere o pune la loc și șterge fișierele pe care macOS le creează automat pentru aplicație.

## Build
```sh
./scripts/build-app.sh      # creează dist/Dockyard.app (necesită Xcode)
```
Cache-urile de compilare rămân în `.build/`, iar urmele inevitabile ale compilatorului din afara proiectului sunt șterse automat.

## Testare fără a atinge Dock-ul
`open dist/Dockyard.app --env DOCKYARD_DRY_RUN=1` pornește interfața și folderele fără să modifice lista din Dock.
