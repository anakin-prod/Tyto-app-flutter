// ============================================================
// ACHATS INTÉGRÉS APPLE — version iOS (RevenueCat).
//
// Ce fichier est copié sur lib/services/achats_service.dart pendant la
// compilation iOS (voir ios_setup/prepare_ios.py), en même temps que
// l'ajout du paquet purchases_flutter. Il n'existe pas dans les
// compilations Android, qui gardent la version vide : ni RevenueCat, ni
// bibliothèque de facturation de Google Play.
//
// La clé publique RevenueCat (« appl_… ») est fournie à la compilation :
//   flutter build ipa --dart-define=RC_IOS_KEY=appl_xxx
// Sans elle, `disponible` reste faux et l'app se comporte comme avant
// (aucun bouton d'achat).
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../services/legal_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class AchatsService {
  static const _cle = String.fromEnvironment('RC_IOS_KEY');
  static bool _pret = false;

  /// Les noms des « accès » créés dans RevenueCat (Entitlements). Ils doivent
  /// être identiques à REVENUECAT_ENTITLEMENT_PRO / _PREMIUM côté serveur.
  static const _acces = ['pro', 'premium'];

  /// Monte à chaque achat réussi : l'écran principal l'écoute pour
  /// rafraîchir le statut Premium/Pro.
  static final ValueNotifier<int> achatReussi = ValueNotifier<int>(0);

  static bool get disponible => defaultTargetPlatform == TargetPlatform.iOS && _cle.isNotEmpty;

  static bool _aUnAcces(CustomerInfo info) =>
      _acces.any((nom) => info.entitlements.all[nom]?.isActive ?? false);

  static Future<void> demarrer() async {
    if (!disponible || _pret) return;
    try {
      await Purchases.configure(PurchasesConfiguration(_cle));
      _pret = true;
      final utilisateur = Supabase.instance.client.auth.currentUser;
      if (AuthService.isSignedIn && utilisateur != null) {
        await Purchases.logIn(utilisateur.id);
      }
    } catch (e) {
      debugPrint('RevenueCat : démarrage impossible ($e)');
    }
  }

  /// Relie les achats au compte Tyto : l'identifiant utilisé chez RevenueCat
  /// est celui de Supabase, comme côté serveur.
  static Future<void> connecter(String userId) async {
    if (!_pret) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('RevenueCat : connexion impossible ($e)');
    }
  }

  static Future<void> deconnecter() async {
    if (!_pret) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      // Une erreur ici est normale si l'utilisateur était déjà anonyme.
    }
  }

  static Future<bool> ouvrirOffres(BuildContext context) async {
    if (!_pret) return false;
    // On prend le navigateur dès le début : le menu qui appelle cette fonction
    // se referme aussitôt, son contexte ne sera plus valable plus loin.
    final navigateur = Navigator.of(context);

    // Un abonnement s'attache à un vrai compte : sans lui, il ne suivrait
    // pas l'utilisateur d'un téléphone à l'autre.
    if (!AuthService.isSignedIn) {
      await navigateur.push(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => const LoginScreen()),
      );
      if (!AuthService.isSignedIn) return false;
    }
    final utilisateur = Supabase.instance.client.auth.currentUser;
    if (utilisateur != null) await connecter(utilisateur.id);

    final reussi = await navigateur.push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PaywallPage()),
    );
    return reussi == true;
  }

  /// La gestion d'un abonnement Apple se fait dans les réglages d'Apple.
  static Future<void> gererAbonnement() async {
    await launchUrl(
      Uri.parse('https://apps.apple.com/account/subscriptions'),
      mode: LaunchMode.externalApplication,
    );
  }
}

// ------------------------------------------------------------------
// L'écran d'abonnement. Apple exige d'y voir clairement : le nom de
// l'abonnement, sa durée, son prix, le renouvellement automatique, les
// liens vers les conditions et la politique de confidentialité, et un
// bouton « Restaurer mes achats ».
// ------------------------------------------------------------------
class _PaywallPage extends StatefulWidget {
  const _PaywallPage();

  @override
  State<_PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<_PaywallPage> {
  List<Package>? _offres;
  String? _erreur;
  String? _enCours; // identifiant du paquet en cours d'achat
  bool _restauration = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final offerings = await Purchases.getOfferings();
      final paquets = List<Package>.of(offerings.current?.availablePackages ?? const <Package>[]);
      // Du moins cher au plus cher : Premium avant Pro.
      paquets.sort((a, b) => a.storeProduct.price.compareTo(b.storeProduct.price));
      if (!mounted) return;
      setState(() {
        _offres = paquets;
        if (paquets.isEmpty) {
          _erreur = 'Les offres ne sont pas disponibles pour le moment. Réessaie dans un instant.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _offres = [];
        _erreur = 'Impossible de charger les offres. Vérifie ta connexion et réessaie.';
      });
    }
  }

