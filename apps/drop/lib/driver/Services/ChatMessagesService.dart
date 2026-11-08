import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/ChatMessageModel.dart';
import '../utils/Constants.dart';
import 'BaseServices.dart';

class ChatMessageService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;
  late CollectionReference userRef;
  late CollectionReference rideChatRef;

  // FirebaseStorage _storage = FirebaseStorage.instance;

  ChatMessageService() {
    ref = fireStore.collection(MESSAGES_COLLECTION);
    userRef = fireStore.collection(USER_COLLECTION);
    rideChatRef = fireStore.collection(RIDE_CHAT);
  }

  Query chatMessagesWithPagination({
    String? driverID,
    required String riderID,
  }) {
    return ref!
        .doc("${riderID}_${driverID}")
        .collection("chats")
        .orderBy("createdAt", descending: true);
    // return ref!.doc(currentUserId).collection(receiverUserId).orderBy("createdAt", descending: true);
  }

  Query rideSpecificChatMessagesWithPagination({required String rideId}) {
    return rideChatRef
        .doc(rideId)
        .collection("messages")
        .orderBy("createdAt", descending: true);
  }

  Future<bool> isRideChatHistory({required String rideId}) async {
    QuerySnapshot<Map<String, dynamic>> b =
        await rideChatRef.doc(rideId).collection("messages").get();
    if (b.docs.isEmpty) {
      return false;
    }
    return true;
  }

  Future<DocumentReference> addMessage(ChatMessageModel data) async {
    var doc2 = await ref!
        .doc("${data.receiverId}_${data.senderId}")
        .collection("chats")
        .add(data.toJson());
    doc2.update({'id': doc2.id});
    return doc2;
  }

  Future<bool> exportChat(
      {required String rideId,
      required String senderId,
      required String receiverId,
      bool? onlyDelete}) async {
    // chat export process
    if (onlyDelete != true) {
      try {
        QuerySnapshot<Map<String, dynamic>> b = await ref!
            .doc("${receiverId}_${senderId}")
            .collection("chats")
            .get();
        b.docs.forEach(
          (element) async {
            await rideChatRef
                .doc(rideId)
                .collection("messages")
                .add(element.data());
          },
        );
      } catch (e, s) {
        print("FailExportChats Operation::$e ::::$s");
      }
    }
    await justDeleteChat(senderId: senderId, receiverId: receiverId);
    return true;
  }

  Future<bool> justDeleteChat({
    required String senderId,
    required String receiverId,
  }) async {
    print("Check CHAT ROOM Id:::${receiverId}_${senderId}");
    try {
      var documentPath = "${receiverId}_${senderId}";
      CollectionReference collectionRef =
          ref!.doc(documentPath).collection("chats");
      QuerySnapshot querySnapshot = await collectionRef.get();
      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      await ref!.doc(documentPath).delete();
      return true;
    } catch (e, s) {
      print("FailDelete Operation::$e ::::$s");
      return false;
    }
  }

  Future<void> deleteSingleMessage(
      {String? senderId,
      required String receiverId,
      String? documentId}) async {
    try {
      // Delete For All
      // await ref!.doc("${receiverId}_${senderId}").collection("chats").doc(documentId).delete();
      // Delete For Specific User
      final chatDocRef = ref!
          .doc("${receiverId}_${senderId}")
          .collection("chats")
          .doc(documentId);
      await chatDocRef.update({'deleted': true});
    } on Exception catch (e) {
      log(e.toString());
      throw 'Something went wrong';
    }
  }

  Future<void> setUnReadStatusToTrue(
      {required String senderId,
      required String receiverId,
      String? documentId}) async {
    print("CheckCase::${senderId}_${receiverId}");
    ref!
        .doc("${receiverId}_${senderId}")
        .collection("chats")
        .where('senderId', isNotEqualTo: senderId)
        .get()
        .then((value) {
      value.docs.forEach((element) {
        element.reference.update({
          'isMessageRead': true,
        });
      });
    });
    return;
  }

  Stream<int> getUnReadCount(
      {String? senderId, required String receiverId, String? documentId}) {
    return ref!
        .doc("${receiverId}_${senderId}")
        .collection("chats")
        .where('isMessageRead', isEqualTo: false)
        .where('receiverId', isEqualTo: senderId)
        .snapshots()
        .map(
          (event) => event.docs.length,
        )
        .handleError((e) {
      return e;
    });
  }
}
