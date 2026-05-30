import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';
import '../../theme/app_theme.dart';

class _Country {
  final String name;
  final String flag;
  final String dialCode;
  final String code;

  const _Country(this.name, this.flag, this.dialCode, this.code);
}

const _countries = [
  _Country('India', '🇮🇳', '+91', 'IN'),
  _Country('United Arab Emirates', '🇦🇪', '+971', 'AE'),
  _Country('United Kingdom', '🇬🇧', '+44', 'GB'),
  _Country('United States', '🇺🇸', '+1', 'US'),
  _Country('Afghanistan', '🇦🇫', '+93', 'AF'),
  _Country('Albania', '🇦🇱', '+355', 'AL'),
  _Country('Algeria', '🇩🇿', '+213', 'DZ'),
  _Country('Angola', '🇦🇴', '+244', 'AO'),
  _Country('Argentina', '🇦🇷', '+54', 'AR'),
  _Country('Armenia', '🇦🇲', '+374', 'AM'),
  _Country('Australia', '🇦🇺', '+61', 'AU'),
  _Country('Austria', '🇦🇹', '+43', 'AT'),
  _Country('Azerbaijan', '🇦🇿', '+994', 'AZ'),
  _Country('Bahrain', '🇧🇭', '+973', 'BH'),
  _Country('Bangladesh', '🇧🇩', '+880', 'BD'),
  _Country('Belarus', '🇧🇾', '+375', 'BY'),
  _Country('Belgium', '🇧🇪', '+32', 'BE'),
  _Country('Brazil', '🇧🇷', '+55', 'BR'),
  _Country('Bulgaria', '🇧🇬', '+359', 'BG'),
  _Country('Cambodia', '🇰🇭', '+855', 'KH'),
  _Country('Canada', '🇨🇦', '+1', 'CA'),
  _Country('Chile', '🇨🇱', '+56', 'CL'),
  _Country('China', '🇨🇳', '+86', 'CN'),
  _Country('Colombia', '🇨🇴', '+57', 'CO'),
  _Country('Croatia', '🇭🇷', '+385', 'HR'),
  _Country('Czech Republic', '🇨🇿', '+420', 'CZ'),
  _Country('Denmark', '🇩🇰', '+45', 'DK'),
  _Country('Egypt', '🇪🇬', '+20', 'EG'),
  _Country('Estonia', '🇪🇪', '+372', 'EE'),
  _Country('Ethiopia', '🇪🇹', '+251', 'ET'),
  _Country('Finland', '🇫🇮', '+358', 'FI'),
  _Country('France', '🇫🇷', '+33', 'FR'),
  _Country('Georgia', '🇬🇪', '+995', 'GE'),
  _Country('Germany', '🇩🇪', '+49', 'DE'),
  _Country('Ghana', '🇬🇭', '+233', 'GH'),
  _Country('Greece', '🇬🇷', '+30', 'GR'),
  _Country('Hong Kong', '🇭🇰', '+852', 'HK'),
  _Country('Hungary', '🇭🇺', '+36', 'HU'),
  _Country('Iceland', '🇮🇸', '+354', 'IS'),
  _Country('Indonesia', '🇮🇩', '+62', 'ID'),
  _Country('Iran', '🇮🇷', '+98', 'IR'),
  _Country('Iraq', '🇮🇶', '+964', 'IQ'),
  _Country('Ireland', '🇮🇪', '+353', 'IE'),
  _Country('Israel', '🇮🇱', '+972', 'IL'),
  _Country('Italy', '🇮🇹', '+39', 'IT'),
  _Country('Japan', '🇯🇵', '+81', 'JP'),
  _Country('Jordan', '🇯🇴', '+962', 'JO'),
  _Country('Kazakhstan', '🇰🇿', '+7', 'KZ'),
  _Country('Kenya', '🇰🇪', '+254', 'KE'),
  _Country('Kuwait', '🇰🇼', '+965', 'KW'),
  _Country('Kyrgyzstan', '🇰🇬', '+996', 'KG'),
  _Country('Laos', '🇱🇦', '+856', 'LA'),
  _Country('Latvia', '🇱🇻', '+371', 'LV'),
  _Country('Lebanon', '🇱🇧', '+961', 'LB'),
  _Country('Libya', '🇱🇾', '+218', 'LY'),
  _Country('Lithuania', '🇱🇹', '+370', 'LT'),
  _Country('Luxembourg', '🇱🇺', '+352', 'LU'),
  _Country('Malaysia', '🇲🇾', '+60', 'MY'),
  _Country('Maldives', '🇲🇻', '+960', 'MV'),
  _Country('Mexico', '🇲🇽', '+52', 'MX'),
  _Country('Moldova', '🇲🇩', '+373', 'MD'),
  _Country('Mongolia', '🇲🇳', '+976', 'MN'),
  _Country('Morocco', '🇲🇦', '+212', 'MA'),
  _Country('Myanmar', '🇲🇲', '+95', 'MM'),
  _Country('Nepal', '🇳🇵', '+977', 'NP'),
  _Country('Netherlands', '🇳🇱', '+31', 'NL'),
  _Country('New Zealand', '🇳🇿', '+64', 'NZ'),
  _Country('Nigeria', '🇳🇬', '+234', 'NG'),
  _Country('Norway', '🇳🇴', '+47', 'NO'),
  _Country('Oman', '🇴🇲', '+968', 'OM'),
  _Country('Pakistan', '🇵🇰', '+92', 'PK'),
  _Country('Palestine', '🇵🇸', '+970', 'PS'),
  _Country('Peru', '🇵🇪', '+51', 'PE'),
  _Country('Philippines', '🇵🇭', '+63', 'PH'),
  _Country('Poland', '🇵🇱', '+48', 'PL'),
  _Country('Portugal', '🇵🇹', '+351', 'PT'),
  _Country('Qatar', '🇶🇦', '+974', 'QA'),
  _Country('Romania', '🇷🇴', '+40', 'RO'),
  _Country('Russia', '🇷🇺', '+7', 'RU'),
  _Country('Saudi Arabia', '🇸🇦', '+966', 'SA'),
  _Country('Serbia', '🇷🇸', '+381', 'RS'),
  _Country('Singapore', '🇸🇬', '+65', 'SG'),
  _Country('Slovakia', '🇸🇰', '+421', 'SK'),
  _Country('Slovenia', '🇸🇮', '+386', 'SI'),
  _Country('South Africa', '🇿🇦', '+27', 'ZA'),
  _Country('South Korea', '🇰🇷', '+82', 'KR'),
  _Country('Spain', '🇪🇸', '+34', 'ES'),
  _Country('Sri Lanka', '🇱🇰', '+94', 'LK'),
  _Country('Sudan', '🇸🇩', '+249', 'SD'),
  _Country('Sweden', '🇸🇪', '+46', 'SE'),
  _Country('Switzerland', '🇨🇭', '+41', 'CH'),
  _Country('Syria', '🇸🇾', '+963', 'SY'),
  _Country('Taiwan', '🇹🇼', '+886', 'TW'),
  _Country('Tajikistan', '🇹🇯', '+992', 'TJ'),
  _Country('Tanzania', '🇹🇿', '+255', 'TZ'),
  _Country('Thailand', '🇹🇭', '+66', 'TH'),
  _Country('Tunisia', '🇹🇳', '+216', 'TN'),
  _Country('Turkey', '🇹🇷', '+90', 'TR'),
  _Country('Turkmenistan', '🇹🇲', '+993', 'TM'),
  _Country('Uganda', '🇺🇬', '+256', 'UG'),
  _Country('Ukraine', '🇺🇦', '+380', 'UA'),
  _Country('Uruguay', '🇺🇾', '+598', 'UY'),
  _Country('Uzbekistan', '🇺🇿', '+998', 'UZ'),
  _Country('Venezuela', '🇻🇪', '+58', 'VE'),
  _Country('Vietnam', '🇻🇳', '+84', 'VN'),
  _Country('Yemen', '🇾🇪', '+967', 'YE'),
  _Country('Zambia', '🇿🇲', '+260', 'ZM'),
  _Country('Zimbabwe', '🇿🇼', '+263', 'ZW'),
];

