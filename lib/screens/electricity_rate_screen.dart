import 'package:flutter/services.dart';

import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';

class ElectricityRateScreen extends StatefulWidget {
  const ElectricityRateScreen({
    required this.controller,
    super.key,
  });

  final AppSettingsController controller;

  @override
  State<ElectricityRateScreen> createState() => _ElectricityRateScreenState();
}

class _ElectricityRateScreenState extends State<ElectricityRateScreen> {
  static const _previewEnergyKwh = 270.5;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rateController;
  late double _previewRate;

  @override
  void initState() {
    super.initState();
    _previewRate = widget.controller.electricityRate;
    _rateController = TextEditingController(
      text: _previewRate.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  double? _parseRate(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? _validateRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr('Please enter an electricity rate.');
    }

    final rate = _parseRate(value);
    if (!AppSettingsController.isValidElectricityRate(rate)) {
      return context.tr('Enter a rate from 0.01 to 100.00.');
    }
    return null;
  }

  void _updatePreview(String value) {
    final rate = _parseRate(value);
    if (AppSettingsController.isValidElectricityRate(rate)) {
      setState(() => _previewRate = rate!);
    }
  }

  Future<void> _saveRate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rate = _parseRate(_rateController.text)!;
    await widget.controller.setElectricityRate(rate);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.tr('Electricity rate saved.'))),
      );
    Navigator.of(context).pop();
  }

  String _rateText(BuildContext context, double rate) {
    final amount = formatDecimal(rate);
    return AppLocalizations.of(context).isThai
        ? '$amount บาท / kWh'
        : '${context.tr('THB')} $amount / kWh';
  }

  String _costText(BuildContext context, double cost) {
    final amount = formatDecimal(cost);
    return AppLocalizations.of(context).isThai
        ? '$amount บาท'
        : '${context.tr('THB')} $amount';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final estimatedCost = _previewEnergyKwh * _previewRate;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Electricity Rate'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    color: AppColors.orange,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Current rate'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _rateText(context, widget.controller.electricityRate),
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('Rate per kWh'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Form(
            key: _formKey,
            child: TextFormField(
              key: const Key('electricity-rate-field'),
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(6),
              ],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _validateRate,
              onChanged: _updatePreview,
              decoration: InputDecoration(
                hintText: context.tr('e.g. 4.50'),
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: context.tr('THB / kWh'),
                helperText: context.tr(
                  'Enter a rate from 0.01 to 100.00 per kWh.',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('Calculation Preview'),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                _CalculationRow(
                  label: context.tr('Energy usage'),
                  value: '${formatDecimal(_previewEnergyKwh)} kWh',
                ),
                const SizedBox(height: 10),
                _CalculationRow(
                  label: context.tr('Electricity rate'),
                  value: _rateText(context, _previewRate),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Divider(
                    height: 1,
                    color: colors.outlineVariant,
                  ),
                ),
                _CalculationRow(
                  label: context.tr('Estimated cost'),
                  value: _costText(context, estimatedCost),
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppColors.blue,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr('Cost = Energy (kWh) × Electricity rate'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              key: const Key('save-electricity-rate-button'),
              onPressed: _saveRate,
              icon: const Icon(Icons.save_rounded),
              label: Text(context.tr('Save Rate')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculationRow extends StatelessWidget {
  const _CalculationRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: emphasized ? Theme.of(context).colorScheme.primary : colors.onSurface,
            fontSize: emphasized ? 18 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
