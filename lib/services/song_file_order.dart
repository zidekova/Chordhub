// Poradie skladieb v podpriečinkoch sa ukladá priamo do názvu súboru
// ako číselná predpona, napr. "01 - Aleluja.pro". Vďaka tomu sa poradie
// zachová na každom zariadení aj na Google Disku. Ak je skladba zaradená do
// kola playlistu, predpona obsahuje aj kolo: "K2-05 - Aleluja.pro".
class SongFileOrder {
  static final RegExp _prefix = RegExp(r'^(?:K(\d)-)?(\d{1,3}) - (?=\S)');

  /// Číslo z predpony názvu súboru, alebo null, ak súbor predponu nemá.
  static int? orderOf(String fileName) {
    final match = _prefix.firstMatch(fileName);
    return match == null ? null : int.parse(match.group(2)!);
  }

  /// Číslo kola z predpony ("K2-05 - X.pro" -> 2), alebo null, ak skladba nie je v kole.
  static int? roundOf(String fileName) {
    final match = _prefix.firstMatch(fileName);
    final round = match?.group(1);
    return round == null ? null : int.parse(round);
  }

  /// Názov bez číselnej predpony ("01 - Aleluja.pro" -> "Aleluja.pro").
  static String stripPrefix(String fileName) =>
      fileName.replaceFirst(_prefix, '');

  /// Názov s predponou zodpovedajúcou poradiu ("Aleluja.pro" -> "01 - Aleluja.pro").
  /// S [round] pribudne aj kolo ("K2-01 - Aleluja.pro").
  static String withOrder(
    String fileName,
    int order, {
    int width = 2,
    int? round,
  }) {
    final number = order.toString().padLeft(width, '0');
    final roundPart = round == null ? '' : 'K$round-';
    return '$roundPart$number - ${stripPrefix(fileName)}';
  }

  /// Šírka čísla pre daný počet skladieb (aspoň 2 číslice).
  static int widthFor(int count) => count >= 100 ? 3 : 2;

  /// Najvyššie číslo predpony medzi názvami, alebo null, ak ju nemá žiadny.
  static int? highestOrder(Iterable<String> fileNames) {
    int? highest;
    for (final name in fileNames) {
      final order = orderOf(name);
      if (order != null && (highest == null || order > highest)) {
        highest = order;
      }
    }
    return highest;
  }

  /// Názov pre kópiu skladby v cieľovom priečinku.
  /// V podpriečinku, ktorý už má očíslované skladby, sa kópia zaradí na koniec.
  /// V hlavnom priečinku sa predpona odstráni.
  static String nameForCopy({
    required String sourceFileName,
    required bool targetIsSubfolder,
    required Iterable<String> existingNames,
  }) {
    final clean = stripPrefix(sourceFileName);
    final dot = clean.lastIndexOf('.');
    final base = dot <= 0 ? clean : clean.substring(0, dot);
    final extension = dot <= 0 ? '' : clean.substring(dot);
    final taken = {for (final name in existingNames) name.toLowerCase()};

    int? next;
    if (targetIsSubfolder) {
      final highest = highestOrder(existingNames);
      if (highest != null) next = highest + 1;
    }

    String build(String name) {
      final fileName = '$name$extension';
      return next == null
          ? fileName
          : withOrder(fileName, next, width: next > 99 ? 3 : 2);
    }

    var result = build(base);
    var counter = 1;
    while (taken.contains(result.toLowerCase())) {
      result = build('${base}_copy$counter');
      counter++;
    }
    return result;
  }
}
