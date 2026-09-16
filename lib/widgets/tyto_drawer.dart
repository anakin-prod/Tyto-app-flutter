import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../screens/login_screen.dart';
import '../screens/team_screen.dart';
import 'tyto_icons.dart';
import 'owl_sketch.dart';

class DrawerItem {
  final String id;
  final String label;
  final String sub;
  const DrawerItem({required this.id, required this.label, required this.sub});
}

const tytoDrawerItems = [
  DrawerItem(id: 'chat', label: 'Chat', sub: 'Poser une question'),
  DrawerItem(id: 'pets', label: 'Mes animaux', sub: 'Profils & compagnons'),
  DrawerItem(id: 'carnet', label: 'Carnet de santé', sub: 'Vaccins, poids, soins'),
  DrawerItem(id: 'tableau', label: 'Tableau des rappels', sub: 'Ce qui arrive bientôt'),
  DrawerItem(id: 'veille', label: 'Veille sanitaire', sub: "L'analyse quotidienne"),
];

/// La teinte dorée de la chouette et des traits du tiroir — un peu plus
/// pâle que le fauve pur, pour rester lisible sur le fond sombre.
const _dore = Color(0xFFD9BE8C);

/// L'icône de chaque rubrique — les mêmes que sur le site.
Widget _iconFor(String id, {required double size, required Color color}) {
  switch (id) {
    case 'chat':
      return TytoIcon.chat(size: size, color: color);
    case 'pets':
      return TytoIcon.owl(size: size, color: color);
    case 'carnet':
      return TytoIcon.notebook(size: size, color: color);
    case 'tableau':
      return TytoIcon.chart(size: size, color: color);
    case 'veille':
      return TytoIcon.monitor(size: size, color: color);
    default:
      return TytoIcon.chat(size: size, color: color);
  }
}

/// Le tiroir de navigation — nouveau design validé : fond nuit avec un
/// cadre doré double, des coins ornementés façon carton d'invitation,
/// des médaillons en anneau pour chaque rubrique, et une chouette
/// teintée de doré. Plus d'étoiles : la sobriété fait l'élégance ici.
class TytoDrawer extends StatelessWidget {
  final String activeId;
  final ValueChanged<String> onSelect;
  final bool isPro;
  final bool isPremium;

