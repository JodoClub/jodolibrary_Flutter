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

  String get displayName {
    if (branchName != null && branchName!.trim().isNotEmpty) {
      return '$name - ${branchName!.trim()}';
    }
    return name;
  }

  factory LibraryBusinessModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    // Default high-quality library photos if photos array is empty
    List<String> photosList = parseStringList(json['photos']);
    if (photosList.isEmpty && json['photoUrl'] != null && json['photoUrl'].toString().isNotEmpty) {
      photosList.add(json['photoUrl'].toString());
    }
    if (photosList.isEmpty) {
      photosList = [
        'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1568667256549-094345857637?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?auto=format&fit=crop&w=1200&q=80',
      ];
    }

    final double price = (json['monthlyPrice'] is num)
        ? (json['monthlyPrice'] as num).toDouble()
        : double.tryParse(json['monthlyPrice']?.toString() ?? '') ?? 1499.0;

    final double rat = (json['rating'] is num)
        ? (json['rating'] as num).toDouble()
        : double.tryParse(json['rating']?.toString() ?? '') ?? 4.9;

    final int seats = (json['totalSeats'] is int)
        ? json['totalSeats'] as int
        : int.tryParse(json['totalSeats']?.toString() ?? '') ?? 60;

    return LibraryBusinessModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Study Hub Library',
      branchName: json['branchName']?.toString(),
      address: json['address']?.toString() ?? 'Boring Road, Patna',
      area: json['area']?.toString() ?? 'Boring Road',
      city: json['city']?.toString() ?? 'Patna',
      totalSeats: seats,
      rating: rat,
      monthlyPrice: price,
      photos: photosList,
      googleMapsUrl: json['googleMapsUrl']?.toString() ?? json['mapsUrl']?.toString(),
      timing: json['timing']?.toString() ?? '24 Hours Open (24×7)',
      operatingDays: json['operatingDays']?.toString() ?? 'Mon - Sun (All 7 Days Open)',
      contactPhone: json['contactPhone']?.toString() ?? json['phone']?.toString(),
      contactEmail: json['contactEmail']?.toString() ?? json['email']?.toString(),
      websiteUrl: json['websiteUrl']?.toString(),
      whatsappNumber: json['whatsappNumber']?.toString(),
      instagramUrl: json['instagramUrl']?.toString(),
      facebookUrl: json['facebookUrl']?.toString(),
      youtubeUrl: json['youtubeUrl']?.toString(),
      amenities: parseStringList(json['amenities']),
      ownerName: json['ownerName']?.toString(),
      ownerUserId: json['ownerUserId']?.toString(),
      qrPayload: json['qrPayload']?.toString(),
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
