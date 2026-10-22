// Data models for Apiaries, Hive Boxes, and Frames.

class ApiaryModel {
  final String source;
  final String id;
  final String userId;
  final String locationName;
  final String areaAddress;
  final String? gpsLocation;
  final int totalHives;
  final int totalFrames;
  final String status;
  final String createdAt;

  const ApiaryModel({
    this.source = 'live',
    required this.id,
    required this.userId,
    required this.locationName,
    required this.areaAddress,
    this.gpsLocation,
    this.totalHives = 0,
    this.totalFrames = 0,
    this.status = 'Active',
    required this.createdAt,
  });

  factory ApiaryModel.fromJson(Map<String, dynamic> json) {
    return ApiaryModel(
      source: json['_data_source'] as String? ?? 'live',
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      locationName: json['location_name'] as String? ?? '',
      areaAddress: json['area_address'] as String? ?? '',
      gpsLocation: json['gps_location'] as String?,
      totalHives: (json['total_hives'] as num?)?.toInt() ?? 0,
      totalFrames: (json['total_frames'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Active',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_data_source': source,
    'id': id,
    'user_id': userId,
    'location_name': locationName,
    'area_address': areaAddress,
    'gps_location': gpsLocation,
    'total_hives': totalHives,
    'total_frames': totalFrames,
    'status': status,
    'created_at': createdAt,
  };
}

class HiveModel {
  final String source;
  final String id;
  final String userId;
  final String apiaryId;
  final String name;
  final int boxNumber;
  final String hiveType;
  final String beeSpecies;
  final int numFrames;
  final String status;
  final String? installationDate;
  final String createdAt;

  const HiveModel({
    this.source = 'live',
    required this.id,
    required this.userId,
    required this.apiaryId,
    required this.name,
    required this.boxNumber,
    this.hiveType = 'Langstroth',
    this.beeSpecies = 'Apis mellifera',
    required this.numFrames,
    this.status = 'Healthy',
    this.installationDate,
    required this.createdAt,
  });

  factory HiveModel.fromJson(Map<String, dynamic> json) {
    return HiveModel(
      source: json['_data_source'] as String? ?? 'live',
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      apiaryId: json['apiary_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      boxNumber: (json['box_number'] as num?)?.toInt() ?? 0,
      hiveType: json['hive_type'] as String? ?? 'Langstroth',
      beeSpecies: json['bee_species'] as String? ?? 'Apis mellifera',
      numFrames: (json['num_frames'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Healthy',
      installationDate: json['installation_date'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_data_source': source,
    'id': id,
    'user_id': userId,
    'apiary_id': apiaryId,
    'name': name,
    'box_number': boxNumber,
    'hive_type': hiveType,
    'bee_species': beeSpecies,
    'num_frames': numFrames,
    'status': status,
    'installation_date': installationDate,
    'created_at': createdAt,
  };
}