  const TytoDrawer({
    super.key,
    required this.activeId,
    required this.onSelect,
    this.isPro = false,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final subscribed = isPro || isPremium;
    final signedIn = AuthService.isSignedIn;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.4, -1.1),
            radius: 1.6,
            colors: [TytoColors.nuit2, TytoColors.nuit, Color(0xFF0A0E18)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Le cadre doré double, à l'intérieur du bord.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: TytoColors.fauve.withOpacity(0.27)),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: TytoColors.fauve.withOpacity(0.145), width: 0.5),
                  ),
                ),
              ),
            ),
            // Les 4 coins ornementés, façon carton d'invitation.
            const Positioned(top: 9, left: 9, child: _CoinOrnement()),
            const Positioned(
              top: 9, right: 9,
              child: RotatedBox(quarterTurns: 1, child: _CoinOrnement()),
            ),
            const Positioned(
              bottom: 9, left: 9,
              child: RotatedBox(quarterTurns: 3, child: _CoinOrnement()),
            ),
            const Positioned(
              bottom: 9, right: 9,
              child: RotatedBox(quarterTurns: 2, child: _CoinOrnement()),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildDividerOrne(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildRubriques(),
                          _buildDividerOrne(),
                          if (subscribed)
                            _buildAction(
                              icon: Icons.group_outlined,
                              label: 'Mon équipe',
                              sub: 'Inviter des soigneurs',
                              visible: isPro,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamScreen()));
                              },
                            ),
                          if (subscribed)
                            _buildAction(
                              icon: Icons.settings_rounded,
                              label: "Gérer l'abonnement",
                              sub: 'Facturation, résiliation',
                              onTap: () async {
                                Navigator.pop(context);
                                final token = AuthService.currentSession?.accessToken;
                                if (token != null) await BillingService.openPortal(token);
                              },
                            )
                          else
                            _buildAction(
                              icon: Icons.star_border_rounded,
                              label: 'Nos offres',
                              sub: 'Découvrir Premium & Pro',
                              onTap: () {
                                Navigator.pop(context);
                                BillingService.openOffers();
                              },
                            ),
                          if (signedIn)
                            _buildAction(
                              icon: Icons.logout_rounded,
                              label: 'Se déconnecter',
                              sub: AuthService.email ?? 'Fermer ma session',
                              onTap: () async {
                                Navigator.pop(context);
                                await AuthService.signOut();
                              },
                            )
                          else
                            _buildAction(
                              icon: Icons.login_rounded,
                              label: 'Se connecter',
                              sub: 'Retrouver mes animaux partout',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                              },
                            ),
                          if (subscribed) _buildBadge(),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(27, 26, 20, 16),
      child: Row(
        children: [
          const OwlSketch(size: 32, ink: _dore),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tyto', style: TytoText.display(size: 22, color: TytoColors.lune)),
              const SizedBox(height: 3),
              Container(width: 26, height: 1.5, color: TytoColors.fauve, margin: const EdgeInsets.only(bottom: 3)),
              Text("L'IA du monde animal",
                  style: TytoText.ui(size: 10.5, color: TytoColors.brume).copyWith(fontStyle: FontStyle.italic)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: TytoColors.brume, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Le trait avec le petit losange doré au centre, comme sur une carte
  /// de membre gravée.
  Widget _buildDividerOrne() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  TytoColors.fauve.withOpacity(0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Text('◆', style: TextStyle(fontSize: 6, color: TytoColors.fauve.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    final color = isPro ? TytoColors.vert : TytoColors.fauve;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            isPro ? 'COMPTE PRO' : 'COMPTE PREMIUM',
            style: TytoText.ui(size: 10.5, weight: FontWeight.w700, color: color).copyWith(letterSpacing: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildRubriques() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: tytoDrawerItems.map((item) {
          final lit = item.id == activeId;
          return InkWell(
            onTap: () => onSelect(item.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 11),
              decoration: lit
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        colors: [TytoColors.fauve.withOpacity(0.07), Colors.transparent],
                        stops: const [0.0, 0.75],
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  _medaillon(
                    icone: _iconFor(item.id, size: 15, color: lit ? TytoColors.fauve : TytoColors.brume),
                    actif: lit,
                    taille: 32,
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TytoText.display(
                          size: 15,
                          weight: lit ? FontWeight.w700 : FontWeight.w600,
                          color: lit ? TytoColors.lune : TytoColors.lune.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(item.sub, style: TytoText.ui(size: 10.5, color: TytoColors.brume)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Le médaillon en anneau : présent sur toutes les rubriques, pas
  /// seulement l'active — comme une collection de badges.
  Widget _medaillon({required Widget icone, required bool actif, required double taille}) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: actif
            ? RadialGradient(colors: [TytoColors.fauve.withOpacity(0.22), TytoColors.fauve.withOpacity(0.04)])
            : null,
        border: Border.all(color: actif ? TytoColors.fauve : TytoColors.lune.withOpacity(0.12)),
        boxShadow: actif
            ? [BoxShadow(color: TytoColors.fauve.withOpacity(0.25), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: icone,
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 9),
        child: Row(
          children: [
            _medaillon(
              icone: Icon(icon, size: 13, color: TytoColors.brume),
              actif: false,
              taille: 28,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TytoText.ui(size: 13, weight: FontWeight.w600, color: TytoColors.lune.withOpacity(0.85))),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TytoText.ui(size: 10, color: TytoColors.brume)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le petit angle doré, dans chaque coin du tiroir.
class _CoinOrnement extends StatelessWidget {
  const _CoinOrnement();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _CoinPainter(),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()
      ..color = TytoColors.fauve
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final chemin = Path()
      ..moveTo(0, 8)
      ..lineTo(0, 0)
      ..lineTo(8, 0);
    canvas.drawPath(chemin, peinture);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
