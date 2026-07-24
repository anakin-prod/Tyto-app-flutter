import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../screens/login_screen.dart';
import 'dotted_line_painter.dart';
import 'tyto_icons.dart';

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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TytoColors.nuit2, TytoColors.nuit],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _StarsPainter())),
            // le liseré doré du bord droit, comme sur le site
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      TytoColors.fauve.withOpacity(0),
                      TytoColors.fauve.withOpacity(0.67),
                      TytoColors.fauve.withOpacity(0.67),
                      TytoColors.fauve.withOpacity(0),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildRubriques(),
                          const Divider(height: 24, color: Color(0x14EDE7D6)),
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
                          // Un visiteur anonyme n'a rien à "déconnecter" :
                          // on lui propose plutôt de créer son compte.
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              },
                            ),
                          if (subscribed) _buildBadge(),
                          const SizedBox(height: 12),
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

  Widget _buildBadge() {
    final color = isPro ? TytoColors.vert : TytoColors.fauve;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isPro ? 'COMPTE PRO' : 'COMPTE PREMIUM',
            style: TytoText.ui(size: 11, weight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
      child: Row(
        children: [
          // La chouette dessinée au trait, fond transparent : plus de carré.
          TytoIcon.owl(size: 34, color: TytoColors.lune),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tyto', style: TytoText.display(size: 20)),
              Text("L'IA du monde animal", style: TytoText.ui(size: 10.5, color: TytoColors.brume)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: TytoColors.brume),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRubriques() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
      child: Stack(
        children: [
          Positioned(
            left: 15,
            top: 8,
            bottom: 8,
            child: SizedBox(
              width: 2,
              child: CustomPaint(
                painter: DottedLinePainter(color: TytoColors.fauve.withOpacity(0.45)),
                child: Container(),
              ),
            ),
          ),
          Column(
            children: tytoDrawerItems.map((item) {
              final lit = item.id == activeId;
              return InkWell(
                onTap: () => onSelect(item.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: lit ? TytoColors.fauve.withOpacity(0.17) : TytoColors.nuit2,
                          border: Border.all(
                            color: lit ? TytoColors.fauve : TytoColors.lune.withOpacity(0.13),
                            width: 1.5,
                          ),
                          boxShadow: lit
                              ? [BoxShadow(color: TytoColors.fauve.withOpacity(0.35), blurRadius: 14, spreadRadius: 2)]
                              : null,
                        ),
                        child: _iconFor(item.id, size: 16, color: lit ? TytoColors.fauve : TytoColors.brume),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TytoText.ui(
                              size: 15,
                              weight: lit ? FontWeight.w700 : FontWeight.w600,
                              color: lit ? TytoColors.lune : TytoColors.lune.withOpacity(0.7),
                            ),
                          ),
                          Text(item.sub, style: TytoText.ui(size: 11, color: TytoColors.brume)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: TytoColors.lune.withOpacity(0.09)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TytoColors.lune.withOpacity(0.05),
                  border: Border.all(color: TytoColors.lune.withOpacity(0.09)),
                ),
                child: Icon(icon, size: 16, color: TytoColors.brume),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TytoText.ui(size: 14, weight: FontWeight.w600, color: TytoColors.lune.withOpacity(0.8))),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TytoText.ui(size: 11, color: TytoColors.brume),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = TytoColors.lune.withOpacity(0.35);
    final positions = const [
      [0.08, 0.06], [0.22, 0.14], [0.15, 0.27], [0.04, 0.38], [0.27, 0.47],
      [0.11, 0.58], [0.24, 0.68], [0.07, 0.77], [0.19, 0.85], [0.30, 0.92],
      [0.88, 0.09], [0.93, 0.22], [0.85, 0.35], [0.95, 0.51], [0.89, 0.63],
      [0.92, 0.74], [0.86, 0.84], [0.94, 0.94],
    ];
    for (final p in positions) {
      canvas.drawCircle(Offset(p[0] * size.width, p[1] * size.height), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
