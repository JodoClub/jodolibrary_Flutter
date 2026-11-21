// Data model and rate card configuration based on Jodo Library Tiered + Dynamic Shift Pricing.
// Ref: Self Study Library Pricing Strategy

class LibraryShiftSlot {
  final String category; // '3 Hours', '6 Hours', '8 Hours', '12 Hours', 'Night Shift', '24 Hours'
  final String planName; // e.g. '3 Hours (Non-Peak)', '6 Hours (Morning/Evening)'
  final String timing; // Canonical timing e.g. '06:00 AM - 09:00 AM'
  final String displayTiming; // Friendly timing label
  final String tag; // e.g. 'Non-Peak', 'Peak Rush 🔥', 'Popular ⭐', 'Budget Booster 🌙', 'VIP 👑'
  final double fee1m; // 1 Month Fee (₹)
  final double fee3m; // 3 Months Fee (₹)
  final double fee6m; // 6 Months Fee (₹)
  final double fee1y; // 1 Year Fee (₹)
  final String effectiveHourly; // e.g. '₹3.3 / hr'
  final bool isDedicatedSeat; // true for 24h dedicated
  final bool branch2Only; // true for Night Shifts & 24h

  const LibraryShiftSlot({
    required this.category,
    required this.planName,
    required this.timing,
    required this.displayTiming,
    required this.tag,
    required this.fee1m,
    required this.fee3m,
    required this.fee6m,
    required this.fee1y,
    required this.effectiveHourly,
    this.isDedicatedSeat = false,
    this.branch2Only = false,
  });

  /// Get total fee for the selected duration
  double getFeeForDuration(String duration) {
    switch (duration.toLowerCase()) {
      case '3m':
        return fee3m;
      case '6m':
        return fee6m;
      case '1y':
      case '12m':
        return fee1y;
      case '1m':
      default:
        return fee1m;
    }
  }

  /// Effective monthly rate for the chosen duration
  double getEffectiveMonthly(String duration) {
    switch (duration.toLowerCase()) {
      case '3m':
        return (fee3m / 3.0);
      case '6m':
        return (fee6m / 6.0);
      case '1y':
      case '12m':
        return (fee1y / 12.0);
      case '1m':
      default:
        return fee1m;
    }
  }

  /// Savings compared to paying month-by-month at base rate
  double getSavingsAmount(String duration) {
    switch (duration.toLowerCase()) {
      case '3m':
        return (fee1m * 3) - fee3m;
      case '6m':
        return (fee1m * 6) - fee6m;
      case '1y':
      case '12m':
        return (fee1m * 12) - fee1y;
      case '1m':
      default:
        return 0;
    }
  }

  /// High-conversion pitch from Section 2 & 3 of PDF
  String getSavingsPitch(String duration) {
    switch (duration.toLowerCase()) {
      case '3m':
        final s = getSavingsAmount('3m').toInt();
        return 'Save ₹$s · ~12% OFF';
      case '6m':
        final s = getSavingsAmount('6m').toInt();
        return 'Pay 5 Mos, Get 1 Mo FREE! 🎁 (Save ₹$s)';
      case '1y':
      case '12m':
        final s = getSavingsAmount('1y').toInt();
        return 'Pay 8.5 Mos, Full 1 Year! 🏆 (Save ₹$s)';
      case '1m':
      default:
        return 'Floating Seat · Standard Monthly';
    }
  }
}

