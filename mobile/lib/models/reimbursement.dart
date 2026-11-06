enum ReimbursementStatus {
  pending('Pending', 'Pendiente', 'Pendientes'),
  approved('Approved', 'Aprobado', 'Aprobadas'),
  rejected('Rejected', 'Rechazado', 'Rechazadas');

  final String wireValue;
  final String spanishLabel;
  final String filterLabel;

  const ReimbursementStatus(
    this.wireValue,
    this.spanishLabel,
    this.filterLabel,
  );

  static ReimbursementStatus fromWire(String? value) {
    switch (value?.trim()) {
      case 'Pending':
        return ReimbursementStatus.pending;
      case 'Approved':
        return ReimbursementStatus.approved;
      case 'Rejected':
        return ReimbursementStatus.rejected;
      default:
        throw FormatException('Invalid reimbursement status: $value');
    }
  }
}

class Reimbursement {
  final int id;
  final String employeeName;
  final double amount;
  final String category;
  final String description;
  final ReimbursementStatus status;
  final String? rejectionReason;
  final DateTime createdAtUtc;
  final DateTime? decidedAtUtc;

  const Reimbursement({
    required this.id,
    required this.employeeName,
    required this.amount,
    required this.category,
    required this.description,
    required this.status,
    required this.rejectionReason,
    required this.createdAtUtc,
    required this.decidedAtUtc,
  });

  factory Reimbursement.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final int? parsedId = rawId is int
        ? rawId
        : (rawId is num && rawId == rawId.toInt())
            ? rawId.toInt()
            : null;
    if (parsedId == null || parsedId <= 0) {
      throw const FormatException('Invalid reimbursement id');
    }

    final rawEmployee = json['employeeName'];
    final rawCategory = json['category'];
    final rawDescription = json['description'];
    if (rawEmployee is! String ||
        rawEmployee.trim().isEmpty ||
        rawCategory is! String ||
        rawCategory.trim().isEmpty ||
        rawDescription is! String ||
        rawDescription.trim().isEmpty) {
      throw const FormatException('Missing required string fields');
    }

    final rawAmount = json['amount'];
    if (rawAmount is! num || !rawAmount.isFinite || rawAmount <= 0) {
      throw const FormatException('Invalid reimbursement amount');
    }

    final rawCreated = json['createdAtUtc'];
    final createdAt =
        rawCreated is String ? DateTime.tryParse(rawCreated)?.toUtc() : null;
    if (createdAt == null) {
      throw const FormatException('Invalid createdAtUtc');
    }

    final rawDecided = json['decidedAtUtc'];
    DateTime? decidedAt;
    if (rawDecided != null) {
      if (rawDecided is! String || rawDecided.trim().isEmpty) {
        throw const FormatException('Invalid decidedAtUtc');
      }
      decidedAt = DateTime.tryParse(rawDecided)?.toUtc();
      if (decidedAt == null) {
        throw const FormatException('Invalid decidedAtUtc format');
      }
    }

    final rawReason = json['rejectionReason'];
    String? rejectionReason;
    if (rawReason != null) {
      if (rawReason is! String) {
        throw const FormatException('Invalid rejectionReason');
      }
      final trimmedReason = rawReason.trim();
      rejectionReason = trimmedReason.isEmpty ? null : trimmedReason;
    }

    final status = ReimbursementStatus.fromWire(json['status']?.toString());

    return Reimbursement(
      id: parsedId,
      employeeName: rawEmployee,
      amount: rawAmount.toDouble(),
      category: rawCategory,
      description: rawDescription,
      status: status,
      rejectionReason: rejectionReason,
      createdAtUtc: createdAt,
      decidedAtUtc: decidedAt,
    );
  }
}

class CreateReimbursementInput {
  final String employeeName;
  final double amount;
  final String category;
  final String description;

  const CreateReimbursementInput({
    required this.employeeName,
    required this.amount,
    required this.category,
    required this.description,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'employeeName': employeeName.trim(),
        'amount': amount,
        'category': category.trim(),
        'description': description.trim(),
      };
}
