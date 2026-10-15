/// Peta path ikon Coolicons kurasi + 6 kategori ledger baru.
///
/// Murni konstanta String, tanpa import Flutter, agar nol risiko analyzer.
/// Sumber ikon: Coolicons v4.1 oleh Kryston Schwarze, lisensi CC BY 4.0.
/// Kredit wajib tampil di layar Tentang bila dibundel ke APK.
class CoolSvg {
  CoolSvg._();

  static const String base = 'assets/icons/coolicons';

  // Nav/aksi (14)
  static const String home = '$base/House_01.svg';
  static const String transactions = '$base/Arrow_Left_Right.svg';
  static const String budget = '$base/Chart_Pie.svg';
  static const String reports = '$base/Chart_Bar_Vertical_01.svg';
  static const String add = '$base/Add_Plus_Circle.svg';
  static const String search = '$base/Search_Magnifying_Glass.svg';
  static const String filter = '$base/Filter.svg';
  static const String calendar = '$base/Calendar.svg';
  static const String clock = '$base/Clock.svg';
  static const String bell = '$base/Bell.svg';
  static const String lock = '$base/Lock.svg';
  static const String show = '$base/Show.svg';
  static const String hide = '$base/Hide.svg';
  static const String settings = '$base/Settings.svg';

  // Kategori/util (14)
  static const String coffee = '$base/Coffee.svg';
  static const String car = '$base/Car_Auto.svg';
  static const String bag = '$base/Handbag.svg';
  static const String document = '$base/File_Document.svg';
  static const String heart = '$base/Heart_01.svg';
  static const String book = '$base/Book_Open.svg';
  static const String headphones = '$base/Headphones.svg';
  static const String trendingUp = '$base/Trending_Up.svg';
  static const String card = '$base/Credit_Card_01.svg';
  static const String reload = '$base/Arrows_Reload_01.svg';
  static const String save = '$base/Save.svg';
  static const String wifi = '$base/Wifi_High.svg';
  static const String qr = '$base/Qr_Code.svg';
  static const String gift = '$base/Gift.svg';

  // Tambahan cakupan penuh AppIcons (32)
  static const String menu = '$base/Menu_Duo_MD.svg';
  static const String cart = '$base/Shopping_Cart_01.svg';
  static const String download = '$base/Download.svg';
  static const String downloadPack = '$base/Download_Package.svg';
  static const String card2 = '$base/Credit_Card_02.svg';
  static const String bank = '$base/Building_02.svg';
  static const String users = '$base/Users.svg';
  static const String userAdd = '$base/User_Add.svg';
  static const String shareAndroid = '$base/Share_Android.svg';
  static const String bellRing = '$base/Bell_Notification.svg';
  static const String tag = '$base/Tag.svg';
  static const String logOut = '$base/Log_Out.svg';
  static const String shieldWarn = '$base/Shield_Warning.svg';
  static const String shield = '$base/Shield.svg';
  static const String chevLeft = '$base/Chevron_Left.svg';
  static const String chevRight = '$base/Chevron_Right.svg';
  static const String circleWarn = '$base/Circle_Warning.svg';
  static const String circleCheck = '$base/Circle_Check.svg';
  static const String closeSm = '$base/Close_SM.svg';
  static const String closeSquare = '$base/Close_Square.svg';
  static const String arrowLeft = '$base/Arrow_Left_SM.svg';
  static const String arrowDownMd = '$base/Arrow_Down_MD.svg';
  static const String arrowUpMd = '$base/Arrow_Up_MD.svg';
  static const String arrowDownSm = '$base/Arrow_Down_SM.svg';
  static const String arrowUpSm = '$base/Arrow_Up_SM.svg';
  static const String check = '$base/Check.svg';
  static const String trash = '$base/Trash_Full.svg';
  static const String timer = '$base/Timer.svg';
  static const String warning = '$base/Warning.svg';
  static const String mail = '$base/Mail.svg';
  static const String star = '$base/Star.svg';
  static const String option = '$base/Option.svg';
  static const String voice = '$base/User_Voice.svg';

  // Ledger baru (6, gaya cat_*.svg)
  static const String invest = 'assets/icons/coolicons/Trending_Up.svg';
  static const String donate = 'assets/icons/coolicons/Gift.svg';
  static const String family = 'assets/icons/coolicons/House_01.svg';
  static const String sport = 'assets/illustrations/cat_sport.svg';
  static const String pet = 'assets/illustrations/cat_pet.svg';
  static const String sos = 'assets/illustrations/cat_sos.svg';

