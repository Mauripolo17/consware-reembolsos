import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/liquid_glass_panel.dart';

class NewReimbursementView extends StatefulWidget {
  final ReimbursementApiService apiService;
  final void Function(Reimbursement created) onCreatedSuccess;

  const NewReimbursementView({
    super.key,
    required this.apiService,
    required this.onCreatedSuccess,
  });

  @override
  State<NewReimbursementView> createState() => _NewReimbursementViewState();
}

class _NewReimbursementViewState extends State<NewReimbursementView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = AppConfig.categories.first;
  bool _isSubmitting = false;

  String? _amountError;
  String? _categoryError;
  String? _descriptionError;
  String? _generalErrorMessage;
  String? _traceId;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double? get _previewAmount {
    final result = InputValidators.validateAmount(_amountController.text);
    return result.value;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();

    final amountCheck = InputValidators.validateAmount(_amountController.text);
    final categoryErr = InputValidators.validateCategory(_selectedCategory);
    final descriptionErr =
        InputValidators.validateDescription(_descriptionController.text);

    setState(() {
      _amountError = amountCheck.error;
      _categoryError = categoryErr;
      _descriptionError = descriptionErr;
      _generalErrorMessage = null;
      _traceId = null;
    });

    if (!amountCheck.isValid || categoryErr != null || descriptionErr != null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final input = CreateReimbursementInput(
      employeeName: AppConfig.fixedEmployeeName,
      amount: amountCheck.value!,
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
    );

    final response = await widget.apiService.createReimbursement(input);
    if (!mounted) {
      return;
    }

    if (response.success && response.data != null) {
      final created = response.data!;
      _amountController.clear();
      _descriptionController.clear();
      setState(() {
        _isSubmitting = false;
        _selectedCategory = AppConfig.categories.first;
        _amountError = null;
        _categoryError = null;
        _descriptionError = null;
        _generalErrorMessage = null;
        _traceId = null;
      });
      widget.onCreatedSuccess(created);
      return;
    }

    final fieldErrors = response.fieldErrors;
    final generalMessages = response.generalErrors
        .map((e) => e.message)
        .where((m) => m.isNotEmpty)
        .toList();

    setState(() {
      _isSubmitting = false;
      _amountError = fieldErrors['amount'];
      _categoryError = fieldErrors['category'];
      _descriptionError = fieldErrors['description'];
      if (generalMessages.isNotEmpty) {
        _generalErrorMessage = generalMessages.join('\n');
      } else if (fieldErrors.isEmpty) {
        _generalErrorMessage = response.message;
      } else {
        _generalErrorMessage = response.message;
      }
      _traceId = response.traceId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isExpanded = screenWidth >= 1024;
    final previewAmount = _previewAmount;
    final isAutoApprovePreview =
        previewAmount != null && previewAmount <= AppConfig.autoApprovalLimitCop;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LiquidGlassPanel(
              useBackdropBlur: true,
              padding: EdgeInsets.all(isExpanded ? 28 : 20),
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Nueva solicitud de reembolso',
                    style: TextStyle(
                      fontSize: isExpanded ? 28 : 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completa los datos del gasto corporativo. Las solicitudes de hasta \$500.000 COP se aprueban automáticamente.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Fixed employee identity card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(
                          Icons.badge_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Colaborador solicitante (fijo)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                AppConfig.fixedEmployeeName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_generalErrorMessage != null) ...<Widget>[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.errorBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _generalErrorMessage!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.rejectedText,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_traceId != null && _traceId!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              'Referencia: $_traceId',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Reintentar envío'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Amount input
                  const Text(
                    'Monto en pesos colombianos (COP) *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('amount_input'),
                    controller: _amountController,
                    enabled: !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      setState(() {
                        if (_amountError != null) {
                          _amountError = null;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Ej: 185000 o 500000.50',
                      prefixIcon: const Icon(
                        Icons.attach_money_rounded,
                        color: AppTheme.primary,
                      ),
                      suffixText: 'COP',
                      helperText:
                          'Escribe solo dígitos sin puntos de miles (máximo 2 decimales).',
                      errorText: _amountError,
                    ),
                  ),
                  if (previewAmount != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isAutoApprovePreview
                            ? AppTheme.approvedBg.withValues(alpha: 0.65)
                            : AppTheme.pendingBg.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAutoApprovePreview
                              ? AppTheme.approvedBorder.withValues(alpha: 0.5)
                              : AppTheme.pendingBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            isAutoApprovePreview
                                ? Icons.bolt_rounded
                                : Icons.supervisor_account_rounded,
                            size: 18,
                            color: isAutoApprovePreview
                                ? AppTheme.approvedText
                                : AppTheme.pendingText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isAutoApprovePreview
                                  ? 'Monto: ${Formatters.formatCop(previewAmount)} — Aprobación automática inmediata (≤ \$500.000 COP).'
                                  : 'Monto: ${Formatters.formatCop(previewAmount)} — Quedará Pendiente de revisión por un aprobador (> \$500.000 COP).',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isAutoApprovePreview
                                    ? AppTheme.approvedText
                                    : AppTheme.pendingText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Category input
                  const Text(
                    'Categoría del gasto *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const Key('category_dropdown'),
                    initialValue: _selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.category_rounded,
                        color: AppTheme.primary,
                      ),
                      errorText: _categoryError,
                    ),
                    items: AppConfig.categories
                        .map(
                          (String cat) => DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedCategory = newValue;
                                _categoryError = null;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 20),
                  // Description input
                  const Text(
                    'Descripción detallada *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('description_input'),
                    controller: _descriptionController,
                    enabled: !_isSubmitting,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (_) {
                      if (_descriptionError != null) {
                        setState(() {
                          _descriptionError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Indica el motivo del gasto, ciudad, cliente o actividad...',
                      alignLabelWithHint: true,
                      helperText: 'Requerido · Máximo 500 caracteres.',
                      errorText: _descriptionError,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      key: const Key('submit_reimbursement_button'),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _isSubmitting
                            ? 'Enviando solicitud...'
                            : 'Registrar solicitud de reembolso',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
