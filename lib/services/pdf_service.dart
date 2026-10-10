import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pet.dart';
import '../models/health_event.dart';

/// Le dossier PDF du carnet de santé — mêmes sections que sur le site :
/// identité de l'animal, puis l'historique complet. Généré entièrement
/// sur l'appareil, aucune donnée n'est envoyée à un serveur pour ça.
class PdfService {
  static const _encre = PdfColor.fromInt(0xFF2A2118);
  static const _papier = PdfColor.fromInt(0xFFF4EDDC);

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Les polices intégrées au PDF sont codées en WinAnsi : les signes
  /// typographiques (tiret long, apostrophes, guillemets, points de
  /// suspension, œ…) y ont leur propre code. Sans cette conversion, ils
  /// sortiraient en cases vides (même conversion que la synthèse).
  static const _winAnsi = <int, int>{
    0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85,
    0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A,
    0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92,
    0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
    0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C,
    0x017E: 0x9E, 0x0178: 0x9F,
  };

  static String _pdf(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r < 0x80 || (r >= 0xA0 && r <= 0xFF)) {
        b.writeCharCode(r);
      } else if (_winAnsi.containsKey(r)) {
        b.writeCharCode(_winAnsi[r]!);
      } else if ((r >= 0x2000 && r <= 0x200A) || r == 0x202F || r == 0x205F || r == 0x3000) {
        b.writeCharCode(0xA0);
      } else if (r == 0x2212 || r == 0x2010 || r == 0x2011) {
        b.write('-');
      }
    }
    return b.toString();
  }

  /// Construit le PDF et le sauvegarde dans un fichier temporaire, prêt
  /// à être partagé ou ouvert.
  static Future<File> genererDossier({
    required Pet pet,
    required List<HealthEvent> evenements,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    final identite = <List<String>>[
      ['Espèce', pet.species + (pet.breed != null && pet.breed!.isNotEmpty ? ' — ${pet.breed}' : '')],
      ['Sexe', (pet.sex ?? '—') + (pet.sterilized ? ' (stérilisé·e)' : '')],
      [
        'Naissance',
        pet.birthdate != null
            ? '${_fmt(pet.birthdate!)}${pet.ageYears != null ? ' (${pet.ageYears} an${pet.ageYears! > 1 ? 's' : ''})' : ''}'
            : '—',
      ],
      ['Poids', pet.weightKg != null ? '${pet.weightKg} kg' : '—'],
      ['Allergies', (pet.allergies != null && pet.allergies!.isNotEmpty) ? pet.allergies! : '—'],
      ['Antécédents', (pet.conditions != null && pet.conditions!.isNotEmpty) ? pet.conditions! : '—'],
    ];

    final historique = List<HealthEvent>.from(evenements)
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_pdf(pet.name), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _encre)),
                  pw.SizedBox(height: 2),
                  pw.Text(_pdf(
                    'Dossier généré par Tyto le ${_fmt(now)} — ne remplace pas un avis vétérinaire'),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 12),
                ],
              )
            : pw.SizedBox(),
        build: (context) => [
          pw.Text(_pdf('Identité'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _encre)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: const {0: pw.FlexColumnWidth(1.3), 1: pw.FlexColumnWidth(3)},
            children: identite
                .map((row) => pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _papier),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(_pdf(row[0]), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _encre)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(_pdf(row[1]), style: const pw.TextStyle(fontSize: 10, color: _encre)),
                        ),
                      ],
                    ))
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(_pdf('Carnet de santé et observations'),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _encre)),
          pw.SizedBox(height: 6),
          if (historique.isEmpty)
            pw.Text(_pdf('Carnet vide'), style: const pw.TextStyle(fontSize: 10, color: _encre))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.1),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(2.4),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _papier),
                  children: ['Date', 'Événement', 'Échéance', 'Notes']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_pdf(h), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _encre)),
                          ))
                      .toList(),
                ),
                ...historique.map((ev) {
                  final evenement = ev.libelle + (ev.valueNum != null ? ' — ${ev.valueNum} kg' : '');
                  final echeance = ev.nextDue != null ? 'rappel le ${_fmt(ev.nextDue!)}' : '';
                  final cellules = [_fmt(ev.eventDate), evenement, echeance, ev.notes ?? ''];
                  return pw.TableRow(
                    children: cellules
                        .map((texte) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(_pdf(texte), style: const pw.TextStyle(fontSize: 9.5, color: _encre)),
                            ))
                        .toList(),
                  );
                }),
              ],
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dossier_${pet.name}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
