class EdgeItem {
  final int start, end;

  EdgeItem({this.start, this.end});

  factory EdgeItem.fromJson(Map<String, dynamic> json) {
    return EdgeItem(
        start: json['start'] as int,
        end: json['end'] as int
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['start'] = start;
    data['end'] = end;
    return data;
  }
}