# ChordHub

ChordHub je Flutter aplikácia na prácu s piesňami vo formáte ChordPro (`.pro`).

## Funkcie

- načítanie celého priečinka so súbormi `.pro`
- zobrazenie textu s akordami
- transpozícia akordov v rozsahu `-11` až `+11`
- úprava obsahu piesne a uloženie späť do pôvodného súboru

## Spustenie

1. `flutter pub get`
2. `flutter run`

Po spustení klikni na **Vybrať priečinok** a zvoľ priečinok so svojimi `.pro` súbormi.

## Web a Google Disk

Windows aplikácia naďalej používa lokálny priečinok (ten môže byť synchronizovaný napríklad cez Google Drive pre počítače). Webová verzia pracuje priamo s priečinkom na Google Disku cez Google Drive API.

### Nastavenie Google aplikácie

1. V [Google Cloud Console](https://console.cloud.google.com/) vytvor projekt.
2. V **APIs & Services → Library** zapni **Google Drive API**.
3. V **APIs & Services → OAuth consent screen** nastav aplikáciu (typ *External*). Kým aplikácia nie je overená, pridaj všetkých používateľov do **Test users**.
4. V **Credentials → Create credentials → OAuth client ID** zvoľ **Web application** a pridaj **Authorized JavaScript origins**:
	- `http://localhost:7357` na lokálne testovanie
	- `https://tvoja-domena.sk` pre nasadenú aplikáciu

   Redirect URI nie je potrebné vypĺňať. Client secret nepotrebujeme; do webovej aplikácie patrí iba verejné **Client ID**.
5. Na Google Disku zdieľaj priečinok s každým používateľom cez jeho Google účet s rolou **Editor**. Použi odkaz na priečinok (`https://drive.google.com/drive/folders/...`).

Aplikácia žiada oprávnenie `https://www.googleapis.com/auth/drive`, pretože musí čítať a upravovať súbory v priečinku, ktorý jej nepatrí. Užšie oprávnenie `drive.file` na to nestačí.

### Spustenie webovej verzie

Client ID vlož do `lib/pages/songbook_page.dart` (`GOOGLE_CLIENT_ID`) alebo ho zadaj pri spustení:

```powershell
flutter run -d chrome --web-port=7357 --dart-define=GOOGLE_CLIENT_ID=TVOJE-CLIENT-ID.apps.googleusercontent.com
```

Pri prvom pripojení sa používateľ prihlási vlastným Google účtom a vloží odkaz na priečinok. Odkaz sa uloží iba v danom prehliadači. Prístupový token platí približne hodinu, potom sa obnoví automaticky alebo po opätovnom kliknutí na **Pripojiť Google Disk**.

Produkčný build:

```powershell
flutter build web --release --dart-define=GOOGLE_CLIENT_ID=TVOJE-CLIENT-ID.apps.googleusercontent.com
```

Presná produkčná adresa (origin) musí byť pridaná v Google Cloud Console. Ak sa tá istá skladba upraví súčasne, aplikácia odmietne prepísať novšiu verziu a zobrazí upozornenie; treba obnoviť zoznam a zmeny zopakovať. Zmazané skladby a priečinky sa presúvajú do koša na Google Disku.

### Rýchlosť a obnovenie po štarte

Naposledy načítaný zoznam sa ukladá v prehliadači. Po otvorení aplikácie sa zobrazí hneď a na pozadí sa aktualizuje; z Google Disku sa sťahujú iba skladby, ktoré sa zmenili. Prístupový token Google platí približne hodinu a bez kliknutia ho prehliadač nepustí obnoviť. Ak vyprší, zobrazí sa hore pruh **Prihlásiť sa** a zoznam ostane viditeľný. Po odhlásení sa uložený zoznam zmaže.

### Poradie skladieb v podpriečinkoch

Keď v podpriečinku presunieš skladbu (alebo uložíš poradie z tvorby playlistu), poradie sa uloží do názvov súborov pomocou číselnej predpony, napr. `01 - Aleluja.pro`, `02 - Amazing Grace.pro`. Vďaka tomu je poradie rovnaké na každom zariadení a na Google Disku. Predpona sa v aplikácii nezobrazuje a nemení názov skladby. Skladby bez predpony idú na koniec. Kópia skladby do už očíslovaného podpriečinka sa zaradí na koniec. Hlavný priečinok sa tým nemení, jeho poradie sa naďalej pamätá len v danom zariadení.

### Mobil a tablet

- **Mobil** (užšie ako 700 px): zobrazí sa zoznam skladieb a po kliknutí na skladbu jej detail s tlačidlom Späť. Ostatné akcie sú v menu `⋮`.
- **Tablet** (700 až 1100 px): zoznam a detail vedľa seba, tlačidlá detailu sa zalomia pod názov.
- **Počítač**: pôvodné rozloženie.
- **Fullscreen na mobile a tablete:** otvorí sa dvojklikom na skladbu. Vo fullscreene jedno klepnutie pozastaví alebo znovu spustí scrollovanie. Na mobile sú transpozícia, veľkosť textu a rýchlosť v paneli pod tlačidlom `tune`. Text sa dá zväčšiť štiepením prstami (alebo tlačidlami). Nastavená veľkosť sa pamätá aj pre ďalšie skladby. Ak je najdlhší riadok po zväčšení širší než displej, skladba sa dá posúvať aj do strán.

### Pevne daný priečinok

Odkaz na priečinok so skladbami je v `lib/pages/songbook_page.dart` v konštante `_fixedDriveFolderUrl` (alebo sa zadá cez `--dart-define=DRIVE_FOLDER_URL=...`). Používateľ sa potom len prihlási do Google účtu a odkaz nezadáva. Pri prázdnej konštante sa odkaz pýta ako predtým.

Priečinok sa na Google Disku zdieľa cez **Zdieľať → Všeobecný prístup → Každý, kto má odkaz** (rola *Editor* na úpravy, *Čitateľ* len na prezeranie). Súbory v ňom dedia rovnaké oprávnenie.

### Prepínanie skladieb, kolá a návrat do zoznamu

- V detaile skladby (aj vo fullscreene) sú šípky na predchádzajúcu a nasledujúcu skladbu v poradí, v akom sú v zozname (pri podpriečinku v poradí playlistu). Vedľa šípok je poloha, napr. `Kolo 2 · 3 / 12`.
- Keď v zostavovači playlistu rozdelíš skladby do kôl a uložíš poradie, kolo sa uloží do názvu súboru, napr. `K2-05 - Aleluja.pro` (kolo 2, poradie 5). Pri skladbách v podpriečinkoch sa potom pri názve zobrazí `Kolo 2` a zostavovač playlistu ich pri otvorení vráti do ich kôl. Skladby bez kola majú názov `05 - Aleluja.pro`.
- Pri ručnom presune skladby v zozname prevezme presunutá skladba kolo skladby nad sebou.
- Na mobile a tablete sa po návrate z detailu zoznam zobrazí na rovnakom mieste a s rozbalenými priečinkami a pri prepnutí šípkami sa doscrolluje k aktuálnej skladbe.