  Future<void> _acheter(Package paquet) async {
    if (_enCours != null || _restauration) return;
    setState(() {
      _enCours = paquet.identifier;
      _erreur = null;
    });
    try {
      // Selon la version de RevenueCat, l'achat renvoie directement les
      // informations du client, ou un résultat qui les contient.
      final dynamic resultat = await Purchases.purchasePackage(paquet);
      final CustomerInfo info = resultat is CustomerInfo ? resultat : resultat.customerInfo;
      if (!mounted) return;
      if (AchatsService._aUnAcces(info)) {
        AchatsService.achatReussi.value++;
        Navigator.pop(context, true);
        return;
      }
      setState(() => _erreur = "L'achat n'a pas pu être confirmé. Si tu as été débité, touche « Restaurer mes achats ».");
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      // Annuler la fenêtre de paiement n'est pas une erreur : on ne dit rien.
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        setState(() => _erreur = "L'achat n'a pas abouti. Réessaie dans un instant.");
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = "L'achat n'a pas abouti. Réessaie dans un instant.");
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  Future<void> _restaurer() async {
    if (_enCours != null || _restauration) return;
    setState(() {
      _restauration = true;
      _erreur = null;
    });
    try {
      final info = await Purchases.restorePurchases();
      if (!mounted) return;
      if (AchatsService._aUnAcces(info)) {
        AchatsService.achatReussi.value++;
        Navigator.pop(context, true);
        return;
      }
      setState(() => _erreur = "Aucun abonnement actif n'a été trouvé sur ton compte Apple.");
    } catch (e) {
      if (mounted) setState(() => _erreur = "La restauration n'a pas abouti. Réessaie dans un instant.");
    } finally {
      if (mounted) setState(() => _restauration = false);
    }
  }

  /// La durée de l'abonnement, que l'écran doit toujours afficher (Apple l'exige).
  /// On regarde le type du paquet, puis le nom du produit : Premium et Pro sont
  /// tous deux « mensuels », et RevenueCat n'accepte qu'un seul paquet « mensuel »
  /// standard par offre — l'autre est donc personnalisé.
  String _periode(Package p) {
    final id = p.storeProduct.identifier.toLowerCase();
    if (p.packageType == PackageType.monthly || id.contains('month')) return ' par mois';
    if (p.packageType == PackageType.annual || id.contains('year') || id.contains('annual')) return ' par an';
    if (p.packageType == PackageType.weekly || id.contains('week')) return ' par semaine';
    return '';
  }

  Widget _carte(Package p) {
    final produit = p.storeProduct;
    final estPro = produit.identifier.toLowerCase().contains('pro');
    final avantages = estPro
        ? const [
            'Tout le plan Premium',
            'Veille sanitaire quotidienne sur tous tes animaux',
            "Lecture d'ordonnance par photo",
            'Synthèse vétérinaire en un clic',
            'Saisie vocale des observations',
            "Journal d'équipe partagé (2 places incluses)",
            'Animaux illimités',
          ]
        : const [
            'Questions illimitées',
            'Réponses plus poussées',
            "L'œil de Tyto : analyse de photos",
          ];
    final occupe = _enCours == p.identifier;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: TytoColors.papier,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: estPro ? TytoColors.fauve : TytoColors.encre.withOpacity(0.15), width: estPro ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(estPro ? 'Tyto Pro' : 'Tyto Premium', style: TytoText.display(size: 20, color: TytoColors.encre)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: TytoText.ui(size: 15, color: TytoColors.encre),
              children: [
                TextSpan(text: produit.priceString, style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: _periode(p)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final a in avantages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(Icons.check_rounded, size: 15, color: TytoColors.fauve),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(a, style: TytoText.body(size: 14, color: TytoColors.encre).copyWith(height: 1.4)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_enCours != null || _restauration) ? null : () => _acheter(p),
              style: ElevatedButton.styleFrom(
                backgroundColor: TytoColors.fauve,
                disabledBackgroundColor: TytoColors.fauve.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: occupe
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.nuit))
                  : Text("S'abonner", style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.nuit)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: TytoColors.lune),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text('Nos offres', style: TytoText.display(size: 20, color: TytoColors.lune)),
      ),
      body: _offres == null
          ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in _offres!) _carte(p),
                  if (_erreur != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_erreur!,
                          textAlign: TextAlign.center,
                          style: TytoText.ui(size: 13, color: TytoColors.urgence).copyWith(height: 1.45)),
                    ),
                  Center(
                    child: TextButton(
                      onPressed: (_enCours != null || _restauration) ? null : _restaurer,
                      child: _restauration
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.fauve))
                          : Text('Restaurer mes achats',
                              style: TytoText.ui(size: 14, weight: FontWeight.w600, color: TytoColors.fauve)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Le paiement est débité sur ton compte Apple à la confirmation de l'achat. "
                    "L'abonnement se renouvelle automatiquement au même prix, sauf si tu l'annules "
                    "au moins 24 heures avant la fin de la période en cours. Tu peux le gérer ou "
                    "l'annuler à tout moment dans les réglages de ton compte Apple "
                    "(Réglages > ton nom > Abonnements).",
                    textAlign: TextAlign.center,
                    style: TytoText.ui(size: 11.5, color: TytoColors.brume).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: LegalService.conditions,
                        child: Text("Conditions d'utilisation",
                            style: TytoText.ui(size: 12, color: TytoColors.lune)
                                .copyWith(decoration: TextDecoration.underline)),
                      ),
                      TextButton(
                        onPressed: LegalService.confidentialite,
                        child: Text('Confidentialité',
                            style: TytoText.ui(size: 12, color: TytoColors.lune)
                                .copyWith(decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
