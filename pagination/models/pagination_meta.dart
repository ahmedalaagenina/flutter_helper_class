class PaginationMeta {
  final int currentPage;
  final int? from;
  final int lastPage;
  final String path;
  final int perPage;
  final int? to;
  final int total;

  PaginationMeta({
    required this.currentPage,
    required this.from,
    required this.lastPage,
    required this.path,
    required this.perPage,
    required this.to,
    required this.total,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'],
      from: json['from'],
      lastPage: json['last_page'],
      path: json['path'],
      perPage: json['per_page'],
      to: json['to'],
      total: json['total'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'from': from,
      'last_page': lastPage,
      'path': path,
      'per_page': perPage,
      'to': to,
      'total': total,
    };
  }
}
