import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Six single-digit PIN fields (matches client PinInput length=6).
class PinInputRow extends StatefulWidget {
  final int length;
  final ValueChanged<String> onComplete;
  final bool enabled;

  const PinInputRow({
    super.key,
    this.length = 6,
    required this.onComplete,
    this.enabled = true,
  });

  @override
  State<PinInputRow> createState() => _PinInputRowState();
}

class _PinInputRowState extends State<PinInputRow> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  static const double _minBoxSize = 36;
  static const double _maxBoxSize = 48;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (i) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      return node;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      value = value.substring(value.length - 1);
      _controllers[index].text = value;
      _controllers[index].selection =
          TextSelection.collapsed(offset: value.length);
    }
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length == widget.length) {
      widget.onComplete(pin);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final digitColor = isDark ? AppColors.darkForeground : AppColors.charcoal;
    final fillColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final focusColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    final pinStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 1.0,
      color: digitColor,
      letterSpacing: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final totalGap = gap * (widget.length - 1);
        final boxWidth = ((constraints.maxWidth - totalGap) / widget.length)
            .clamp(_minBoxSize, _maxBoxSize);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            final hasFocus = _focusNodes[index].hasFocus;
            final hasValue = _controllers[index].text.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(right: index < widget.length - 1 ? gap : 0),
              child: SizedBox(
                width: boxWidth,
                height: boxWidth + 4,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: pinStyle,
                  cursorColor: focusColor,
                  cursorWidth: 2,
                  showCursor: hasFocus,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: fillColor,
                    contentPadding: EdgeInsets.symmetric(vertical: boxWidth * 0.22),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: hasValue
                            ? focusColor.withValues(alpha: 0.6)
                            : borderColor,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: focusColor, width: 2.5),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                    _onChanged(index, v);
                  },
                  onSubmitted: (_) {
                    if (index < widget.length - 1) {
                      _focusNodes[index + 1].requestFocus();
                    }
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
