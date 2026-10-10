import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// La page « Imprimer » de la synthèse vétérinaire du site
/// (printVetReport), mise en PDF : chouette et titre, date de génération,
/// filet, puis le texte avec ses passages en gras. Le fichier est ensuite
/// proposé au partage, d'où il s'imprime ou s'envoie au vétérinaire.
class CarnetSynthesePdf {
  static const _encre = PdfColor.fromInt(0xFF2A2118);

  /// La chouette du site, celle qui précède le titre de la page imprimée.
  static const _chouette =
      '<svg width="26" height="33" viewBox="0 0 120 150" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M60 12 C43 14, 31 27, 29 45 C27 62, 31 85, 37 103 C42 116, 49 127, 60 131 C71 127, 78 116, 83 103 C89 85, 93 62, 91 45 C89 27, 77 14, 60 12 Z" stroke="#2A2118" stroke-width="3" stroke-linejoin="round"/>'
      '<path d="M60 26 C50 23, 40 29, 38 41 C36 54, 46 66, 60 74 C74 66, 84 54, 82 41 C80 29, 70 23, 60 26 Z" stroke="#2A2118" stroke-width="2.6" stroke-linejoin="round"/>'
      '<path d="M60 27 L60 52" stroke="#2A2118" stroke-width="1.6" opacity="0.5"/>'
      '<ellipse cx="50" cy="45" rx="3.6" ry="4.4" fill="#2A2118"/>'
      '<ellipse cx="70" cy="45" rx="3.6" ry="4.4" fill="#2A2118"/>'
      '<path d="M60 52 L57.4 59 L60 65 L62.6 59 Z" stroke="#2A2118" stroke-width="2" stroke-linejoin="round"/>'
      '<path d="M20 145 C40 140.5, 84 141.5, 101 144.5" stroke="#2A2118" stroke-width="2.6" stroke-linecap="round"/>'
      '<g stroke="#2A2118" stroke-width="2.4" stroke-linecap="round">'
      '<path d="M52 130 L50 141 M50 141 L46 146 M50 141 L50 147 M50 141 L54 146"/>'
      '<path d="M68 130 L70 141 M70 141 L66 146 M70 141 L70 147 M70 141 L74 146"/>'
      '</g></svg>';

  /// Les polices intégrées au PDF (Times) sont codées en WinAnsi : les
  /// signes typographiques courants (tirets, apostrophes, guillemets,
  /// points de suspension, œ…) y ont leur propre code, à 1 octet. Sans
  /// cette conversion, ils seraient remplacés par une case vide.
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
        b.writeCharCode(0xA0); // espaces fines ou insécables
      } else if (r == 0x2212 || r == 0x2010 || r == 0x2011) {
        b.write('-');
      }
      // Tout autre signe (hors de l'alphabet latin) est laissé de côté.
    }
    return b.toString();
  }

  /// La chouette (26 x 33 px, soit 19,5 x 24,75 pt) ; si le dessin ne
  /// pouvait être lu, le titre s'imprime seul plutôt que d'échouer.
  static pw.Widget _logo() {
    try {
      return pw.SvgImage(svg: _chouette, width: 19.5, height: 24.75);
    } catch (e) {
      return pw.SizedBox(width: 19.5, height: 24.75);
    }
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Construit le PDF et l'enregistre dans un fichier temporaire.
  static Future<File> generer({required String nomAnimal, required String contenu}) async {
    final doc = pw.Document();
    final serif = pw.Font.times();
    final serifGras = pw.Font.timesBold();
    // Georgia 16 px, interligne 1,6 (en points : 12 pt, 7,2 pt d'interligne).
    final corps = pw.TextStyle(font: serif, fontSize: 12, color: _encre, lineSpacing: 7.2);
    final gras = corps.copyWith(font: serifGras);

    pw.Widget paragraphe(String ligne) {
      if (ligne.trim().isEmpty) return pw.SizedBox(height: 12);
      final morceaux = ligne.split('**');
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(
          text: pw.TextSpan(
            style: corps,
            children: [
              for (var i = 0; i < morceaux.length; i++)
                pw.TextSpan(text: _pdf(morceaux[i]), style: i.isOdd ? gras : corps),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 34, 42, 34),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _logo(),
              pw.SizedBox(width: 4.5),
              pw.Expanded(
                child: pw.Text(
                  _pdf('Synthèse vétérinaire — $nomAnimal'),
                  style: pw.TextStyle(font: serifGras, fontSize: 16.5, color: _encre),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            _pdf('Générée par Tyto le ${_date(DateTime.now())}'),
            style: pw.TextStyle(font: serif, fontSize: 10, color: const PdfColor.fromInt(0xFF777777)),
          ),
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 10.5),
            height: 0.75,
            color: const PdfColor.fromInt(0xFFCCCCCC),
          ),
          for (final ligne in contenu.split('\n')) paragraphe(ligne),
        ],
      ),
    );

    final dossier = await getTemporaryDirectory();
    final nomFichier = nomAnimal.replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ_-]+'), '_');
    final fichier = File('${dossier.path}/synthese_$nomFichier.pdf');
    await fichier.writeAsBytes(await doc.save());
    return fichier;
  }
}
