import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de PIN de 4 dígitos. Chama [onCompleted] quando os 4 são digitados.
class PinField extends StatefulWidget {
  const PinField({
    super.key,
    required this.onCompleted,
    this.enabled = true,
    this.autofocus = true,
  });

  final ValueChanged<String> onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  State<PinField> createState() => PinFieldState();
}

class PinFieldState extends State<PinField> {
  final _controller = TextEditingController();

  void clear() => _controller.clear();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, letterSpacing: 12),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: '', hintText: '••••'),
        onChanged: (v) {
          if (v.length == 4) widget.onCompleted(v);
        },
      ),
    );
  }
}
