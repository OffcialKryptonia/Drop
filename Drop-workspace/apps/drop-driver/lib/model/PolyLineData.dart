class PolyLineData {
  bool? status;
  String? polyline;

  PolyLineData({this.status, this.polyline});

  PolyLineData.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    polyline = json['polyline'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['polyline'] = this.polyline;
    return data;
  }
}