  /// Path Coolicons untuk codepoint primer [AppIcons], null bila tak ada.
  ///
  /// Tabrakan codepoint yang diketahui (entri kedua tak pernah dirender
  /// karena pemanggilnya mati): e3f1 = transaksi nav (bills mati),
  /// e0a1 = transfer (workspaceSwitch mati), e13b = chevron kanan,
  /// e1b7 = peringatan.
  static String? pathForCodePoint(int cp) {
    switch (cp) {
      case 0xe2c3:
        return home;
      case 0xe3f1:
        return transactions;
      case 0xea05:
        return budget;
      case 0xe151:
        return reports;
      case 0xe465:
        return menu;
      case 0xe3d5:
        return add;
      case 0xe263:
        return coffee;
      case 0xe113:
        return car;
      case 0xe419:
        return cart;
      case 0xe2a9:
        return heart;
      case 0xe62d:
        return book;
      case 0xe8c3:
        return headphones;
      case 0xe54d:
        return trendingUp;
      case 0xe467:
        return download;
      case 0xe0a1:
        return reload;
      case 0xec5f:
        return option;
      case 0xe041:
        return arrowDownMd;
      case 0xe093:
        return arrowUpMd;
      case 0xe03f:
        return arrowDownSm;
      case 0xe08f:
        return arrowUpSm;
      case 0xe2df:
        return star;
      case 0xe68b:
        return card;
      case 0xe589:
        return bag;
      case 0xe1e1:
        return card2;
      case 0xe0b5:
        return bank;
      case 0xe105:
        return users;
      case 0xe68f:
        return shareAndroid;
      case 0xe0cf:
        return bellRing;
      case 0xe20d:
        return downloadPack;
      case 0xe1d3:
        return tag;
      case 0xe42b:
        return logOut;
      case 0xe2e9:
        return shieldWarn;
      case 0xe095:
        return qr;
      case 0xe139:
        return chevLeft;
      case 0xe13b:
        return chevRight;
      case 0xe221:
        return show;
      case 0xe225:
        return hide;
      case 0xe1b7:
        return circleWarn;
      case 0xe2fb:
        return lock;
      case 0xe4d1:
        return userAdd;
      case 0xe607:
        return circleCheck;
      case 0xe4f7:
        return closeSm;
      case 0xe059:
        return arrowLeft;
      case 0xe183:
        return check;
      case 0xe4a7:
        return trash;
      case 0xe30d:
        return search;
      case 0xe1a1:
        return clock;
      case 0xe19b:
        return timer;
      case 0xe10b:
        return calendar;
      case 0xe0af:
        return closeSquare;
      case 0xe271:
        return settings;
      case 0xe4e3:
        return warning;
      case 0xe219:
        return mail;
      case 0xe1f0:
        return voice;
      case 0xe1f1:
        return users;
      default:
        return null;
    }
  }
}

/// Tambahan kategori baru di atas cabang [svgForCategory] yang ada.
/// Mengembalikan null bila tak cocok, agar cabang lama tak berubah perilaku.
String? coolForNewCategory(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('invest') ||
      c.contains('saham') ||
      c.contains('reksa') ||
      c.contains('kripto')) {
    return CoolSvg.invest;
  }
  if (c.contains('donasi') ||
      c.contains('sedekah') ||
      c.contains('zakat') ||
      c.contains('infak') ||
      c.contains('infaq')) {
    return CoolSvg.donate;
  }
  if (c.contains('keluarga') ||
      c.contains('anak') ||
      c.contains('istri') ||
      c.contains('suami')) {
    return CoolSvg.family;
  }
  if ((c.contains('olahraga') ||
          c.contains('gym') ||
          c.contains('lari') ||
          c.contains('futsal') ||
          c.contains('sport')) &&
      !c.contains('transport')) {
    // 'transportasi' mengandung 'sport' -> kecualikan agar tetap ikon mobil
    return CoolSvg.sport;
  }
  if (c.contains('hewan') ||
      c.contains('kucing') ||
      c.contains('anjing') ||
      c.contains('pakan') ||
      c.contains('pet')) {
    return CoolSvg.pet;
  }
  if (c.contains('darurat') || c.contains('mendesak') || c.contains('sos')) {
    return CoolSvg.sos;
  }
  return null;
}
