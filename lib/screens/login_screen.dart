import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';
import 'tables_screen.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _cafeCtrl  = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool    _loading   = false;
  bool    _obscure   = true;
  String? _error;
  String? _warning;    // Mahalliy tarmoq ogohlantirishi (sariq)
  bool    _offlineMode = false; // Mahalliy tarmoq orqali ishlayapti
  String? _resolvedCafeName; // kafe topilgandan keyin ko'rsatish uchun

  @override
  void initState() {
    super.initState();
    _loadSavedCafe();
  }

  Future<void> _loadSavedCafe() async {
    final code = await AppConfig.getCafeCode();
    final name = await AppConfig.getCafeName();
    if (code != null) {
      _cafeCtrl.text = code;
      setState(() => _resolvedCafeName = name);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _warning = null; _offlineMode = false; });

    try {
      // ── 1. Ulanish holatini tekshirish ─────────────────────────────────
      final cloudOk = await Api.isCloudReachable();

      if (!cloudOk) {
        final localOk = await Api.isLocalReachable();

        if (!localOk) {
          // Ikkalasi ham offline — kirish mumkin emas
          final hasLocalConfigured =
              (await AppConfig.getLocalUrl())?.isNotEmpty == true;
          setState(() => _error = hasLocalConfigured
              ? 'Asosiy monoblok online emas.\n\n'
                'Kompyuter bilan bir xil Wi-Fi tarmoqida bo\'lishingiz kerak.'
              : 'Asosiy monoblok online emas.\n\n'
                '"Mahalliy tarmoqqa ulashish" bo\'limida\n'
                'kompyuterning Wi-Fi IP sini kiriting.');
          return;
        }

        // Local ishlayapti — ogohlantirish bilan davom etamiz
        setState(() {
          _offlineMode = true;
          _warning = 'Asosiy server offline.\nMahalliy tarmoq orqali ulandi.';
        });
      }

      // ── 2. Kafe orqali tenantId topish ─────────────────────────────────
      final cafeRes = await Api.get(
          'auth/cafe?q=${Uri.encodeComponent(_cafeCtrl.text.trim())}');
      final tenantId = cafeRes['tenantId'] as int;
      final cafeName = (cafeRes['cafeName'] ?? '').toString();

      // ── 3. Login ────────────────────────────────────────────────────────
      final loginRes = await Api.post('auth/login', {
        'login':    _loginCtrl.text.trim(),
        'password': _passCtrl.text,
        'tenantId': tenantId,
      });

      await AppConfig.setToken(loginRes['token'] as String);
      await AppConfig.setTenantId(tenantId);
      await AppConfig.saveCafe(_cafeCtrl.text.trim(), cafeName);

      final user = loginRes['user'] as Map<String, dynamic>;
      await AppConfig.saveUser(
          user['id'] as int,
          (user['name'] ?? '').toString(),
          (user['role'] ?? '').toString());

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TablesScreen()),
      );
    } on ApiException catch (e) {
      setState(() {
        if (e.statusCode == 401) {
          _error = 'Login yoki parol noto\'g\'ri';
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),

                  // Logo
                  Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.restaurant_menu,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('FoodX',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  const Text('Ofitsiant ilovasi',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 32),

                  // Login card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kirish',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        const SizedBox(height: 20),

                        // ── Kafe nomi ──────────────────────────────────────
                        _label('Kafe nomi'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _cafeCtrl,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) =>
                              setState(() => _resolvedCafeName = null),
                          decoration: _inputDec(
                            'Kafe nomi yoki kodi',
                            Icons.store_outlined,
                            suffix: _resolvedCafeName != null
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Row(mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: AppColors.success,
                                              size: 16),
                                          const SizedBox(width: 4),
                                          Text(_resolvedCafeName!,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.success,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ]),
                                  )
                                : null,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Kafe nomini kiriting'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Login ──────────────────────────────────────────
                        _label('Login'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _loginCtrl,
                          textInputAction: TextInputAction.next,
                          decoration:
                              _inputDec('login', Icons.person_outline),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Login kiriting'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Parol ──────────────────────────────────────────
                        _label('Parol'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: _inputDec(
                            'parol',
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textMuted,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Parol kiriting'
                                  : null,
                        ),
                        const SizedBox(height: 20),

                        // ── Offline ogohlantirish (sariq) ─────────────────
                        if (_warning != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFFFB300).withAlpha(160)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: Color(0xFFFF8F00), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_warning!,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF7B5800),
                                            fontWeight: FontWeight.w500))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Xatolik (qizil) ────────────────────────────────
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: AppColors.danger.withAlpha(80)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.danger, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.danger))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Kirish tugmasi ─────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withAlpha(120),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                          width: 18, height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2)),
                                      SizedBox(width: 10),
                                      Text('Tekshirilmoqda...',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14)),
                                    ])
                                : const Text('Kirish',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Mahalliy tarmoq / sozlamalar
                  _LocalNetworkTile(),
                  const SizedBox(height: 16),
                ],
              ),
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

  InputDecoration _inputDec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.bg,
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
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5)),
      );
}

// ── Mahalliy tarmoq tugmasi ───────────────────────────────────────────────────

class _LocalNetworkTile extends StatefulWidget {
  @override
  State<_LocalNetworkTile> createState() => _LocalNetworkTileState();
}

class _LocalNetworkTileState extends State<_LocalNetworkTile> {
  bool _custom = false;

  @override
  void initState() {
    super.initState();
    AppConfig.isUsingCustomUrl().then((v) => setState(() => _custom = v));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
        final v = await AppConfig.isUsingCustomUrl();
        setState(() => _custom = v);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _custom ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _custom ? AppColors.primary : AppColors.border),
        ),
        child: Row(children: [
          Icon(
              _custom
                  ? Icons.wifi
                  : Icons.settings_outlined,
              color: _custom ? AppColors.primary : AppColors.textMuted,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _custom
                        ? 'Mahalliy tarmoq rejimi'
                        : 'Mahalliy tarmoqqa ulashish',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _custom
                            ? AppColors.primary
                            : AppColors.textDark)),
                Text(
                    _custom
                        ? 'Sozlash uchun bosing'
                        : 'Internet bo\'lmasa, Wi-Fi orqali ulanish',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}