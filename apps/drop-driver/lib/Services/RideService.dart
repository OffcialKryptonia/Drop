import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taxi_driver/model/FRideBookingModel.dart';
import 'package:taxi_driver/utils/Extensions/app_common.dart';

import '../utils/Constants.dart';
import 'BaseServices.dart';

class RideService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;
  late CollectionReference rideRef;

  RideService() {
    rideRef = fireStore.collection(RIDE_COLLECTION);
  }

  Stream<QuerySnapshot> fetchRide({int? userId}) {
    return rideRef.where('driver_ids', arrayContains: userId).snapshots();
  }

  Future<bool> removeOldRideEntry({int? userId}) async {
    try {
      QuerySnapshot<Object?> b =
          await rideRef.where('driver_id', isEqualTo: userId).get();
      List<FRideBookingModel> x = b.docs
          .map((e) =>
              FRideBookingModel.fromJson(e.data() as Map<String, dynamic>))
          .toList();
      FRideBookingModel y = x
          .where(
            (element) =>
                element.status == COMPLETED || element.status == CANCELED,
          )
          .first;
      await rideRef.doc("ride_${y.rideId}").delete();
      return true;
    } catch (e) {
      log(e);
      return false;
    }
  }

  Future<List<FRideBookingModel>> fetchRideData({int? userId}) {
    return rideRef.where('driver_id', isEqualTo: userId).get().then((value) {
      return value.docs
          .map((e) =>
              FRideBookingModel.fromJson(e.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> updateStatusOfRide({int? rideID, req}) {
    log(' status updated $rideID');
    return rideRef
        .doc("ride_$rideID")
        .update(req)
        .then((value) {})
        .catchError((e) {
      log('Error status update $e');
    });
  }
}
