import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';
import 'login_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _tenantCtrl = TextEditingController(text: '1');

  bool _loading = false;
  String? _statusMsg;
  bool _statusOk = false;

  // Tezkor sozlama tugmalari
  static const _presets = [
    ('Mahalliy (192.168.1.x)', 'http://192.168.1.'),
    ('Localhost', 'http://localhost:5000'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final url = await AppConfig.getBaseUrl();
    final tid = await AppConfig.getTenantId();
    if (url != null) _urlCtrl.text = url;
    _tenantCtrl.text = tid.toString();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _statusMsg = null; });

    final tid = int.tryParse(_tenantCtrl.text.trim()) ?? 1;
    final ok = await Api.testConnection(_urlCtrl.text.trim(), tid);

    setState(() {
      _loading = false;
      _statusOk = ok;
      _statusMsg = ok ? 'Ulanish muvaffaqiyatli!' : 'Ulanib bo\'lmadi. URL va port tekshiring.';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await AppConfig.setBaseUrl(_urlCtrl.text.trim());
    await AppConfig.setTenantId(int.tryParse(_tenantCtrl.text.trim()) ?? 1);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restaurant_menu,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Text('FoodX',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                ]),
                const SizedBox(height: 32),
                const Text('Server sozlamalari',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),
                const Text(
                    'Markaziy server yoki mahalliy tarmoq manzilini kiriting',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 24),

                // Tezkor presets
                Wrap(
                  spacing: 8,
                  children: _presets.map((p) => ActionChip(
                    label: Text(p.$1,
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.primaryLight,
                    onPressed: () => _urlCtrl.text = p.$2,
                  )).toList(),
                ),
                const SizedBox(height: 16),

                _label('Server manzili (URL)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: _inputDec(
                      'https://server.com yoki http://192.168.1.100:5000'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Majburiy maydon';
                    if (!v.trim().startsWith('http')) {
                      return 'http:// yoki https:// bilan boshlang';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _label('Tenant ID'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tenantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDec('1'),
                  validator: (v) {
                    if (int.tryParse(v ?? '') == null) return 'Raqam kiriting';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                if (_statusMsg != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
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
                          _statusOk ? Icons.check_circle : Icons.error_outline,
                          color: _statusOk ? AppColors.success : AppColors.danger,
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

                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary))
                          : const Text('Ulanishni tekshirish'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Saqlash',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted));

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
      );
}