import '../manage_imports.dart';

class ModelFAQ {
  PaginationModel? pagination;
  List<FaqItem>? data;

  ModelFAQ({this.pagination, this.data});

  ModelFAQ.fromJson(Map<String, dynamic> json) {
    pagination = json['pagination'] != null
        ? new PaginationModel.fromJson(json['pagination'])
        : null;
    if (json['data'] != null) {
      data = <FaqItem>[];
      json['data'].forEach((v) {
        data!.add(new FaqItem.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.pagination != null) {
      data['pagination'] = this.pagination!.toJson();
    }
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class FaqItem {
  int? id;
  String? question;
  String? answer;
  String? createdAt;
  String? updatedAt;

  FaqItem(
      {this.id, this.question, this.answer, this.createdAt, this.updatedAt});

  FaqItem.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    question = json['question'];
    answer = json['answer'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['question'] = this.question;
    data['answer'] = this.answer;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}
