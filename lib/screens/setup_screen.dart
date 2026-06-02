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
  final _formKey    = GlobalKey<FormState>();
  final _urlCtrl    = TextEditingController();
  final _localCtrl  = TextEditingController();

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
    final custom   = await AppConfig.isUsingCustomUrl();
    final url      = await AppConfig.getBaseUrl();
    final localUrl = await AppConfig.getLocalUrl();
    setState(() {
      _isCustom = custom;
      if (custom) _urlCtrl.text = url;
      if (localUrl != null && localUrl.isNotEmpty) _localCtrl.text = localUrl;
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
    final tid      = await AppConfig.getTenantId();
    final primary  = _normalize(_urlCtrl.text);
    final localRaw = _localCtrl.text.trim();
    final local    = localRaw.isNotEmpty ? _normalize(localRaw) : null;

    final okPrimary = await Api.testConnection(primary, tid);
    final okLocal   = local != null ? await Api.testConnection(local, tid) : null;

    setState(() {
      _loading = false;
      if (okPrimary) {
        _statusOk  = true;
        _statusMsg = '✓ Online server ulandi: $primary';
      } else if (okLocal == true) {
        _statusOk  = true;
        _statusMsg = '✓ Offline server ulandi: $local';
      } else {
        _statusOk  = false;
        _statusMsg = 'Ulanib bo\'lmadi. IP va port tekshiring.';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await AppConfig.setBaseUrl(_normalize(_urlCtrl.text));
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
    await AppConfig.resetToDefault();
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
                // Izoh banner
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
                          'Internet bo\'lmasa, Windows kompyuter bilan bir xil Wi-Fi tarmoqda bo\'lsangiz, '
                          'kompyuterning IP manziliga to\'g\'ridan-to\'g\'ri ulanish mumkin.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Mahalliy server manzili',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: '192.168.1.100:5050',
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.wifi,
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
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'IP manzil kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Tezkor misollar
                Wrap(spacing: 8, children: [
                  for (final ip in ['192.168.1', '192.168.0', '10.0.0'])
                    ActionChip(
                      label: Text('$ip.x:5050',
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.bg,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () => _urlCtrl.text = '$ip.',
                    ),
                ]),
                const SizedBox(height: 20),

                // Offline (Windows PC) URL
                const Text('Offline server manzili (ixtiyoriy)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 4),
                const Text(
                    'Online server javob bermasa avtomatik shu manzilga ulanadi.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _localCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: '192.168.35.252:5050',
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.computer,
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

                // Markaziy serverga qaytish (agar custom URL bo'lsa)
                if (_isCustom) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _resetToDefault,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.cloud_outlined, size: 16),
                      label: const Text(
                          'Markaziy serverga qaytish',
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