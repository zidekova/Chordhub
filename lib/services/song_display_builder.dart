// Zostavenie riadkov na zobrazenie z parsovanej piesne (skrýva direktívy, označí refrén).
import '../models/song.dart';

class SongDisplayBuilder {
  static List<SongDisplayLine> build(List<String> lines) {
    final output = <SongDisplayLine>[];
    var inChorus = false;

    for (final line in lines) {
      final directive = ParsedSong.tryParseDirective(line);
      if (directive != null) {
        final key = directive.key;
        if (key == 'title' || key == 'subtitle') {
          continue;
        }
        if (key == 'soc' || key == 'start_of_chorus') {
          inChorus = true;
          continue;
        }
        if (key == 'eoc' || key == 'end_of_chorus') {
          inChorus = false;
          continue;
        }
        // Skip any other standalone directive lines (e.g. {scrollspeed: 20})
        continue;
      }

      output.add(SongDisplayLine(rawLine: line, isChorus: inChorus));
    }

    return output;
  }
}
