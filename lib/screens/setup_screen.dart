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
  bool    _isCustom  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final localUrl = await AppConfig.getLocalUrl();
    setState(() {
      if (localUrl != null && localUrl.isNotEmpty) {
        _localCtrl.text = localUrl;
        _isCustom = true;
      }
    });
  }

  String _normalize(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s';
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _statusMsg = null; });

    final localRaw = _localCtrl.text.trim();
    final localUrl = localRaw.isNotEmpty ? _normalize(localRaw) : null;
    final tid      = await AppConfig.getTenantId();

    if (localUrl != null) {
      final ok = await Api.testConnection(localUrl, tid);
      setState(() {
        _loading = false;
        _statusOk  = ok;
        _statusMsg = ok
            ? '✓ Wi-Fi server ulandi: $localUrl'
            : 'Ulanib bo\'lmadi. IP va port to\'g\'riligini tekshiring.';
      });
    } else {
      setState(() {
        _loading = false;
        _statusOk  = false;
        _statusMsg = 'IP manzil kiriting.';
      });
    }
  }

  Future<void> _save() async {
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

  Future<void> _resetToDefault() async {
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
                // Markaziy server info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withAlpha(80)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cloud_done_outlined,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Markaziy server (internet)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success)),
                            const SizedBox(height: 2),
                            Text(AppConfig.centralUrl,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.success)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Wi-Fi divider
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Yoki — bir xil Wi-Fi tarmoqida bo\'lsangiz',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),

                const Text('Kompyuter Wi-Fi IP manzili',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 4),
                const Text(
                    'Markaziy server ishlamasa, kompyuter bilan bir xil Wi-Fi da bo\'lib ulanish uchun.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _localCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: '192.168.35.100:5050',
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
                      label: Text('$ip.x:5050',
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.bg,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () =>
                          setState(() => _localCtrl.text = '$ip.'),
                    ),
                ]),
                const SizedBox(height: 20),

                // Status xabar
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
                        side: const BorderSide(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
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
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                ]),

                // Wi-Fi manzilini o'chirish (agar sozlangan bo'lsa)
                if (_isCustom) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _localCtrl.clear();
                          _isCustom = false;
                        });
                        _resetToDefault();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.wifi_off_outlined, size: 16),
                      label: const Text(
                          'Wi-Fi sozlamasini o\'chirish',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}