class LibraryRateCard {
  /// All standard and special shifts
  static const List<LibraryShiftSlot> allSlots = [
    // ----------------- 3 HOURS -----------------
    LibraryShiftSlot(
      category: '3 Hours',
      planName: '3 Hours (Non-Peak)',
      timing: '06:00 AM - 09:00 AM',
      displayTiming: '06:00 AM - 09:00 AM (Early Morning)',
      tag: 'Non-Peak',
      fee1m: 299,
      fee3m: 799,
      fee6m: 1399,
      fee1y: 2599,
      effectiveHourly: '₹3.3 / hr',
    ),
    LibraryShiftSlot(
      category: '3 Hours',
      planName: '3 Hours (Non-Peak)',
      timing: '06:00 PM - 09:00 PM',
      displayTiming: '06:00 PM - 09:00 PM (Late Evening)',
      tag: 'Non-Peak',
      fee1m: 299,
      fee3m: 799,
      fee6m: 1399,
      fee1y: 2599,
      effectiveHourly: '₹3.3 / hr',
    ),
    LibraryShiftSlot(
      category: '3 Hours',
      planName: '3 Hours (Peak Rush)',
      timing: '12:00 PM - 03:00 PM',
      displayTiming: '12:00 PM - 03:00 PM (Afternoon Rush)',
      tag: 'Peak Rush 🔥',
      fee1m: 349,
      fee3m: 899,
      fee6m: 1699,
      fee1y: 2999,
      effectiveHourly: '₹3.9 / hr',
    ),
    LibraryShiftSlot(
      category: '3 Hours',
      planName: '3 Hours (Peak Rush)',
      timing: '03:00 PM - 06:00 PM',
      displayTiming: '03:00 PM - 06:00 PM (Evening Rush)',
      tag: 'Peak Rush 🔥',
      fee1m: 349,
      fee3m: 899,
      fee6m: 1699,
      fee1y: 2999,
      effectiveHourly: '₹3.9 / hr',
    ),

    // ----------------- 6 HOURS -----------------
    LibraryShiftSlot(
      category: '6 Hours',
      planName: '6 Hours (Morning/Evening)',
      timing: '06:00 AM - 12:00 PM',
      displayTiming: '06:00 AM - 12:00 PM (Morning Prime)',
      tag: 'Popular ⭐',
      fee1m: 499,
      fee3m: 1299,
      fee6m: 2399,
      fee1y: 4299,
      effectiveHourly: '₹2.8 / hr',
    ),
    LibraryShiftSlot(
      category: '6 Hours',
      planName: '6 Hours (Morning/Evening)',
      timing: '03:00 PM - 09:00 PM',
      displayTiming: '03:00 PM - 09:00 PM (Evening Prime)',
      tag: 'Popular ⭐',
      fee1m: 499,
      fee3m: 1299,
      fee6m: 2399,
      fee1y: 4299,
      effectiveHourly: '₹2.8 / hr',
    ),
    LibraryShiftSlot(
      category: '6 Hours',
      planName: '6 Hours (Peak Afternoon)',
      timing: '12:00 PM - 06:00 PM',
      displayTiming: '12:00 PM - 06:00 PM (High Rush Afternoon)',
      tag: 'High Rush 🔥',
      fee1m: 599,
      fee3m: 1599,
      fee6m: 2899,
      fee1y: 5199,
      effectiveHourly: '₹3.3 / hr',
    ),

    // ----------------- 8 HOURS -----------------
    LibraryShiftSlot(
      category: '8 Hours',
      planName: '8 Hours (Flexible Shift)',
      timing: 'Any 8 Hours (06:00 AM - 09:00 PM)',
      displayTiming: 'Any 8 Hours (06:00 AM - 09:00 PM)',
      tag: 'Flexible Choice',
      fee1m: 699,
      fee3m: 1799,
      fee6m: 3399,
      fee1y: 5999,
      effectiveHourly: '₹2.9 / hr',
    ),

    // ----------------- 12 HOURS -----------------
    LibraryShiftSlot(
      category: '12 Hours',
      planName: '12 Hours (Full Day)',
      timing: '06:00 AM - 06:00 PM',
      displayTiming: '06:00 AM - 06:00 PM (Full Day)',
      tag: 'Full Day',
      fee1m: 899,
      fee3m: 2399,
      fee6m: 4299,
      fee1y: 7799,
      effectiveHourly: '₹2.5 / hr',
    ),
    LibraryShiftSlot(
      category: '12 Hours',
      planName: '12 Hours (Full Day)',
      timing: '09:00 AM - 09:00 PM',
      displayTiming: '09:00 AM - 09:00 PM (Extended Day)',
      tag: 'Full Day',
      fee1m: 899,
      fee3m: 2399,
      fee6m: 4299,
      fee1y: 7799,
      effectiveHourly: '₹2.5 / hr',
    ),

    // ----------------- NIGHT SHIFT -----------------
    LibraryShiftSlot(
      category: 'Night Shift',
      planName: 'Night Shift (8 Hrs Special)',
      timing: '10:00 PM - 06:00 AM',
      displayTiming: '10:00 PM - 06:00 AM (8 Hrs Off-Peak)',
      tag: 'Budget Booster 🌙',
      fee1m: 399,
      fee3m: 1099,
      fee6m: 1899,
      fee1y: 3399,
      effectiveHourly: '₹1.7 / hr',
      branch2Only: true,
    ),
    LibraryShiftSlot(
      category: 'Night Shift',
      planName: 'Night Shift (9 Hrs Special)',
      timing: '09:00 PM - 06:00 AM',
      displayTiming: '09:00 PM - 06:00 AM (9 Hrs Off-Peak)',
      tag: 'Best Value Night 🌙',
      fee1m: 449,
      fee3m: 1199,
      fee6m: 2199,
      fee1y: 3899,
      effectiveHourly: '₹1.7 / hr',
      branch2Only: true,
    ),

    // ----------------- 24 HOURS DEDICATED -----------------
    LibraryShiftSlot(
      category: '24 Hours',
      planName: '24 Hours (Dedicated Seat)',
      timing: '24 Hours (Full Day & Night)',
      displayTiming: '24 Hours Full Day & Night (Round the clock)',
      tag: 'VIP Dedicated 👑',
      fee1m: 1299,
      fee3m: 3399,
      fee6m: 6199,
      fee1y: 11199,
      effectiveHourly: '₹1.8 / hr',
      isDedicatedSeat: true,
      branch2Only: true,
    ),
  ];

  /// Duration options for member selection
  static const List<Map<String, String>> durationOptions = [
    {
      'code': '1m',
      'label': '1 Month',
      'sub': 'Standard',
      'discount': 'Base',
      'pitch': 'Floating Seat',
    },
    {
      'code': '3m',
      'label': '3 Months',
      'sub': '~12% OFF',
      'discount': '12% OFF',
      'pitch': 'Fixed Seat + Locker 🔐',
    },
    {
      'code': '6m',
      'label': '6 Months',
      'sub': '1 Mo FREE! 🎁',
      'discount': '20% OFF',
      'pitch': '1 Mo Free · Fixed + Locker 🔐',
    },
    {
      'code': '1y',
      'label': '1 Year',
      'sub': '3.5 Mos FREE! 🏆',
      'discount': '28% OFF',
      'pitch': '3.5 Mos Free · Fixed + Locker 🔐',
    },
  ];

  /// Distinct category list
  static List<String> get categories => [
        '6 Hours',
        '3 Hours',
        '8 Hours',
        '12 Hours',
        'Night Shift',
        '24 Hours',
      ];

  /// Find slots matching a category
  static List<LibraryShiftSlot> getSlotsForCategory(String category) {
    return allSlots.where((s) => s.category == category).toList();
  }

  /// Default starting slot
  static LibraryShiftSlot get defaultSlot => allSlots[4]; // 6 Hours Morning (₹499)
}
