enum UserRole { admin, student }

enum AccountType { firstTime, returning }

enum AppScreen {
  welcome,
  mobile,
  otp,
  ownerSetup,
  studentSetup,
  adminDashboard,
  studentDashboard,
  studentHome,
  partnerHome,
}

enum StudentTab { home, explore, bookings, profile }

enum PartnerTab { overview, seats, members, profile }

class CalendarDayInfo {
  final int day;
  final String status; // 'present', 'absent', 'half-day', 'holiday', 'upcoming'
  final String? inTime;
  final String? outTime;
  final String? hours;
  final String? note;

  const CalendarDayInfo({
    required this.day,
    required this.status,
    this.inTime,
    this.outTime,
    this.hours,
    this.note,
  });
}

class StudyHoursInfo {
  final String day;
  final String fullDay;
  final double hours;
  final String focus;
  final bool isToday;

  const StudyHoursInfo({
    required this.day,
    required this.fullDay,
    required this.hours,
    required this.focus,
    this.isToday = false,
  });
}

class MemberInfo {
  final String? id;
  final String? studentId;
  final String name;
  final String seat;
  final String status; // 'Present', 'Renewal Due', 'Absent', 'Not Yet In'
  final String plan;
  final String phone;
  final String? shiftTiming;
  final String? checkInTime;
  final String membershipStatus; // 'ACTIVE', 'INACTIVE'
  final String? startDate;
  final String? validTill;
  final num? monthlyFee;
  final num? amountPaid;
  final int daysRemaining;
  final bool isDueSoon;
  final String paymentStatus; // 'PAID', 'DUE'
  final String? lastCollectionDate;
  final num? lastCollectedAmount;

  const MemberInfo({
    this.id,
    this.studentId,
    required this.name,
    required this.seat,
    required this.status,
    required this.plan,
    required this.phone,
    this.shiftTiming,
    this.checkInTime,
    this.membershipStatus = 'ACTIVE',
    this.startDate,
    this.validTill,
    this.monthlyFee,
    this.amountPaid,
    this.daysRemaining = 30,
    this.isDueSoon = false,
    this.paymentStatus = 'PAID',
    this.lastCollectionDate,
    this.lastCollectedAmount,
  });

  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    final validTillStr = json['validTill']?.toString();
    final daysRem = json['daysRemaining'] != null ? num.tryParse(json['daysRemaining'].toString())?.toInt() ?? 30 : 30;
    final isDue = json['isDueSoon'] == true || daysRem <= 5;
    final payStatus = json['paymentStatus']?.toString() ?? (isDue ? 'DUE' : 'PAID');

    return MemberInfo(
      id: json['id']?.toString(),
      studentId: json['studentId']?.toString(),
      name: json['name']?.toString() ?? 'Member',
      seat: json['seat']?.toString() ?? 'Unassigned',
      status: json['status']?.toString() ?? 'Active',
      plan: json['plan']?.toString() ?? 'Monthly Plan',
      phone: json['phone']?.toString() ?? '',
      shiftTiming: json['shiftTiming']?.toString(),
      checkInTime: json['checkInTime']?.toString(),
      membershipStatus: json['membershipStatus']?.toString() ?? 'ACTIVE',
      startDate: json['startDate']?.toString(),
      validTill: validTillStr,
      monthlyFee: json['monthlyFee'] != null ? num.tryParse(json['monthlyFee'].toString()) : null,
      amountPaid: json['amountPaid'] != null ? num.tryParse(json['amountPaid'].toString()) : null,
      daysRemaining: daysRem,
      isDueSoon: isDue,
      paymentStatus: payStatus,
      lastCollectionDate: json['lastCollectionDate']?.toString(),
      lastCollectedAmount: json['lastCollectedAmount'] != null ? num.tryParse(json['lastCollectedAmount'].toString()) : null,
    );
  }
}

class SeatInfo {
  final int number;
  final String student;
  final String plan;
  final String status;
  final String time;
  final String validTill;
  final String? shiftTiming;

  const SeatInfo({
    required this.number,
    required this.student,
    required this.plan,
    required this.status,
    required this.time,
    required this.validTill,
    this.shiftTiming,
  });

  factory SeatInfo.fromJson(Map<String, dynamic> json) {
    final status = (json['status']?.toString() ?? 'available').toLowerCase();
    String statusLabel = 'Available';
    if (status == 'occupied') {
      statusLabel = 'Occupied';
      if (json['attendanceToday'] != null) {
        statusLabel = 'Occupied · ${json['attendanceToday']}';
      }
    } else if (status == 'reserved') {
      statusLabel = 'Reserved';
    }

    return SeatInfo(
      number: (json['seatNumber'] as num?)?.toInt() ?? 0,
      student: json['studentName']?.toString() ?? 'Available Desk',
      plan: json['plan']?.toString() ?? 'Monthly Dedicated',
      status: statusLabel,
      time: json['shiftTiming']?.toString() ?? 'Full Day',
      validTill: json['validTill']?.toString() ?? 'Available',
      shiftTiming: json['shiftTiming']?.toString(),
    );
  }
}

class ActivityItem {
  final String icon; // 'check', 'wallet', 'users', 'clock'
  final String title;
  final String detail;
  final bool isHighlight;

  const ActivityItem({
    required this.icon,
    required this.title,
    required this.detail,
    this.isHighlight = false,
  });
}

class FeeCollectionItem {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentPhone;
  final String? studentCode;
  final String? seatLabel;
  final String? planName;
  final num originalAmount;
  final num collectedAmount;
  final String collectionDate;
  final String paymentMode;
  final String? remarks;
  final String? createdAt;

  const FeeCollectionItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentPhone,
    this.studentCode,
    this.seatLabel,
    this.planName,
    required this.originalAmount,
    required this.collectedAmount,
    required this.collectionDate,
    this.paymentMode = 'CASH',
    this.remarks,
    this.createdAt,
  });

  factory FeeCollectionItem.fromJson(Map<String, dynamic> json) {
    return FeeCollectionItem(
      id: json['id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? 'Student',
      studentPhone: json['studentPhone']?.toString(),
      studentCode: json['studentCode']?.toString(),
      seatLabel: json['seatLabel']?.toString(),
      planName: json['planName']?.toString(),
      originalAmount: json['originalAmount'] != null ? num.tryParse(json['originalAmount'].toString()) ?? 0 : 0,
      collectedAmount: json['collectedAmount'] != null ? num.tryParse(json['collectedAmount'].toString()) ?? 0 : 0,
      collectionDate: json['collectionDate']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? 'CASH',
      remarks: json['remarks']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