class PhonePage extends StatefulWidget {
  const PhonePage({super.key});

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  _Country _selectedCountry = _countries[0];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CountryPickerSheet(
        selected: _selectedCountry,
        onSelected: (c) {
          setState(() => _selectedCountry = c);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _submit(TelegramService telegram) {
    final number = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (number.isEmpty) return;
    telegram.setPhoneNumber('${_selectedCountry.dialCode}$number');
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final hasNumber = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android, size: 36, color: AppColors.primary),
                ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0.8, end: 1, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                Text('Enter your phone number',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white))
                  .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text("You'll receive a verification code in Telegram",
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                  .animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const SizedBox(height: 32),

                if (telegram.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(telegram.error!,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -10, end: 0, curve: Curves.easeOutCubic),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _CountryCodeButton(
                        flag: _selectedCountry.flag,
                        dialCode: _selectedCountry.dialCode,
                        onTap: _openCountryPicker,
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            hintStyle: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: hasNumber && !telegram.loading
                          ? [AppColors.gradientStart, AppColors.gradientEnd]
                          : [AppColors.surfaceElevated, AppColors.surfaceElevated],
                    ),
                    boxShadow: hasNumber && !telegram.loading
                        ? [BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 1)]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (hasNumber && !telegram.loading) ? () => _submit(telegram) : null,
                      child: Center(
                        child: telegram.loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Continue', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryCodeButton extends StatelessWidget {
  final String flag;
  final String dialCode;
  final VoidCallback onTap;

  const _CountryCodeButton({
    required this.flag,
    required this.dialCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(dialCode,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final _Country selected;
  final ValueChanged<_Country> onSelected;

  const _CountryPickerSheet({required this.selected, required this.onSelected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final idx = _filtered.indexOf(widget.selected);
    if (idx >= 0 && _scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(idx * 60.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  List<_Country> get _filtered {
    if (_query.isEmpty) return _countries;
    return _countries.where((c) =>
      c.name.toLowerCase().contains(_query) ||
      c.dialCode.contains(_query) ||
      c.code.toLowerCase().contains(_query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Text('Select Country', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search countries...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No countries found',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _filtered.length,
                    itemExtent: 56,
                    itemBuilder: (ctx, i) {
                      final country = _filtered[i];
                      final isSelected = country.code == widget.selected.code && country.dialCode == widget.selected.dialCode;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onSelected(country),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Text(country.flag, style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(country.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
                                          color: isSelected ? AppColors.primary : Colors.white)),
                                ),
                                const SizedBox(width: 8),
                                Text(country.dialCode,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 24, height: 24,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
