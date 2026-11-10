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
