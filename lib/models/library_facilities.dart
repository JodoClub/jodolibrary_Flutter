import 'package:flutter/material.dart';

/// Single facility definition with metadata, category, and visual icon
class LibraryFacility {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String category;

  const LibraryFacility({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
  });
}

/// Official catalog of 24+ facilities matching 24sevenlibrary.in & modern study spaces
class LibraryFacilitiesCatalog {
  static const List<LibraryFacility> all = [
    // --- Technology & Infrastructure ---
    LibraryFacility(
      id: 'wifi',
      name: 'High-Speed 5G Wi-Fi',
      description: 'Unlimited high-speed optical fiber connectivity for online research & lectures',
      icon: Icons.wifi_rounded,
      category: 'Technology',
    ),
    LibraryFacility(
      id: 'power_backup',
      name: '100% Power Backup',
      description: 'Continuous silent generator & inverter power supply with zero disruption',
      icon: Icons.bolt_rounded,
      category: 'Technology',
    ),
    LibraryFacility(
      id: 'charging_points',
      name: 'Individual Charging Points',
      description: 'Dedicated 3-pin power socket & USB mobile charging port at every desk',
      icon: Icons.power_rounded,
      category: 'Technology',
    ),
    LibraryFacility(
      id: 'biometric',
      name: 'Biometric & QR Access',
      description: 'Automated smart entrance gate access ensuring only verified members enter',
      icon: Icons.fingerprint_rounded,
      category: 'Technology',
    ),
    LibraryFacility(
      id: 'printing',
      name: 'Printing & Photostat',
      description: 'High-speed document printing, scanning and photocopying facility',
      icon: Icons.print_rounded,
      category: 'Technology',
    ),

    // --- Comfort & Study Environment ---
    LibraryFacility(
      id: 'ac',
      name: 'Fully Air-Conditioned',
      description: 'Climate-controlled study halls maintained at optimum study temperature',
      icon: Icons.ac_unit_rounded,
      category: 'Comfort',
    ),
    LibraryFacility(
      id: 'ergonomic_chairs',
      name: 'Ergonomic Comfort Chairs',
      description: 'High-back cushioned ergonomic chairs engineered for 10-12 hours study',
      icon: Icons.chair_rounded,
      category: 'Comfort',
    ),
    LibraryFacility(
      id: 'silent_zone',
      name: 'Silent Distraction-Free Zone',
      description: 'Strict pin-drop silence policy enforced with sound-dampened partitions',
      icon: Icons.volume_off_rounded,
      category: 'Comfort',
    ),
    LibraryFacility(
      id: 'open_24_7',
      name: 'Open 24×7 & 365 Days',
      description: 'Round-the-clock library access for late night and early morning study shifts',
      icon: Icons.access_time_filled_rounded,
      category: 'Comfort',
    ),
    LibraryFacility(
      id: 'reserved_desk',
      name: 'Dedicated Reserved Desk',
      description: 'Personal fixed desk where you can leave your notes and study materials',
      icon: Icons.desk_rounded,
      category: 'Comfort',
    ),
    LibraryFacility(
      id: 'discussion_room',
      name: 'Group Discussion Room',
      description: 'Soundproof space for peer discussions, group studies and mock interviews',
      icon: Icons.groups_rounded,
      category: 'Comfort',
    ),
    LibraryFacility(
      id: 'girls_section',
      name: 'Dedicated Girls Study Zone',
      description: 'Comfortable dedicated study floor and partitioned zone for female students',
      icon: Icons.shield_rounded,
      category: 'Comfort',
    ),

    // --- Utilities, Storage & Refreshment ---
    LibraryFacility(
      id: 'ro_water',
      name: 'RO Purified Drinking Water',
      description: 'Multi-stage RO filtered mineral water with Hot, Cold & Normal dispensers',
      icon: Icons.water_drop_rounded,
      category: 'Utilities',
    ),
    LibraryFacility(
      id: 'lockers',
      name: 'Smart Personal Lockers',
      description: 'Secure lockable personal lockers for storing heavy books and laptops safely',
      icon: Icons.lock_rounded,
      category: 'Utilities',
    ),
    LibraryFacility(
      id: 'dining_area',
      name: 'Separate Dining & Cafeteria',
      description: 'Hygienic separate lunch room equipped with microwave and wash basin',
      icon: Icons.restaurant_rounded,
      category: 'Utilities',
    ),
    LibraryFacility(
      id: 'tea_coffee',
      name: 'Tea & Coffee Vending Machine',
      description: 'Instant refreshment bar with hot tea, coffee, soup and healthy snacks',
      icon: Icons.coffee_rounded,
      category: 'Utilities',
    ),
    LibraryFacility(
      id: 'washrooms',
      name: 'Clean & Sanitized Washrooms',
      description: 'Regularly sanitized, well-ventilated separate washrooms for male and female',
      icon: Icons.wc_rounded,
      category: 'Utilities',
    ),
    LibraryFacility(
      id: 'phone_booth',
      name: 'Soundproof Phone Booth',
      description: 'Acoustic private phone cabin for urgent calls without disturbing the hall',
      icon: Icons.phone_in_talk_rounded,
      category: 'Utilities',
    ),

    // --- Learning Resources & Parking & Safety ---
    LibraryFacility(
      id: 'newspapers',
      name: 'Daily Newspapers & Magazines',
      description: 'Daily Hindi & English leading newspapers (The Hindu, Indian Express, Dainik Jagran)',
      icon: Icons.menu_book_rounded,
      category: 'Resources',
    ),
    LibraryFacility(
      id: 'book_bank',
      name: 'Reference Book Bank',
      description: 'Curated competitive examination books, NCERTs and standard reference materials',
      icon: Icons.auto_stories_rounded,
      category: 'Resources',
    ),
    LibraryFacility(
      id: 'two_wheeler_parking',
      name: '2-Wheeler Parking Space',
      description: 'CCTV-monitored safe on-premises parking for motorcycles, scooters & cycles',
      icon: Icons.two_wheeler_rounded,
      category: 'Parking',
    ),
    LibraryFacility(
      id: 'four_wheeler_parking',
      name: '4-Wheeler Car Parking',
      description: 'Designated parking spots for four-wheelers and cabs nearby',
      icon: Icons.directions_car_rounded,
      category: 'Parking',
    ),
    LibraryFacility(
      id: 'cctv',
      name: '24×7 CCTV Surveillance',
      description: 'High-definition security cameras with night vision covering all corners',
      icon: Icons.videocam_rounded,
      category: 'Safety',
    ),
    LibraryFacility(
      id: 'fire_safety',
      name: 'Fire Safety & First Aid',
      description: 'Equipped with certified fire extinguishers, smoke alarms and complete first-aid kit',
      icon: Icons.local_fire_department_rounded,
      category: 'Safety',
    ),
  ];

  static LibraryFacility? findById(String id) {
    try {
      return all.firstWhere((f) => f.id.toLowerCase() == id.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  static String getName(String id) {
    final f = findById(id);
    if (f != null) return f.name;
    // Fallback: capitalize id
    return id.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  static IconData getIcon(String id) {
    final f = findById(id);
    return f?.icon ?? Icons.check_circle_outline_rounded;
  }
}
