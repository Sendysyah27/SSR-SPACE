// SPIKE THROWAWAY — layar uji baca saldo e-money via NFC.
// DIBUANG setelah spike selesai (revert penuh). Bukan fitur asli.
// Memakai prepaid_lib_flutter_null_safety mode dev (MID dummy).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prepaid_lib_flutter_null_safety/unik_lib_flutter.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/section_card.dart';

// Layar uji: 1 tombol tap -> tempel kartu -> tampil mentah semua field.
// Tanpa prefs, tanpa Supabase, tanpa taut dompet. Murni bukti device.
class NfcSpikeScreen extends StatefulWidget {
  const NfcSpikeScreen({super.key});

  @override
  State<NfcSpikeScreen> createState() => _NfcSpikeScreenState();
}

class _NfcSpikeScreenState extends State<NfcSpikeScreen> {
  bool? _initOk;
  String _initErr = '';
  bool _scanning = false;
  bool _ok = false;
  String _uid = '';
  String _num = '';
  String _bal = '';
  String _bank = '';
  String _attr = '';
  String _info = '';
  String _rrn = '';
  String _hist = '';
  bool _timeout = false;
  bool _nfcErr = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _initLib();
  }

  Future<void> _initLib() async {
    var ok = false;
    var err = '';
    try {
      ok = await UnikLibFlutter.initUnikLib('1234567abc', 0);
    } catch (e) {
      err = '$e';
    }
    if (!mounted) return;
    setState(() {
      _initOk = ok;
      _initErr = err;
    });
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _ok = false;
      _err = '';
      _timeout = false;
      _nfcErr = false;
      _uid = '';
      _num = '';
      _bal = '';
      _bank = '';
      _attr = '';
      _info = '';
      _rrn = '';
      _hist = '';
    });
    final uid = <String>[''];
    final num = <String>[''];
    final bal = <String>[''];
    final bank = <String>[''];
    final attr = <String?>[''];
    final info = <String?>[''];
    final rrn = <String?>[''];
    var ok = false;
    var timeout = false;
    var nfcErr = false;
    var err = '';
    try {
      ok = await UnikLibFlutter.getCardInfo(
        uid,
        num,
        bal,
        bank,
        cardAttr: attr,
        cardInfo: info,
        rrn: rrn,
        startPooling: true,
        callbackTimeout: (bool t) {
          timeout = t;
        },
        errorNfc: (bool e) {
          nfcErr = e;
        },
      );
    } catch (e) {
      err = '$e';
    }
    var hist = '';
    if (ok) {
      try {
        final h = <String>[''];
        final hok = await UnikLibFlutter.getHistory(h);
        hist = hok ? h[0] : '(getHistory=false utk kartu ini)';
      } catch (e) {
        hist = '(getHistory error: $e)';
      }
    }
    try {
      await UnikLibFlutter.stopReader(
        messageSuccess: ok ? 'Baca kartu berhasil' : '',
        messageError: ok ? '' : 'Baca kartu gagal',
      );
    } catch (e) {
      debugPrint('spike stopReader: $e');
    }
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _ok = ok;
      _uid = uid[0];
      _num = num[0];
      _bal = bal[0];
      _bank = bank[0];
      _attr = '${attr[0]}';
      _info = '${info[0]}';
      _rrn = '${rrn[0]}';
      _hist = hist;
      _timeout = timeout;
      _nfcErr = nfcErr;
      _err = err;
    });
  }

  Future<void> _stop() async {
    try {
      await UnikLibFlutter.stopReader(messageError: 'Dibatalkan user');
    } catch (e) {
      debugPrint('spike stop manual: $e');
    }
    if (!mounted) return;
    setState(() => _scanning = false);
  }

  String get _report {
    return 'init=${_initOk.toString()} initErr=${_initErr.isEmpty ? "-" : _initErr}\n'
        'ok=$_ok err=${_err.isEmpty ? "-" : _err}\n'
        'uid=$_uid\nnomor=$_num\nsaldo=$_bal\nbank=$_bank\n'
        'cardAttr=$_attr\ncardInfo=$_info\nrrn=$_rrn\n'
        'timeout=$_timeout nfcError=$_nfcErr\n'
        'history=$_hist';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hasil disalin, kirim ke developer')),
    );
  }

  Widget _initCard() {
    final init = _initOk;
    final label = init == null
        ? 'Inisialisasi library…'
        : init
            ? 'Library siap (dev)'
            : 'Init GAGAL: ${_initErr.isEmpty ? "unknown" : _initErr}';
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Text(label),
    );
  }

  Widget _buttons() {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _scanning ? null : _scan,
            child: const Text('Tempel kartu & baca'),
          ),
          const SizedBox(height: SsrSpace.sm),
          OutlinedButton(
            onPressed: _scanning ? _stop : null,
            child: const Text('Stop'),
          ),
          if (_scanning) ...[
            const SizedBox(height: SsrSpace.sm),
            const LinearProgressIndicator(),
            const SizedBox(height: SsrSpace.sm),
            const Text('Tempelkan kartu ke HP, jangan dilepas…'),
          ],
        ],
      ),
    );
  }

  Widget _resultCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(_report, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: SsrSpace.sm),
          OutlinedButton(
            onPressed: _copy,
            child: const Text('Salin hasil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uji NFC (spike)')),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [_initCard(), _buttons(), _resultCard()],
      ),
    );
  }
}
