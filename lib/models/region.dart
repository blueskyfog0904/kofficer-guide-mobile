class Region {
  final String id;
  final String name; // sub_add1 (e.g., 서울특별시)
  final String subName; // sub_add2 (e.g., 강남구)

  Region({
    required this.id,
    required this.name,
    required this.subName,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] ?? '',
      name: json['sub_add1'] ?? '',
      subName: json['sub_add2'] ?? '',
    );
  }

  // 이전 호환성을 위한 fromStats (v_region_stats 뷰용)
  factory Region.fromStats(Map<String, dynamic> json) {
    return Region(
      id: json['id'] ?? json['region_id'] ?? '',
      name: json['sub_add1'] ?? json['region'] ?? '',
      subName: json['sub_add2'] ?? json['sub_region'] ?? '',
    );
  }
}

