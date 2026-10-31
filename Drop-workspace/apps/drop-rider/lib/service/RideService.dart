import '../manage_imports.dart';

class RideService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;
  late CollectionReference rideRef;

  RideService() {
    rideRef = fireStore.collection(RIDE_COLLECTION);
  }

  Future addRide(FRideBookingModel rideBookingModel, int? rideID) {
    return rideRef.doc("ride_$rideID").set(rideBookingModel.toJson()).then((value) {}).catchError((e) {
      log('===error $e');
    });
  }

  Stream<QuerySnapshot> fetchRide({int? rideId}) {
    return rideRef.where('ride_id', isEqualTo: rideId).snapshots();
  }

  Future<QuerySnapshot<Object?>> checkIsRideExist({required int rideId}) async {
    return await rideRef.where('ride_id', isEqualTo: rideId).get();
  }

  Future<List<FRideBookingModel>> fetchRideFuture({int? rideId}) {
    return rideRef.where('ride_id', isEqualTo: rideId).get().then((value) {
      return value.docs.map((e) => FRideBookingModel.fromJson(e.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> updateStatusOfRide({int? rideID, req}) {
    return rideRef.doc("ride_$rideID").update(req).then((value) {
      log(' status updated');
    }).catchError((e) {
      log('Error status update $e');
    });
  }
}
