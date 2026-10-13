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
// Sans une clé « appl_… », `disponible` reste faux et l'app se comporte
// comme avant (aucun bouton d'achat).
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
import '../services/user_service.dart';
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

  /// Seule une vraie clé iOS (« appl_… ») active les achats. Une clé du Test
  /// Store (« test_… ») ferait planter exprès une version publiée, et le texte
  /// d'attente « A_REMPLIR » ne doit rien activer du tout.
  static bool get disponible => defaultTargetPlatform == TargetPlatform.iOS && _cle.startsWith('appl_');

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
  String? _actif; // 'pro', 'premium' ou null (gratuit)
  // Vrai si l'abonnement actuel a été pris via l'App Store (donc modifiable ici).
  // Faux s'il vient du site ou a été donné à la main : on ne le double pas.
  bool _viaApple = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final offerings = await Purchases.getOfferings();
      String? actif;
      try {
        final info = await Purchases.getCustomerInfo();
        if (info.entitlements.all['pro']?.isActive ?? false) {
          actif = 'pro';
          _viaApple = true;
        } else if (info.entitlements.all['premium']?.isActive ?? false) {
          actif = 'premium';
          _viaApple = true;
        }
      } catch (_) {}
      // Le serveur connaît aussi les abonnements pris sur le site et ceux
      // donnés à la main : sans lui, un compte Pro verrait « Gratuit » comme
      // offre actuelle et pourrait racheter un abonnement.
      try {
        final jeton = AuthService.currentSession?.accessToken;
        if (jeton != null) {
          final profil = await UserService.fetchMe(jeton);
          final serveur = profil.pro ? 'pro' : (profil.premium ? 'premium' : null);
          if (serveur == 'pro' || (serveur == 'premium' && actif == null)) actif = serveur;
        }
      } catch (_) {}
      _actif = actif;
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

  /// Peut-on acheter ce plan depuis cet écran ? Oui si la personne est
  /// gratuite, ou si elle passe de Premium (pris sur l'App Store) à Pro.
  /// Jamais le plan qu'elle a déjà, ni un plan inférieur, ni un deuxième
  /// abonnement quand le sien vient d'ailleurs.
  bool _achetable(Package p) {
    final estPro = p.storeProduct.identifier.toLowerCase().contains('pro');
    if (_actif == null) return true;
    return _viaApple && _actif == 'premium' && estPro;
  }

  Future<void> _acheter(Package paquet) async {
    if (_enCours != null || _restauration || !_achetable(paquet)) return;
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
    if (p.packageType == PackageType.monthly || id.contains('month')) return '/mois';
    if (p.packageType == PackageType.annual || id.contains('year') || id.contains('annual')) return '/an';
    if (p.packageType == PackageType.weekly || id.contains('week')) return '/semaine';
    return '';
  }

  /// La carte du plan gratuit : l'offre actuelle tant que la personne
  /// n'est pas abonnée.
  Widget _carteGratuit() {
    const avantages = [
      '15 questions par jour',
      'Profils de vos compagnons',
      'Carnet de santé et rappels',
      'Tableau de bord des échéances',
      'Courbe de poids',
    ];
    final courant = _actif == null;
    final accent = TytoColors.fauve;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              color: TytoColors.papier,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TytoColors.encre.withOpacity(0.18), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 34, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text('Gratuit', style: TytoText.display(size: 23, color: TytoColors.encre)),
                const SizedBox(height: 8),
                Text('0 €', style: TytoText.display(size: 34, color: TytoColors.encre)),
                const SizedBox(height: 6),
                Text(
                  'Pour découvrir Tyto et poser vos premières questions.',
                  style: TytoText.body(size: 14.5, color: TytoColors.encre.withOpacity(0.8)).copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                for (final a in avantages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('✓', style: TextStyle(color: accent, fontWeight: FontWeight.w700, height: 1.5, fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(a, style: TytoText.body(size: 14, color: TytoColors.encre).copyWith(height: 1.5)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (courant)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    'VOTRE OFFRE ACTUELLE',
                    style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.nuit).copyWith(letterSpacing: 0.88),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// La carte d'un plan : le même contenu et la même mise en page que la page
  /// « Tarifs » du site (app/tarifs/page.js) — badge, nom, prix, accroche,
  /// liste détaillée des avantages et bouton. Seul le prix vient d'Apple.
  Widget _carte(Package p) {
    final produit = p.storeProduct;
    final estPro = produit.identifier.toLowerCase().contains('pro');
    // Le Pro a sa propre teinte, comme sur le site.
    final accent = estPro ? const Color(0xFF7FB2A6) : TytoColors.fauve;
    final texteBouton = estPro ? const Color(0xFF0F2A24) : TytoColors.nuit;
    final courant = _actif == (estPro ? 'pro' : 'premium');
    final peutAcheter = _achetable(p);
    final etiquetteBouton = courant
        ? 'Offre en cours'
        : peutAcheter
            ? (estPro ? 'Passer Pro' : 'Passer Premium')
            : (_actif == 'pro' ? 'Inclus dans votre offre' : 'Non modifiable ici');
    final badge = courant ? 'Votre offre actuelle' : (estPro ? 'Professionnels' : 'Le plus choisi');
    final accroche = estPro
        ? 'Pour les refuges, éleveurs, pensions et pet-sitters qui gèrent plusieurs animaux au quotidien.'
        : 'Pour les propriétaires qui veulent le meilleur pour leur animal.';
    final avantages = estPro
        ? const [
            'Tout le plan Premium, et en plus :',
            'Animaux illimités',
            "Veille sanitaire quotidienne — l'IA relit le journal de tous vos animaux et détecte ce que l'œil humain ne croise pas : tendances de poids, baisse d'appétit répétée, symptômes communs à plusieurs animaux (risque de contagion), échéances oubliées",
            'Saisie vocale — notez une observation en parlant, même les mains prises',
            "Ordonnance photographiée — Tyto lit l'ordonnance et prépare le protocole de traitement, que vous validez ligne par ligne",
            'Synthèse vétérinaire — un compte-rendu structuré et complet généré en un clic avant la consultation',
            "Journal d'équipe — invitez vos soigneurs, tout le monde voit et note sur les mêmes animaux, avec traçabilité de qui a fait quoi",
            'Support prioritaire',
          ]
        : const [
            'Tout le plan Gratuit, et en plus :',
            'Questions illimitées',
            "Réponses par un modèle d'IA plus avancé",
            "L'œil de Tyto — analyse de photos (plante toxique, aliment, insecte, lésion suspecte)",
            "Journal d'observations",
            'Export PDF du carnet',
          ];
    final occupe = _enCours == p.identifier;

    return Padding(
      // Le badge dépasse de 12 px au-dessus de la carte.
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              color: TytoColors.papier,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 34, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(estPro ? 'Pro' : 'Premium', style: TytoText.display(size: 23, color: TytoColors.encre)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(produit.priceString, style: TytoText.display(size: 34, color: TytoColors.encre)),
                    const SizedBox(width: 4),
                    Text(_periode(p), style: TytoText.ui(size: 14, color: TytoColors.encre.withOpacity(0.6))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  accroche,
                  style: TytoText.body(size: 14.5, color: TytoColors.encre.withOpacity(0.8)).copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                for (final a in avantages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: a.endsWith(':')
                        ? Text(
                            a,
                            style: TytoText.ui(size: 12.5, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6))
                                .copyWith(height: 1.5),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('✓', style: TextStyle(color: accent, fontWeight: FontWeight.w700, height: 1.5, fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(a, style: TytoText.body(size: 14, color: TytoColors.encre).copyWith(height: 1.5)),
                              ),
                            ],
                          ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_enCours != null || _restauration || !peutAcheter) ? null : () => _acheter(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor: accent.withOpacity(0.4),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: occupe
                        ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: texteBouton))
                        : Text(etiquetteBouton,
                            style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: texteBouton)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  badge.toUpperCase(),
                  style: TytoText.ui(size: 11, weight: FontWeight.w700, color: texteBouton).copyWith(letterSpacing: 0.88),
                ),
              ),
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
          icon: Icon(Icons.close_rounded, color: TytoColors.lune),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Choisissez votre formule',
                      textAlign: TextAlign.center,
                      style: TytoText.display(size: 26, color: TytoColors.lune),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Du simple curieux au refuge qui suit trente animaux — sans engagement, résiliable en deux clics.',
                      textAlign: TextAlign.center,
                      style: TytoText.body(size: 14.5, color: TytoColors.brume).copyWith(height: 1.5),
                    ),
                  ),
                  _carteGratuit(),
                  for (final p in _offres!) _carte(p),
                  if (_actif != null && !_viaApple)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        "Ton abonnement a été souscrit en dehors de l'App Store : il ne peut pas être modifié depuis cet écran.",
                        textAlign: TextAlign.center,
                        style: TytoText.ui(size: 12.5, color: TytoColors.brume).copyWith(height: 1.45),
                      ),
                    ),
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
