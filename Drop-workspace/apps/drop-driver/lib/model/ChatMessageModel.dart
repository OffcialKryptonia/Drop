class ChatMessageModel {
  String? id;
  String? senderId;
  String? receiverId;
  String? photoUrl;
  String? messageType;
  bool? isMe;
  bool? isMessageRead;
  String? message;
  String? msg_topic;
  bool? deleted;
  int? createdAt;

  ChatMessageModel(
      {this.id,
      this.deleted,
      this.senderId,
      this.msg_topic,
      this.receiverId,
      this.createdAt,
      this.message,
      this.isMessageRead,
      this.photoUrl,
      this.messageType});

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      deleted: json['deleted'],
      senderId: json['senderId'],
      msg_topic: json['msg_topic'],
      receiverId: json['receiverId'],
      message: json['message'],
      isMessageRead: json['isMessageRead'],
      photoUrl: json['photoUrl'],
      messageType: json['messageType'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['deleted'] = this.deleted;
    data['createdAt'] = this.createdAt;
    data['msg_topic'] = this.msg_topic;
    data['message'] = this.message;
    data['senderId'] = this.senderId;
    data['isMessageRead'] = this.isMessageRead;
    data['receiverId'] = this.receiverId;
    data['photoUrl'] = this.photoUrl;
    data['messageType'] = this.messageType;
    return data;
  }
}
