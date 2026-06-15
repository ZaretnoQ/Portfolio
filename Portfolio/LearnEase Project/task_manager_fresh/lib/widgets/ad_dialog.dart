// lib/widgets/ad_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// A dialog that shows a progress bar counting down [duration], then auto-closes.
class AdDialog extends StatefulWidget {
  final Duration duration;
  const AdDialog({Key? key, this.duration = const Duration(seconds: 10)}) : super(key: key);

  @override
  State<AdDialog> createState() => _AdDialogState();
}

class _AdDialogState extends State<AdDialog> {
  double _progress = 0;
  late final int _totalMs;
  late final Timer _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _totalMs = widget.duration.inMilliseconds;
    // fire every 100ms to update progress
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      _elapsed += 100;
      setState(() {
        _progress = _elapsed / _totalMs;
      });
      if (_elapsed >= _totalMs) {
        t.cancel();
        Navigator.of(context).pop(); // close the ad
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 200),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ad placeholder',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '${((widget.duration.inSeconds) - (_progress * widget.duration.inSeconds)).ceil()}s',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
