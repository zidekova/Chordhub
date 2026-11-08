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

## Web a OneDrive

Windows aplikácia naďalej používa lokálny priečinok synchronizovaný OneDrive klientom. Webová verzia pracuje priamo so zdieľaným priečinkom cez Microsoft Graph.

### Nastavenie Microsoft aplikácie

1. V Microsoft Entra admin center vytvor **App registration**. Zvoľ účty z ľubovoľného organizačného adresára aj osobné Microsoft účty.
2. V **Authentication** pridaj platformu **Single-page application (SPA)** a presmerovacie adresy:
	- `http://localhost:7357/redirect.html` na lokálne testovanie
	- `https://tvoja-domena.sk/redirect.html` pre nasadenú aplikáciu
3. V **API permissions** pridaj Microsoft Graph delegated permission `Files.ReadWrite`. Nepotrebujeme client secret; do Flutter web aplikácie patrí iba verejné Application (client) ID.
4. V OneDrive zdieľaj priečinok s každým používateľom cez jeho Microsoft účet a povoľ úpravy. Použi zdieľací odkaz priečinka, nie odkaz na súbor.

### Spustenie webovej verzie

V priečinku projektu:

```powershell
npm install
npm run build
flutter run -d chrome --web-port=7357
```

Application (client) ID je už prednastavené. Ak ho potrebuješ prepísať pre inú registráciu, pridaj `--dart-define=MSAL_CLIENT_ID=TVE-CLIENT-ID`.

Pri prvom pripojení sa používateľ prihlási vlastným Microsoft účtom a vloží zdieľací odkaz. Každý účet musí mať k priečinku pridelené oprávnenie na úpravy. Odkaz sa uloží iba v danom prehliadači.

Pre produkčný build najprv spusti `npm run build`, potom:

```powershell
flutter build web --release
```

Presná produkčná adresa `redirect.html` musí byť tiež zaregistrovaná v Microsoft Entra. Ak sa tá istá skladba upraví súčasne, aplikácia odmietne prepísať novšiu verziu a zobrazí upozornenie; treba obnoviť zoznam a zmeny zopakovať.
