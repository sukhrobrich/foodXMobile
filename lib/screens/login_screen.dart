import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/api.dart';
import '../core/config.dart';
import 'tables_screen.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cafeCtrl  = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  // Kafe tekshiruv natijasi
  bool    _cafeLoading  = false;
  int?    _tenantId;
  String? _cafeName;
  String? _cafeError;

  // Login
  bool    _loginLoading = false;
  bool    _obscure      = true;
  String? _loginError;
  String? _warning;

  bool get _cafeFound => _tenantId != null;

  @override
  void initState() {
    super.initState();
    _loadSavedCafe();
  }

  Future<void> _loadSavedCafe() async {
    final code = await AppConfig.getCafeCode();
    final name = await AppConfig.getCafeName();
    if (code != null && code.isNotEmpty) {
      _cafeCtrl.text = code;
      // Agar saqlangan bo'lsa — avtomatik tekshiramiz
      if (name != null && name.isNotEmpty) {
        // Faqat UI ni ko'rsatamiz, so'rov yubormaymiz (offline bo'lishi mumkin)
        setState(() => _cafeName = name);
      }
    }
  }

  // ── 1-qadam: Kafeni tekshirish ─────────────────────────────────────────────
  Future<void> _checkCafe() async {
    final q = _cafeCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _cafeLoading = true;
      _cafeError   = null;
      _tenantId    = null;
      _cafeName    = null;
      _loginError  = null;
      _warning     = null;
      _loginCtrl.clear();
      _passCtrl.clear();
    });

    try {
      final primaryUrl = await AppConfig.getBaseUrl();
      Api.resetActiveBase();

      final res      = await Api.get('auth/cafe?q=${Uri.encodeComponent(q)}');
      final tenantId = res['tenantId'] as int;
      final cafeName = (res['cafeName'] ?? '').toString();

      // Qaysi URL ishlatilgani
      final activeUrl      = Api.activeBaseUrl;
      final usedFallback   = activeUrl != null && activeUrl != primaryUrl;

      await AppConfig.saveCafe(q, cafeName);

      setState(() {
        _tenantId  = tenantId;
        _cafeName  = cafeName;
        if (usedFallback)
          _warning = 'Asosiy server offline. Mahalliy tarmoq orqali ulandi.';
      });

      // Login maydoniga fokus
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) FocusScope.of(context).nextFocus();
      });

    } on ApiException catch (e) {
      final hasLocal = (await AppConfig.getLocalUrl())?.isNotEmpty == true;
      setState(() {
        _cafeError = (e.statusCode == 404)
            ? 'Kafe topilmadi. Nomni to\'g\'ri kiriting.'
            : (e.statusCode != null)
                ? e.message
                : hasLocal
                    ? 'Serverga ulanib bo\'lmadi.\nKompyuter bilan bir xil Wi-Fi da bo\'ling.'
                    : 'Serverga ulanib bo\'lmadi.\n"Mahalliy tarmoqqa ulashish" da IP kiriting.';
      });
    } finally {
      if (mounted) setState(() => _cafeLoading = false);
    }
  }

  // ── 2-qadam: Login ─────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_cafeFound) return;
    if (_loginCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;

    setState(() { _loginLoading = true; _loginError = null; });

    try {
      final loginRes = await Api.post('auth/login', {
        'login':    _loginCtrl.text.trim(),
        'password': _passCtrl.text,
        'tenantId': _tenantId!,
      });

      await AppConfig.setToken(loginRes['token'] as String);
      await AppConfig.setTenantId(_tenantId!);

      final user = loginRes['user'] as Map<String, dynamic>;
      await AppConfig.saveUser(
          user['id']   as int,
          (user['name'] ?? '').toString(),
          (user['role'] ?? '').toString());

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TablesScreen()),
      );

    } on ApiException catch (e) {
      setState(() {
        _loginError = e.statusCode == 401
            ? 'Login yoki parol noto\'g\'ri'
            : e.message;
      });
    } finally {
      if (mounted) setState(() => _loginLoading = false);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),

                // ── Logo ───────────────────────────────────────────────────
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Icon(Icons.restaurant_menu,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('FoodX',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold,
                        color: AppColors.textDark, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                const Text('Ofitsiant ilovasi',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 32),

                // ── Karta ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kirish',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                      const SizedBox(height: 20),

                      // ── Kafe nomi ─────────────────────────────────────
                      _label('Kafe nomi'),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cafeCtrl,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _checkCafe(),
                            onChanged: (_) => setState(() {
                              _tenantId   = null;
                              _cafeName   = null;
                              _cafeError  = null;
                              _loginError = null;
                              _warning    = null;
                            }),
                            decoration: _inputDec(
                              'Kafe nomi yoki kodi',
                              Icons.store_outlined,
                              suffix: _cafeFound
                                  ? const Padding(
                                      padding: EdgeInsets.only(right: 10),
                                      child: Icon(Icons.check_circle,
                                          color: AppColors.success, size: 20))
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _cafeLoading ? null : _checkCafe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withAlpha(100),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                            ),
                            child: _cafeLoading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Tekshir',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                          ),
                        ),
                      ]),

                      // Kafe topildi banner
                      if (_cafeFound) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.success.withAlpha(80)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.success, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Topildi: $_cafeName',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                      ],

                      // Kafe xatolik
                      if (_cafeError != null) ...[
                        const SizedBox(height: 10),
                        _errorBox(_cafeError!),
                      ],

                      // Offline ogohlantirish
                      if (_warning != null) ...[
                        const SizedBox(height: 10),
                        _warningBox(_warning!),
                      ],

                      const SizedBox(height: 20),

                      // ── Login ─────────────────────────────────────────
                      _label('Login'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _loginCtrl,
                        enabled: _cafeFound,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDec('login', Icons.person_outline),
                      ),
                      const SizedBox(height: 16),

                      // ── Parol ─────────────────────────────────────────
                      _label('Parol'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passCtrl,
                        enabled: _cafeFound,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: _inputDec(
                          'parol',
                          Icons.lock_outline,
                          suffix: _cafeFound
                              ? IconButton(
                                  icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textMuted, size: 20),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login xatolik
                      if (_loginError != null) ...[
                        _errorBox(_loginError!),
                        const SizedBox(height: 16),
                      ],

                      // ── Kirish tugmasi ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_cafeFound && !_loginLoading)
                              ? _login
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withAlpha(60),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _loginLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
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
                _LocalNetworkTile(),
                const SizedBox(height: 16),
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

  Widget _errorBox(String msg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.danger.withAlpha(80)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.danger))),
          ],
        ),
      );

  Widget _warningBox(String msg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                child: Text(msg,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7B5800),
                        fontWeight: FontWeight.w500))),
          ],
        ),
      );

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
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: AppColors.border.withAlpha(100))),
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
              color:
                  _custom ? AppColors.primary : AppColors.border),
        ),
        child: Row(children: [
          Icon(
              _custom ? Icons.wifi : Icons.settings_outlined,
              color:
                  _custom ? AppColors.primary : AppColors.textMuted,
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