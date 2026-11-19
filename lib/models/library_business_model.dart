import '../services/api_config.dart';

/// Complete Google Business Style Profile Model for Libraries
class LibraryBusinessModel {
  final String id;
  final String name;
  final String? branchName;
  final String address;
  final String? area;
  final String city;
  final int totalSeats;
  final double rating;
  final double monthlyPrice;
  final List<String> photos;
  final String? googleMapsUrl;
  final String timing;
  final String operatingDays;
  final String? contactPhone;
  final String? contactEmail;
  final String? websiteUrl;
  final String? whatsappNumber;
  final String? instagramUrl;
  final String? facebookUrl;
  final String? youtubeUrl;
  final List<String> amenities;
  final String? ownerName;
  final String? ownerUserId;
  final String? qrPayload;

  const LibraryBusinessModel({
    required this.id,
    required this.name,
    this.branchName,
    required this.address,
    this.area,
    required this.city,
    required this.totalSeats,
    this.rating = 4.9,
    this.monthlyPrice = 1499.0,
    this.photos = const [],
    this.googleMapsUrl,
    this.timing = '24 Hours Open (24×7)',
    this.operatingDays = 'Mon - Sun (All 7 Days Open)',
    this.contactPhone,
    this.contactEmail,
    this.websiteUrl,
    this.whatsappNumber,
    this.instagramUrl,
    this.facebookUrl,
    this.youtubeUrl,
    this.amenities = const [],
    this.ownerName,
    this.ownerUserId,
    this.qrPayload,
  });

  LibraryBusinessModel copyWith({
    String? id,
    String? name,
    String? branchName,
    String? address,
    String? area,
    String? city,
    int? totalSeats,
    double? rating,
    double? monthlyPrice,
    List<String>? photos,
    String? googleMapsUrl,
    String? timing,
    String? operatingDays,
    String? contactPhone,
    String? contactEmail,
    String? websiteUrl,
    String? whatsappNumber,
    String? instagramUrl,
    String? facebookUrl,
    String? youtubeUrl,
    List<String>? amenities,
    String? ownerName,
    String? ownerUserId,
    String? qrPayload,
  }) {
    return LibraryBusinessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      branchName: branchName ?? this.branchName,
      address: address ?? this.address,
      area: area ?? this.area,
      city: city ?? this.city,
      totalSeats: totalSeats ?? this.totalSeats,
      rating: rating ?? this.rating,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      photos: photos ?? this.photos,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      timing: timing ?? this.timing,
      operatingDays: operatingDays ?? this.operatingDays,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      amenities: amenities ?? this.amenities,
      ownerName: ownerName ?? this.ownerName,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      qrPayload: qrPayload ?? this.qrPayload,
    );
  }

  String get displayName {
    if (branchName != null && branchName!.trim().isNotEmpty) {
      return '$name - ${branchName!.trim()}';
    }
    return name;
  }

  factory LibraryBusinessModel.fromJson(Map<String, dynamic> json) {
    // 1. Unwrap nested payload if wrapped in 'library' or 'data'
    final map = (json['library'] is Map<String, dynamic>)
        ? json['library'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : json;

    String resolvePhotoUrl(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      if (trimmed.startsWith('/')) {
        final host = ApiConfig.baseUrl.replaceAll('/api/v1', '');
        return '$host$trimmed';
      }
      return trimmed;
    }

    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    // Parse photos list and resolve relative upload URLs
    List<String> photosList = parseStringList(map['photos'])
        .map(resolvePhotoUrl)
        .where((u) => u.isNotEmpty)
        .toList();

    if (photosList.isEmpty && map['photoUrl'] != null && map['photoUrl'].toString().trim().isNotEmpty) {
      final resolvedSingle = resolvePhotoUrl(map['photoUrl'].toString().trim());
      if (resolvedSingle.isNotEmpty) {
        photosList.add(resolvedSingle);
      }
    }

    final double price = (map['monthlyPrice'] is num)
        ? (map['monthlyPrice'] as num).toDouble()
        : double.tryParse(map['monthlyPrice']?.toString() ?? '') ?? 1499.0;

    final double rat = (map['rating'] is num)
        ? (map['rating'] as num).toDouble()
        : double.tryParse(map['rating']?.toString() ?? '') ?? 4.9;

    final int seats = (map['totalSeats'] is int)
        ? map['totalSeats'] as int
        : int.tryParse(map['totalSeats']?.toString() ?? '') ?? 60;

    return LibraryBusinessModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Study Hub Library',
      branchName: map['branchName']?.toString(),
      address: map['address']?.toString() ?? 'Boring Road, Patna',
      area: map['area']?.toString() ?? 'Boring Road',
      city: map['city']?.toString() ?? 'Patna',
      totalSeats: seats,
      rating: rat,
      monthlyPrice: price,
      photos: photosList,
      googleMapsUrl: map['googleMapsUrl']?.toString() ?? map['mapsUrl']?.toString(),
      timing: map['timing']?.toString() ?? '24 Hours Open (24×7)',
      operatingDays: map['operatingDays']?.toString() ?? 'Mon - Sun (All 7 Days Open)',
      contactPhone: map['contactPhone']?.toString() ?? map['phone']?.toString(),
      contactEmail: map['contactEmail']?.toString() ?? map['email']?.toString(),
      websiteUrl: map['websiteUrl']?.toString(),
      whatsappNumber: map['whatsappNumber']?.toString(),
      instagramUrl: map['instagramUrl']?.toString(),
      facebookUrl: map['facebookUrl']?.toString(),
      youtubeUrl: map['youtubeUrl']?.toString(),
      amenities: parseStringList(map['amenities']),
      ownerName: map['ownerName']?.toString(),
      ownerUserId: map['ownerUserId']?.toString(),
      qrPayload: map['qrPayload']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'branchName': branchName,
      'address': address,
      'area': area,
      'city': city,
      'totalSeats': totalSeats,
      'rating': rating,
      'monthlyPrice': monthlyPrice,
      'photos': photos,
      'googleMapsUrl': googleMapsUrl,
      'timing': timing,
      'operatingDays': operatingDays,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'websiteUrl': websiteUrl,
      'whatsappNumber': whatsappNumber,
      'instagramUrl': instagramUrl,
      'facebookUrl': facebookUrl,
      'youtubeUrl': youtubeUrl,
      'amenities': amenities,
      'ownerName': ownerName,
      'ownerUserId': ownerUserId,
      'qrPayload': qrPayload,
    };
  }
}
