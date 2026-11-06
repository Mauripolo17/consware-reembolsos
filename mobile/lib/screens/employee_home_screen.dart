import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/liquid_glass_panel.dart';
import 'new_reimbursement_view.dart';
import 'requests_list_view.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final ReimbursementApiService apiService;

  const EmployeeHomeScreen({
    super.key,
    required this.apiService,
  });

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _selectedIndex = 0; // 0 = Mis solicitudes, 1 = Nuevo gasto
  List<Reimbursement> _items = <Reimbursement>[];
  bool _isLoading = false;
  String? _errorMessage;
  ReimbursementStatus? _statusFilter;
  String? _bannerMessage;
  int _loadGeneration = 0;

  final ScrollController _listScrollController = ScrollController();
  final ScrollController _formScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final int currentGeneration = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.apiService.getReimbursements(
      employeeName: AppConfig.fixedEmployeeName,
      status: _statusFilter,
    );

    if (!mounted || currentGeneration != _loadGeneration) {
      return;
    }

    if (response.success && response.data != null) {
      setState(() {
        _items = response.data!;
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      final generalMsg = response.generalErrors.isNotEmpty
          ? response.generalErrors.map((e) => e.message).join('\n')
          : response.message;
      setState(() {
        _isLoading = false;
        _errorMessage = generalMsg;
      });
    }
  }

  void _onStatusFilterChanged(ReimbursementStatus? status) {
    setState(() {
      _statusFilter = status;
    });
    _loadRequests();
  }

  void _onCreatedSuccess(Reimbursement created) {
    final statusMsg = created.status == ReimbursementStatus.approved
        ? 'Solicitud #${created.id} por ${Formatters.formatCop(created.amount)} aprobada automáticamente.'
        : 'Solicitud #${created.id} por ${Formatters.formatCop(created.amount)} registrada en estado Pendiente.';

    setState(() {
      _selectedIndex = 0;
      _statusFilter = null;
      _bannerMessage = statusMsg;
    });

    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }
    if (_formScrollController.hasClients) {
      _formScrollController.jumpTo(0);
    }

    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isExpanded = screenWidth >= 1024;
    final bool isMedium = screenWidth >= 600 && screenWidth < 1024;
    final EdgeInsets scrollPadding = EdgeInsets.symmetric(
      horizontal: isExpanded
          ? 32
          : isMedium
              ? 24
              : 16,
      vertical: isExpanded ? 24 : 16,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: <Widget>[
          // Subtle ambient liquid-glass gradients
          Positioned(
            top: -100,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppTheme.accent.withValues(alpha: 0.22),
                      AppTheme.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppTheme.primary.withValues(alpha: 0.14),
                      AppTheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                _TopHeaderBar(
                  isExpanded: isExpanded,
                  selectedIndex: _selectedIndex,
                  onSelectTab: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: <Widget>[
                      SingleChildScrollView(
                        key: const PageStorageKey<String>('requests_list_scroll'),
                        controller: _listScrollController,
                        padding: scrollPadding,
                        child: RequestsListView(
                          items: _items,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          selectedStatusFilter: _statusFilter,
                          onStatusFilterChanged: _onStatusFilterChanged,
                          onRefresh: _loadRequests,
                          onGoToNewRequest: () {
                            setState(() {
                              _selectedIndex = 1;
                            });
                          },
                          bannerMessage: _bannerMessage,
                          onDismissBanner: () {
                            setState(() {
                              _bannerMessage = null;
                            });
                          },
                        ),
                      ),
                      SingleChildScrollView(
                        key: const PageStorageKey<String>('new_expense_scroll'),
                        controller: _formScrollController,
                        padding: scrollPadding,
                        child: NewReimbursementView(
                          apiService: widget.apiService,
                          onCreatedSuccess: _onCreatedSuccess,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isExpanded
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Color(0xF5FFFFFF),
                border: Border(
                  top: BorderSide(color: Color(0xFFBFDBFE), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _selectedIndex,
                  indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.format_list_bulleted_rounded),
                      selectedIcon: Icon(
                        Icons.format_list_bulleted_rounded,
                        color: AppTheme.primary,
                      ),
                      label: 'Mis solicitudes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.add_card_rounded),
                      selectedIcon: Icon(
                        Icons.add_card_rounded,
                        color: AppTheme.primary,
                      ),
                      label: 'Nuevo gasto',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TopHeaderBar extends StatelessWidget {
  final bool isExpanded;
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;

  const _TopHeaderBar({
    required this.isExpanded,
    required this.selectedIndex,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isExpanded ? 32 : 16,
        isExpanded ? 20 : 12,
        isExpanded ? 32 : 16,
        8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: LiquidGlassPanel(
            useBackdropBlur: true,
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 24 : 16,
              vertical: 14,
            ),
            borderRadius: 20,
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[AppTheme.primary, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Consware Reembolsos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Portal del colaborador · ${AppConfig.fixedEmployeeName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isExpanded)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _TopNavTabButton(
                        key: const Key('nav_requests_tab'),
                        label: 'Mis solicitudes',
                        icon: Icons.format_list_bulleted_rounded,
                        isSelected: selectedIndex == 0,
                        onTap: () => onSelectTab(0),
                      ),
                      const SizedBox(width: 10),
                      _TopNavTabButton(
                        key: const Key('nav_new_expense_tab'),
                        label: 'Nuevo gasto',
                        icon: Icons.add_card_rounded,
                        isSelected: selectedIndex == 1,
                        onTap: () => onSelectTab(1),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNavTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopNavTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primary : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
