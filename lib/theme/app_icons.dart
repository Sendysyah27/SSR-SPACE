import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Peta semantik ikon aplikasi ke Phosphor duotone.
///
/// Render lewat widget `PhosphorIcon`, bukan `Icon`: hanya `PhosphorIcon`
/// yang menggambar lapisan sekunder pada opacity 20% (tint zamrud lembut),
/// sesuai token desain primer/sekunder.
class AppIcons {
  AppIcons._();

  // Navigasi bawah & aksi utama
  static const home = PhosphorIconsDuotone.house;
  static const transactions = PhosphorIconsDuotone.receipt;
  static const budget = PhosphorIconsDuotone.piggyBank;
  static const reports = PhosphorIconsDuotone.chartBar;
  static const menu = PhosphorIconsDuotone.squaresFour;
  static const add = PhosphorIconsDuotone.plus;

  // Kategori transaksi (pengganti Material di category_icons)
  static const food = PhosphorIconsDuotone.forkKnife;
  static const transport = PhosphorIconsDuotone.car;
  static const shopping = PhosphorIconsDuotone.shoppingBagOpen;
  static const bills = PhosphorIconsDuotone.receipt;
  static const health = PhosphorIconsDuotone.heart;
  static const education = PhosphorIconsDuotone.graduationCap;
  static const entertainment = PhosphorIconsDuotone.filmSlate;
  static const income = PhosphorIconsDuotone.currencyCircleDollar;
  static const topup = PhosphorIconsDuotone.stack;
  static const transfer = PhosphorIconsDuotone.arrowsLeftRight;
  static const categoryFallback = PhosphorIconsDuotone.shapes;

  // Arah transaksi
  static const txIn = PhosphorIconsDuotone.arrowDownLeft;
  static const txOut = PhosphorIconsDuotone.arrowUpRight;
  static const arrowDown = PhosphorIconsDuotone.arrowDown;
  static const arrowUp = PhosphorIconsDuotone.arrowUp;
  static const autoBadge = PhosphorIconsDuotone.lightning;

  // Dompet
  static const wallet = PhosphorIconsDuotone.wallet;
  static const walletCash = PhosphorIconsDuotone.money;
  static const walletEwallet = PhosphorIconsDuotone.deviceMobile;
  static const walletBank = PhosphorIconsDuotone.bank;

  // Menu Lainnya & utilitas
  static const workspace = PhosphorIconsDuotone.buildings;
  static const workspaceSwitch = PhosphorIconsDuotone.arrowsLeftRight;
  static const invite = PhosphorIconsDuotone.usersThree;
  static const tracking = PhosphorIconsDuotone.bell;
  static const backup = PhosphorIconsDuotone.downloadSimple;
  static const billing = PhosphorIconsDuotone.creditCard;
  static const logout = PhosphorIconsDuotone.signOut;
  static const revoke = PhosphorIconsDuotone.linkSimpleBreak;
  static const scan = PhosphorIconsDuotone.arrowsClockwise;
  static const monthPrev = PhosphorIconsDuotone.caretLeft;
  static const monthNext = PhosphorIconsDuotone.caretRight;
  static const chevron = PhosphorIconsDuotone.caretRight;
  static const eye = PhosphorIconsDuotone.eye;
  static const eyeOff = PhosphorIconsDuotone.eyeSlash;
  static const error = PhosphorIconsDuotone.cloudSlash;
  static const lock = PhosphorIconsDuotone.lock;
  static const addUser = PhosphorIconsDuotone.userPlus;
  static const success = PhosphorIconsDuotone.sealCheck;
}
