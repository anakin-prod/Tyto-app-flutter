import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/pro_service.dart';

/// Fonction Pro : inviter des soigneurs à partager le carnet des animaux.
/// Chaque soigneur au-delà des sièges inclus est facturé en plus — c'est
/// écrit noir sur blanc avant d'inviter, comme sur le site.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _email = TextEditingController();
  TeamData? _team;
  bool _chargement = true;
  bool _envoi = false;
  InviteResult? _message;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      setState(() => _chargement = false);
      return;
    }
    final t = await ProService.loadTeam(token);
    if (!mounted) return;
    setState(() {
      _team = t;
      _chargement = false;
    });
  }

  Future<void> _inviter() async {
    final email = _email.text.trim();
    if (email.isEmpty || _envoi) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() {
      _envoi = true;
      _message = null;
    });
    final r = await ProService.invite(accessToken: token, email: email);
    if (!mounted) return;
    setState(() {
      _envoi = false;
      _message = r;
      if (r.ok) _email.clear();
    });
    if (r.ok) _charger();
  }

  Future<void> _retirer(TeamMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        title: Text('Retirer ce soigneur ?', style: TytoText.display(size: 17)),
        content: Text(
          '${m.email} n\'aura plus accès aux animaux ni à leur carnet.',
          style: TytoText.body(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TytoText.ui(color: TytoColors.brume)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Retirer', style: TytoText.ui(color: TytoColors.urgence, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;
    await ProService.removeMember(accessToken: token, memberId: m.id);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('Mon équipe', style: TytoText.display(size: 19))),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
          : _team == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      "Impossible de charger ton équipe pour l'instant.",
                      textAlign: TextAlign.center,
                      style: TytoText.body(size: 15, color: TytoColors.brume),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: TytoColors.papier,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TytoColors.encre.withOpacity(0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    _resumeSieges(),
                    const SizedBox(height: 18),
                    Text('Inviter un soigneur', style: TytoText.display(size: 17, color: TytoColors.encre)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: TytoText.ui(color: TytoColors.encre),
                      decoration: InputDecoration(
                        hintText: 'son@email.com',
                        hintStyle: TytoText.ui(color: TytoColors.encre.withOpacity(0.4)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: TytoColors.encre.withOpacity(0.2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _envoi ? null : _inviter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TytoColors.fauve,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _envoi ? 'Envoi…' : "Envoyer l'invitation",
                          style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit),
                        ),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_message!.ok ? TytoColors.vert : TytoColors.urgence).withOpacity(0.13),
                          border: Border.all(
                              color: (_message!.ok ? TytoColors.vert : TytoColors.urgence).withOpacity(0.45)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _message!.message,
                          style: TytoText.ui(size: 13, color: TytoColors.encre),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text('Soigneurs', style: TytoText.display(size: 17, color: TytoColors.encre)),
                    const SizedBox(height: 8),
                    if (_team!.members.isEmpty)
                      Text(
                        "Personne pour l'instant. Invite un proche ou un collègue "
                        "pour qu'il puisse suivre les animaux avec toi.",
                        style: TytoText.body(size: 14.5, color: TytoColors.encre.withOpacity(0.7)).copyWith(height: 1.5),
                      )
                    else
                      ..._team!.members.map(_membre),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _resumeSieges() {
    final t = _team!;
    final total = t.members.length;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TytoColors.vert.withOpacity(0.1),
        border: Border.all(color: TytoColors.vert.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total soigneur${total > 1 ? 's' : ''} · ${t.seatsIncluded} inclus dans ton abonnement',
            style: TytoText.ui(size: 14, weight: FontWeight.w700, color: TytoColors.encre),
          ),
          if (t.seatsExtra > 0) ...[
            const SizedBox(height: 5),
            Text(
              '${t.seatsExtra} siège${t.seatsExtra > 1 ? 's' : ''} supplémentaire${t.seatsExtra > 1 ? 's' : ''} '
              '(+${t.seatsExtra * t.extraPriceEur} €/mois, ajusté automatiquement sur ta facture)',
              style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.65)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _membre(TeamMember m) {
    final actif = m.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TytoColors.encre.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(
            actif ? Icons.person_rounded : Icons.mail_outline_rounded,
            size: 18,
            color: actif ? TytoColors.vert : TytoColors.encre.withOpacity(0.5),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TytoText.ui(size: 14, color: TytoColors.encre)),
                Text(actif ? 'Actif' : 'Invitation en attente',
                    style: TytoText.ui(size: 11.5, color: TytoColors.encre.withOpacity(0.55))),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: TytoColors.encre.withOpacity(0.4)),
            tooltip: 'Retirer',
            onPressed: () => _retirer(m),
          ),
        ],
      ),
    );
  }
}
