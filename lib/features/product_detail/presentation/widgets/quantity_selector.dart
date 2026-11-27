import 'package:flutter/services.dart';
import 'package:ipr_mobile/features/product_detail/domain/rules/quantity_rules.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Selector de cantidad `−` / valor / `+` (RF-029, AC-029-1..3): de 1 a
/// [maxQuantity] (99 por defecto). Cada parte mide al menos 48 dp; el valor se
/// puede escribir con teclado numérico y lo inválido se corrige al rango con
/// mensaje. Anuncia cada cambio a los lectores de pantalla.
class QuantitySelector extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    super.key,
    this.minQuantity = QuantityRules.min,
    this.maxQuantity = QuantityRules.max,
  });

  final int value;
  final ValueChanged<int> onChanged;

  /// Rango de esta compra: el del producto (W1-06) o 1–99.
  final int minQuantity;
  final int maxQuantity;

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _showRangeError = false;
  late int _lastCommitted = widget.value;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(QuantitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final typed = int.tryParse(_controller.text);
    if (widget.value != oldWidget.value && typed != widget.value) {
      _controller.text = '${widget.value}';
      _lastCommitted = widget.value;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // El envío ("Listo") ya confirmó el valor: no se confirma dos veces, o se
    // borraría el mensaje de corrección.
    if (!_focus.hasFocus && _controller.text != '$_lastCommitted') {
      _commit(_controller.text);
    }
  }

  void _commit(String raw) {
    final input = QuantityRules.parse(
      raw,
      minQuantity: widget.minQuantity,
      maxQuantity: widget.maxQuantity,
    );
    _controller.text = '${input.value}';
    _lastCommitted = input.value;
    setState(() => _showRangeError = input.corrected);
    if (input.value != widget.value) widget.onChanged(input.value);
  }

  void _step(int delta) {
    final next = QuantityRules.clamp(
      widget.value + delta,
      minQuantity: widget.minQuantity,
      maxQuantity: widget.maxQuantity,
    );
    setState(() => _showRangeError = false);
    _controller.text = '$next';
    _lastCommitted = next;
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final min = widget.minQuantity.clamp(QuantityRules.min, QuantityRules.max);
    final max = widget.maxQuantity.clamp(min, QuantityRules.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: IprSpace.s3,
          runSpacing: IprSpace.s1,
          children: [
            Text(
              l10n.productDetailQuantityLabel,
              style: theme.textTheme.titleSmall,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  tooltip: l10n.productDetailQuantityDecrease,
                  constraints: const BoxConstraints(
                    minWidth: IprSpace.minTapTarget,
                    minHeight: IprSpace.minTapTarget,
                  ),
                  onPressed: widget.value > min ? () => _step(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 72,
                  child: Semantics(
                    liveRegion: true,
                    label: l10n.productDetailQuantitySemantics(widget.value),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onSubmitted: _commit,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: IprSpace.s3,
                          horizontal: IprSpace.s1,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: l10n.productDetailQuantityIncrease,
                  constraints: const BoxConstraints(
                    minWidth: IprSpace.minTapTarget,
                    minHeight: IprSpace.minTapTarget,
                  ),
                  onPressed: widget.value < max ? () => _step(1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
        if (_showRangeError)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: IprSpace.s1),
              child: Text(
                l10n.productDetailQuantityRangeError(min, max),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
