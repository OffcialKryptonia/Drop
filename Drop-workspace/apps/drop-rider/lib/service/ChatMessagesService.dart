import '../manage_imports.dart';

class ChatMessageService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;

  // late CollectionReference userRef;
  late CollectionReference rideChatRef;

  // FirebaseStorage _storage = FirebaseStorage.instance;

  ChatMessageService() {
    ref = fireStore.collection(MESSAGES_COLLECTION);
    // userRef = fireStore.collection(USER_COLLECTION);
    rideChatRef = fireStore.collection(RIDE_CHAT);
  }

  Query chatMessagesWithPagination({String? riderId, required String driverID, required int filter_msg}) {
    // ref!.doc('${currentUserId}_${receiverUserId}');
    return ref!.doc("${riderId}_${driverID}").collection("chats").orderBy("createdAt", descending: true);
    // return ref!.doc(currentUserId).collection(receiverUserId).orderBy("createdAt", descending: true);
    // return ref!.doc(currentUserId).collection(receiverUserId).orderBy("createdAt", descending: true);
  }

  Query rideSpecificChatMessagesWithPagination({required String rideId}) {
    return rideChatRef.doc(rideId).collection("messages").orderBy("createdAt", descending: true);
  }

  Future<bool> isRideChatHistory({required String rideId}) async {
    QuerySnapshot<Map<String, dynamic>> b = await rideChatRef.doc(rideId).collection("messages").get();
    if (b.docs.isEmpty) {
      return false;
    }
    return true;
  }

  Future<DocumentReference> addMessage(ChatMessageModel data) async {
    var doc2 = await ref!.doc("${data.senderId}_${data.receiverId}").collection("chats").add(data.toJson());
    doc2.update({'id': doc2.id});
    return doc2;
  }

  Future<void> deleteSingleMessage({String? riderID, required String driverID, String? documentId}) async {
    try {
      // ref!.doc("${riderID}_${driverID}").collection("chats").doc(documentId).delete();
      final chatDocRef = ref!.doc("${riderID}_${driverID}").collection("chats").doc(documentId);
      await chatDocRef.update({'deleted': true});
    } on Exception catch (e) {
      log(e.toString());
      throw 'Something went wrong';
    }
  }

  Future<void> setUnReadStatusToTrue({required String riderID, required String driverID, String? documentId}) async {
    ref!.doc("${riderID}_${driverID}").collection("chats").where('senderId', isNotEqualTo: riderID).get().then((value) {
      value.docs.forEach((element) {
        element.reference.update({
          'isMessageRead': true,
        });
      });
    });

    return;
    // ref!.doc(senderId).collection(receiverId).where('senderId', isNotEqualTo: senderId).get().then((value) {
    //   value.docs.forEach((element) {
    //     element.reference.update({
    //       'isMessageRead': true,
    //     });
    //   });
    // });
    //
    // ref!.doc(receiverId).collection(senderId).where('senderId', isNotEqualTo: senderId).get().then((value) {
    //   value.docs.forEach((element) {
    //     element.reference.update({
    //       'isMessageRead': true,
    //     });
    //   });
    // });
  }

  Future<bool> justDeleteChat({
    required String senderId,
    required String receiverId,
  }) async {
    print("Check CHAT ROOM Id:::${senderId}_${receiverId}");
    try {
      var documentPath = "${senderId}_${receiverId}";
      CollectionReference collectionRef = ref!.doc(documentPath).collection("chats");
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

  // Future<bool> exportChat({required String rideId, required String senderId, required String receiverId, bool? onlyDelete}) async {
  //   // chat export process
  //   // if (onlyDelete != true) {
  //   //   try {
  //   //     // QuerySnapshot<Map<String, dynamic>> b = await ref!.doc("$receiverId").collection("$senderId").get();
  //   //     QuerySnapshot<Map<String, dynamic>> b = await ref!.doc("${senderId}_${receiverId}").collection("chats").get();
  //   //     b.docs.forEach(
  //   //           (element) async {
  //   //         await rideChatRef.doc(rideId).collection("messages").add(element.data());
  //   //       },
  //   //     );
  //   //   } catch (e, s) {
  //   //     // FirebaseCrashlytics.instance.recordError("Export_Chat_Failed::" + e.toString(), s, fatal: true);
  //   //   }
  //   // }
  //   // remove chat process
  //   try {
  //     // await ref!.doc("${senderId}_${receiverId}").delete();
  //     // QuerySnapshot<Map<String, dynamic>> a = await ref!.doc("$senderId").collection("$receiverId").get();
  //     // QuerySnapshot<Map<String, dynamic>> c = await ref!.doc("$receiverId").collection("$senderId").get();
  //     // a.docs.forEach(
  //     //   (element1) async {
  //     //     await element1.reference.delete();
  //     //   },
  //     // );
  //     // c.docs.forEach(
  //     //   (element1) async {
  //     //     await element1.reference.delete();
  //     //   },
  //     // );
  //   } catch (e, s) {
  //     FirebaseCrashlytics.instance.recordError("Remove_Chat_Failed::" + e.toString(), s, fatal: true);
  //   }
  //   return true;
  // }

  Stream<int> getUnReadCount({String? senderId, required String receiverId, String? documentId}) {
    return ref!
        .doc("${senderId}_${receiverId}")
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
