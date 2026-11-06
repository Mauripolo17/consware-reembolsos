import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/reimbursement.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass_panel.dart';
import '../widgets/reimbursement_card.dart';

class RequestsListView extends StatelessWidget {
  final List<Reimbursement> items;
  final bool isLoading;
  final String? errorMessage;
  final ReimbursementStatus? selectedStatusFilter;
  final ValueChanged<ReimbursementStatus?> onStatusFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback onGoToNewRequest;
  final String? bannerMessage;
  final VoidCallback? onDismissBanner;

  const RequestsListView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.errorMessage,
    required this.selectedStatusFilter,
    required this.onStatusFilterChanged,
    required this.onRefresh,
    required this.onGoToNewRequest,
    this.bannerMessage,
    this.onDismissBanner,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isExpanded = screenWidth >= 1024;
    final isCompact = screenWidth < 600;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header glass panel
            LiquidGlassPanel(
              useBackdropBlur: true,
              padding: EdgeInsets.all(isExpanded ? 24 : 18),
              borderRadius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Mis solicitudes de reembolso',
                            style: TextStyle(
                              fontSize: isExpanded ? 26 : 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Colaborador: ${AppConfig.fixedEmployeeName} · Ordenadas de la más reciente a la más antigua',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          key: const Key('refresh_requests_button'),
                          onPressed: isLoading ? null : onRefresh,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Actualizar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Filtrar por estado',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isCompact ? double.infinity : 320,
                    ),
                    child: DropdownButtonFormField<ReimbursementStatus?>(
                      key: const Key('status_filter_dropdown'),
                      initialValue: selectedStatusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.filter_list_rounded,
                          color: AppTheme.primary,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: <DropdownMenuItem<ReimbursementStatus?>>[
                        const DropdownMenuItem<ReimbursementStatus?>(
                          value: null,
                          child: Text('Todas'),
                        ),
                        ...ReimbursementStatus.values.map(
                          (ReimbursementStatus status) =>
                              DropdownMenuItem<ReimbursementStatus?>(
                            value: status,
                            child: Text(status.filterLabel),
                          ),
                        ),
                      ],
                      onChanged: (ReimbursementStatus? newStatus) {
                        onStatusFilterChanged(newStatus);
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (bannerMessage != null && bannerMessage!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.successBorder),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.successText,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        bannerMessage!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successText,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (onDismissBanner != null)
                      IconButton(
                        onPressed: onDismissBanner,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppTheme.successText,
                        ),
                        tooltip: 'Cerrar aviso',
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (isLoading && items.isEmpty)
              LiquidGlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 48,
                ),
                child: Column(
                  children: const <Widget>[
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text(
                      'Cargando solicitudes de reembolso...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Consultando el historial de Empleado Demo en el servidor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (errorMessage != null)
              LiquidGlassPanel(
                backgroundColor: AppTheme.errorSurface,
                borderColor: AppTheme.errorBorder,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No pudimos cargar las solicitudes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.rejectedText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.rejectedText,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      key: const Key('retry_requests_button'),
                      onPressed: isLoading ? null : onRefresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar conexión'),
                    ),
                  ],
                ),
              )
            else if (items.isEmpty)
              LiquidGlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 44,
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 30,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selectedStatusFilter == null
                          ? 'Aún no tienes solicitudes registradas'
                          : 'No hay solicitudes con estado "${selectedStatusFilter!.spanishLabel}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Registra un nuevo gasto corporativo para iniciar el proceso de reembolso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: onGoToNewRequest,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Registrar nuevo gasto'),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (BuildContext context, int index) {
                  return ReimbursementCard(item: items[index]);
                },
              ),
          ],
        ),
      ),
    );
  }
}
