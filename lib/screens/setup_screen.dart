import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _localCtrl = TextEditingController();

  bool    _loading   = false;
  String? _statusMsg;
  bool    _statusOk  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _localCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final localUrl = await AppConfig.getLocalUrl();
    if (localUrl != null && localUrl.isNotEmpty) {
      final uri = Uri.tryParse(localUrl);
      setState(() => _localCtrl.text = uri?.host ?? localUrl);
    }
  }

  String _normalize(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s:5050';
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _statusMsg = null; });

    final localRaw = _localCtrl.text.trim();
    final local    = localRaw.isNotEmpty ? _normalize(localRaw) : null;

    if (local == null) {
      setState(() {
        _loading   = false;
        _statusOk  = false;
        _statusMsg = 'IP manzil kiriting.';
      });
      return;
    }

    try {
      await Api.getStaffList(local);
      setState(() {
        _loading   = false;
        _statusOk  = true;
        _statusMsg = '✓ Ulandi: $local';
      });
    } catch (_) {
      setState(() {
        _loading   = false;
        _statusOk  = false;
        _statusMsg = 'Ulanib bo\'lmadi. IP va port tekshiring.';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final localRaw = _localCtrl.text.trim();
    if (localRaw.isNotEmpty) {
      await AppConfig.setLocalUrl(_normalize(localRaw));
    } else {
      await AppConfig.clearLocalUrl();
    }
    Api.resetActiveBase();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await AppConfig.clearLocalUrl();
    Api.resetActiveBase();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        title: const Text('Mahalliy tarmoq',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textDark)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withAlpha(60)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kompyuter bilan bir xil Wi-Fi tarmog\'ida bo\'lganingizda '
                          'mahalliy IP kiritib tezroq ishlashingiz mumkin.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Mahalliy IP maydoni
                const Text('Kompyuter IP manzili',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _localCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: '192.168.1.100',
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.computer_outlined,
                        color: AppColors.textMuted, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 8),

                // Tezkor misollar
                Wrap(spacing: 8, children: [
                  for (final ip in ['192.168.35', '192.168.1', '192.168.0'])
                    ActionChip(
                      label: Text('$ip.x',
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.bg,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () =>
                          setState(() => _localCtrl.text = '$ip.'),
                    ),
                ]),
                const SizedBox(height: 20),

                // Status xabari
                if (_statusMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusOk
                          ? AppColors.successLight
                          : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _statusOk
                              ? AppColors.success
                              : AppColors.danger),
                    ),
                    child: Row(children: [
                      Icon(
                          _statusOk
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _statusOk
                              ? AppColors.success
                              : AppColors.danger,
                          size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_statusMsg!,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _statusOk
                                      ? AppColors.success
                                      : AppColors.danger))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tugmalar
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _test,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side:
                            const BorderSide(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary))
                          : const Icon(Icons.network_check, size: 16),
                      label: const Text('Tekshirish',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Saqlash',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                ]),

                // Tozalash
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _clear,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Mahalliy IP ni o\'chirish',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}