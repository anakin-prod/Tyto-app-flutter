#!/usr/bin/env python3
"""
Prépare le projet iOS pendant la compilation (Codemagic).

Le dépôt n'a pas de dossier `ios` (le projet Xcode). Ce script le fait
générer par Flutter, puis y règle tout ce que Tyto demande :

  - l'identifiant de l'app (bundle id)
  - les permissions : appareil photo, photos, micro, dictée vocale
  - le lien de connexion par email (app.tytoai.twa://login-callback)
  - iPhone seulement (pas de captures d'iPad à fournir)
  - l'icône 1024x1024 (ios_setup/icone-1024.png) et une icône au choix, ivoire
    (ios_setup/icone-ivoire-1024.png), changeable depuis Paramètres
  - deux petits ponts Swift : le changement d'icône, et le son de la chouette
    à l'envoi d'un message
  - la notification au premier plan (UNUserNotificationCenter)
  - un écran de démarrage sombre, comme l'app (pas de flash blanc)
  - « pas de chiffrement soumis à déclaration » (évite une question à chaque envoi)
  - les achats intégrés Apple (RevenueCat) : ce script remplace le fichier vide
    lib/services/achats_service.dart par ios_setup/achats_ios.dart et ajoute le
    paquet purchases_flutter. Les compilations Android ne les voient jamais.

On peut le relancer sans risque : chaque étape vérifie avant de modifier.

Usage, à la racine du dépôt :   python3 ios_setup/prepare_ios.py
Variables :  IOS_BUNDLE_ID   (défaut : app.tytoai.tyto)
             SKIP_FLUTTER_CREATE=1   (tests : ne génère pas le projet, n'ajoute pas le paquet)
             TYTO_ROOT       (tests : autre racine que le dossier parent)
"""

import json
import os
import plistlib
import re
import shutil
import subprocess
import sys

BUNDLE_ID = os.environ.get("IOS_BUNDLE_ID", "app.tytoai.tyto")
ROOT = os.environ.get("TYTO_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS = os.path.join(ROOT, "ios")
RUNNER = os.path.join(IOS, "Runner")

# L'identifiant que « flutter create --org app.tytoai --project-name tyto_app »
# donne par défaut (projet « tyto_app » → « tytoApp »).
ID_PAR_DEFAUT = "app.tytoai.tytoApp"

# Le lien de connexion par email : le même schéma que sur Android.
SCHEMA_CONNEXION = "app.tytoai.twa"

PERMISSIONS = {
    "NSCameraUsageDescription":
        "Tyto utilise l'appareil photo pour analyser une photo de ton animal ou lire une ordonnance.",
    "NSPhotoLibraryUsageDescription":
        "Tyto accède à tes photos pour que tu puisses en choisir une à analyser.",
    "NSMicrophoneUsageDescription":
        "Le micro sert à dicter tes questions et tes observations.",
    "NSSpeechRecognitionUsageDescription":
        "La reconnaissance vocale transforme ta voix en texte pour dicter tes messages.",
}


def info(msg):
    print("  ✓", msg)


def avertir(msg):
    print("  ⚠️ ", msg)


def lire(chemin):
    with open(chemin, encoding="utf-8") as f:
        return f.read()


def ecrire(chemin, contenu):
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(contenu)


# ------------------------------------------------------------------
def generer_projet():
    print("1) Projet iOS")
    if os.path.isdir(os.path.join(IOS, "Runner.xcodeproj")):
        info("le dossier ios existe déjà")
        return
    if os.environ.get("SKIP_FLUTTER_CREATE") == "1":
        sys.exit("Pas de dossier ios et SKIP_FLUTTER_CREATE=1 : rien à préparer.")
    # Ajoute iOS à un projet existant, sans toucher à Android ni à lib/.
    subprocess.run(
        ["flutter", "create", "--platforms=ios", "--org", "app.tytoai", "--project-name", "tyto_app", "."],
        cwd=ROOT,
        check=True,
    )
    info("dossier ios généré par Flutter")


# ------------------------------------------------------------------
def regler_projet_xcode():
    print("2) Identifiant et appareils")
    chemin = os.path.join(IOS, "Runner.xcodeproj", "project.pbxproj")
    contenu = lire(chemin)
    avant = contenu

    # Les deux cibles (app et tests) portent l'identifiant ; « .RunnerTests »
    # en suffixe est conservé.
    contenu = contenu.replace(ID_PAR_DEFAUT, BUNDLE_ID)
    nb_id = len(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = " + re.escape(BUNDLE_ID) + r"[;.]", contenu))
    if nb_id == 0:
        sys.exit(f"Identifiant {BUNDLE_ID} introuvable après remplacement : modèle Flutter inattendu.")
    info(f"identifiant d'app : {BUNDLE_ID} ({nb_id} occurrence(s))")

    # iPhone seulement : « 1,2 » = iPhone + iPad → « 1 » = iPhone.
    contenu, nb_fam = re.subn(r'TARGETED_DEVICE_FAMILY = "1,2";', 'TARGETED_DEVICE_FAMILY = "1";', contenu)
    info(f"iPhone seulement ({nb_fam} réglage(s))")

    if contenu != avant:
        ecrire(chemin, contenu)


# ------------------------------------------------------------------
def regler_info_plist():
    print("3) Permissions et lien de connexion")
    chemin = os.path.join(RUNNER, "Info.plist")
    with open(chemin, "rb") as f:
        plist = plistlib.load(f)

    plist["CFBundleDisplayName"] = "Tyto"
    plist["CFBundleName"] = "Tyto"
    for cle, texte in PERMISSIONS.items():
        plist[cle] = texte
    info("permissions : appareil photo, photos, micro, dictée vocale")

    # Évite la question « chiffrement » à chaque envoi à Apple : Tyto n'utilise
    # que le chiffrement standard du système (HTTPS).
    plist["ITSAppUsesNonExemptEncryption"] = False

    # Le lien de connexion par email ouvre l'app via ce schéma.
    types = plist.get("CFBundleURLTypes", [])
    if not any(SCHEMA_CONNEXION in t.get("CFBundleURLSchemes", []) for t in types):
        types.append({
            "CFBundleTypeRole": "Editor",
            "CFBundleURLName": BUNDLE_ID,
            "CFBundleURLSchemes": [SCHEMA_CONNEXION],
        })
    plist["CFBundleURLTypes"] = types
    info(f"lien de connexion : {SCHEMA_CONNEXION}://login-callback")

    # Liens ouverts depuis l'app (site, mail, téléphone).
    requetes = set(plist.get("LSApplicationQueriesSchemes", []))
    requetes.update(["https", "http", "mailto", "tel", "sms"])
    plist["LSApplicationQueriesSchemes"] = sorted(requetes)

    with open(chemin, "wb") as f:
        plistlib.dump(plist, f)


# ------------------------------------------------------------------
def regler_appdelegate():
    print("4) Notifications au premier plan")
    chemin = os.path.join(RUNNER, "AppDelegate.swift")
    if not os.path.isfile(chemin):
        avertir("AppDelegate.swift introuvable : étape ignorée")
        return
    contenu = lire(chemin)
    if "UNUserNotificationCenter" in contenu:
        info("déjà réglé")
        return

    ancre = "return super.application(application, didFinishLaunchingWithOptions: launchOptions)"
    if ancre not in contenu:
        avertir("modèle d'AppDelegate inattendu : étape ignorée (les notifications marcheront app fermée)")
        return

    # L'ancre est déjà précédée de son indentation dans le fichier : la première
    # ligne insérée n'a donc pas la sienne.
    bloc = (
        "// Affiche aussi les notifications quand l'app est ouverte.\n"
        "    if #available(iOS 10.0, *) {\n"
        "      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate\n"
        "    }\n"
        "    "
    )
    contenu = contenu.replace(ancre, bloc + ancre, 1)
    if "import UserNotifications" not in contenu:
        contenu = contenu.replace("import UIKit", "import UIKit\nimport UserNotifications", 1)
    ecrire(chemin, contenu)
    info("délégué de notifications ajouté")


# ------------------------------------------------------------------
def regler_icone():
    print("5) Icône")
    source = os.path.join(ROOT, "ios_setup", "icone-1024.png")
    dossier = os.path.join(RUNNER, "Assets.xcassets", "AppIcon.appiconset")
    if not os.path.isfile(source):
        avertir("ios_setup/icone-1024.png introuvable : icône Flutter par défaut conservée")
        return
    if not os.path.isdir(dossier):
        avertir("AppIcon.appiconset introuvable : étape ignorée")
        return
    # Xcode 14+ accepte une seule icône 1024x1024 et génère toutes les tailles.
    for nom in os.listdir(dossier):
        if nom.lower().endswith(".png"):
            os.remove(os.path.join(dossier, nom))
    shutil.copyfile(source, os.path.join(dossier, "icon-1024.png"))
    contenu = {
        "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }
    ecrire(os.path.join(dossier, "Contents.json"), json.dumps(contenu, indent=2) + "\n")
    info("icône 1024x1024 en place")


# ------------------------------------------------------------------
NOM_ICONE_IVOIRE = "AppIcon-Ivoire"
CANAL_ICONE = "app.tytoai/icone"

# Le code Swift des petits « ponts » entre l'appli et iOS. Il est ajouté tel
# quel à la fin d'AppDelegate.swift : pas de nouveau fichier à déclarer dans
# Xcode, et pas de paquet externe.
#   - IconeAlternativePlugin : change l'icône (Paramètres > Icône de l'appli)
#   - SonInterfacePlugin : joue le « hou » de la chouette à l'envoi d'un message
CODE_SWIFT_ICONE = """
// --- Icône de l'appli au choix (Paramètres) : ajouté par prepare_ios.py ---
class IconeAlternativePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(name: "%s", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(IconeAlternativePlugin(), channel: canal)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "actuelle":
      result(UIApplication.shared.alternateIconName)
    case "definir":
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "non_supporte", message: "Icônes alternatives non supportées", details: nil))
        return
      }
      let nom = call.arguments as? String
      UIApplication.shared.setAlternateIconName(nom) { erreur in
        if let erreur = erreur {
          result(FlutterError(code: "echec", message: erreur.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
""" % CANAL_ICONE

CANAL_SON = "app.tytoai/son"

# Les sons sont copiés par l'appli dans Library/Sounds au lancement (comme pour
# les sons de notification) : on les y retrouve par leur nom.
CODE_SWIFT_SON = """
// --- Petit son de l'appli (chouette à l'envoi d'un message) : ajouté par prepare_ios.py ---
class SonInterfacePlugin: NSObject, FlutterPlugin {
  private var identifiants: [String: SystemSoundID] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(name: "%s", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SonInterfacePlugin(), channel: canal)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "jouer" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let arguments = call.arguments as? [String: Any]
    guard let nom = arguments?["nom"] as? String else {
      result(nil)
      return
    }
    if identifiants[nom] == nil {
      if let bibliotheque = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
        let fichier = bibliotheque.appendingPathComponent("Sounds").appendingPathComponent(nom + ".wav")
        if FileManager.default.fileExists(atPath: fichier.path) {
          var identifiant: SystemSoundID = 0
          if AudioServicesCreateSystemSoundID(fichier as CFURL, &identifiant) == kAudioServicesNoError {
            identifiants[nom] = identifiant
          }
        }
      }
    }
    if let identifiant = identifiants[nom] {
      AudioServicesPlaySystemSound(identifiant)
    }
    result(nil)
  }
}
""" % CANAL_SON

PONTS_SWIFT = [
    ("IconeAlternativePlugin", CODE_SWIFT_ICONE),
    ("SonInterfacePlugin", CODE_SWIFT_SON),
]


def ajouter_ponts_swift():
    print("5c) Ponts Swift (icône, son)")
    chemin = os.path.join(RUNNER, "AppDelegate.swift")
    if not os.path.isfile(chemin):
        avertir("AppDelegate.swift introuvable : ni le changement d'icône ni le son d'envoi ne marcheront")
        return
    swift = lire(chemin)
    m = re.search(r"^([ \t]*)GeneratedPluginRegistrant\.register\(with: (.+)\)\s*$", swift, re.M)
    if not m:
        avertir("ligne d'enregistrement des plugins non trouvée : ni le changement d'icône ni le son d'envoi ne marcheront")
        return
    indent, registre = m.group(1), m.group(2)
    modifie = False
    for nom, code in PONTS_SWIFT:
        if nom in swift:
            info(f"{nom} déjà présent")
            continue
        m = re.search(r"^([ \t]*)GeneratedPluginRegistrant\.register\(with: (.+)\)\s*$", swift, re.M)
        ajout = (
            "\n" + indent + "if let r = (" + registre + ').registrar(forPlugin: "' + nom + '") {\n'
            + indent + "  " + nom + ".register(with: r)\n"
            + indent + "}"
        )
        swift = swift[: m.end()].rstrip("\n") + ajout + swift[m.end():]
        swift = swift.rstrip("\n") + "\n" + code
        modifie = True
        info(f"{nom} ajouté")
    # Le son utilise AudioToolbox.
    if modifie and "import AudioToolbox" not in swift:
        swift = swift.replace("import UIKit", "import UIKit\nimport AudioToolbox", 1)
    if modifie:
        ecrire(chemin, swift)


def regler_icone_alternative():
    print("5b) Icône au choix (ivoire)")
    source = os.path.join(ROOT, "ios_setup", "icone-ivoire-1024.png")
    catalogue = os.path.join(RUNNER, "Assets.xcassets")
    if not os.path.isfile(source):
        avertir("ios_setup/icone-ivoire-1024.png introuvable : pas d'icône au choix")
        return
    if not os.path.isdir(catalogue):
        avertir("Assets.xcassets introuvable : pas d'icône au choix")
        return

    # 1) le jeu d'icônes alternatif, à côté de AppIcon
    dossier = os.path.join(catalogue, NOM_ICONE_IVOIRE + ".appiconset")
    os.makedirs(dossier, exist_ok=True)
    shutil.copyfile(source, os.path.join(dossier, "icon-1024.png"))
    contenu = {
        "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }
    ecrire(os.path.join(dossier, "Contents.json"), json.dumps(contenu, indent=2) + "\n")
    info("jeu d'icônes " + NOM_ICONE_IVOIRE + " en place")

    # 2) le réglage Xcode qui déclare cette icône comme alternative
    chemin = os.path.join(IOS, "Runner.xcodeproj", "project.pbxproj")
    pbx = lire(chemin)
    if "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES" in pbx:
        info("réglage Xcode déjà présent")
    else:
        pbx, nb = re.subn(
            r"(\t+)(ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;)",
            lambda m: m.group(1) + m.group(2) + "\n" + m.group(1)
            + 'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "' + NOM_ICONE_IVOIRE + '";',
            pbx,
        )
        if nb == 0:
            avertir("réglage d'icône non trouvé dans le projet Xcode : l'icône ivoire ne sera pas proposée")
        else:
            ecrire(chemin, pbx)
            info(f"réglage Xcode ajouté ({nb} configuration(s))")


# ------------------------------------------------------------------
def regler_ecran_demarrage():
    print("6) Écran de démarrage")
    chemin = os.path.join(RUNNER, "Base.lproj", "LaunchScreen.storyboard")
    if not os.path.isfile(chemin):
        avertir("LaunchScreen.storyboard introuvable : étape ignorée")
        return
    contenu = lire(chemin)
    # Fond de l'app (#151C2C) au lieu du blanc.
    nuit = '<color key="backgroundColor" red="0.0823" green="0.1098" blue="0.1725" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>'
    if 'red="0.0823" green="0.1098"' in contenu:
        info("déjà réglé")
        return
    nouveau, nb = re.subn(r'<color key="backgroundColor"[^>]*systemBackgroundColor[^>]*/>', nuit, contenu, count=1)
    if nb == 0:
        avertir("couleur de fond non trouvée : écran de démarrage inchangé (blanc)")
        return
    ecrire(chemin, nouveau)
    info("fond sombre")


# ------------------------------------------------------------------
# Version de RevenueCat figée : l'API d'achat a changé à la version 9 (le
# résultat d'un achat n'a plus la même forme). Le code d'achats_ios.dart
# gère les deux, mais on garde une version connue pour éviter les surprises.
PAQUET_ACHATS = "purchases_flutter:>=8.8.1 <9.0.0"


def injecter_achats():
    print("7) Achats intégrés Apple (RevenueCat)")
    source = os.path.join(ROOT, "ios_setup", "achats_ios.dart")
    cible = os.path.join(ROOT, "lib", "services", "achats_service.dart")
    if not os.path.isfile(source):
        avertir("ios_setup/achats_ios.dart introuvable : achats non injectés (l'app iOS n'aura aucun bouton d'achat)")
        return
    shutil.copyfile(source, cible)
    info("lib/services/achats_service.dart remplacé par la version iOS")

    pubspec = lire(os.path.join(ROOT, "pubspec.yaml"))
    if "purchases_flutter" in pubspec:
        info("purchases_flutter déjà déclaré")
    elif os.environ.get("SKIP_FLUTTER_CREATE") == "1":
        info("(test) ajout du paquet ignoré")
    else:
        subprocess.run(["flutter", "pub", "add", PAQUET_ACHATS], cwd=ROOT, check=True)
        info("paquet purchases_flutter ajouté")


# ------------------------------------------------------------------
if __name__ == "__main__":
    print(f"Préparation iOS — identifiant : {BUNDLE_ID}")
    generer_projet()
    regler_projet_xcode()
    regler_info_plist()
    regler_appdelegate()
    regler_icone()
    regler_icone_alternative()
    ajouter_ponts_swift()
    regler_ecran_demarrage()
    injecter_achats()
    print("Terminé.")
