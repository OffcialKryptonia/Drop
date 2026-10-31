import '../manage_imports.dart';

class CarDetailWidget extends StatefulWidget {
  final ServicesListData service;
  final String tripType;

  CarDetailWidget({required this.service, required this.tripType});

  @override
  CarDetailWidgetState createState() => CarDetailWidgetState();
}

class CarDetailWidgetState extends State<CarDetailWidget> {
  double locationDistance = 0.0;
  double fareDistance = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.service.distanceUnit == DISTANCE_TYPE_KM) {
      locationDistance = widget.service.dropoffDistanceInKm!.toDouble();
    } else {
      locationDistance = widget.service.dropoffDistanceInKm!.toDouble() * 0.621371;
    }
    locationDistance = double.parse(locationDistance.toStringAsFixed(digitAfterDecimal));

    double distance = double.parse(
      widget.service.dropoffDistanceInKm!.toStringAsFixed(digitAfterDecimal),
    );

    fareDistance = distance - widget.service.minimumDistance!.toDouble();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              alignment: Alignment.center,
              height: 5,
              width: 70,
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
            ),
          ),
          SizedBox(height: 12),
          Center(child: Text(widget.service.name.validate(), style: boldTextStyle(size: 20))),
          SizedBox(height: 8),
          Text(language.fareBreakdown, style: boldTextStyle(size: 20)),
          SizedBox(height: 8),
          if (widget.tripType == tripTypeZoneWise) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(language.fixedPrice, style: primaryTextStyle()), printAmountWidget(amount: '${widget.service.subtotal!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal)],
            ),
            if (widget.service.surgeAmount != null && widget.service.surgeAmount! > 0) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(language.highDemandCharge, style: primaryTextStyle(color: Colors.red)), printAmountWidgetForEstimate(amount: '${widget.service.surgeAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.red, sign: "+")],
              ),
            ],
            if (widget.service.discountAmount != null && widget.service.discountAmount! > 0) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(language.couponDiscount, style: primaryTextStyle(color: Colors.green)), printAmountWidgetForEstimate(amount: '${widget.service.discountAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.green, sign: "-")],
              ),
              SizedBox(height: 8),
            ],
            if (widget.service.coinsUsed != null && widget.service.coinsUsed! > 0) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('Coins', style: primaryTextStyle(color: Colors.green)), printAmountWidgetForEstimate(amount: '${widget.service.coinsUsed!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.green, sign: "-")],
              ),
              SizedBox(height: 8),
            ],
            Divider(),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(language.totalFare, style: boldTextStyle(size: 24)), printAmountWidget(amount: '${widget.service.totalAmountAfterDiscount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.bold, size: 24)],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(language.baseFare, style: primaryTextStyle()), printAmountWidget(amount: '${widget.service.baseFare!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal)],
            ),
            if (widget.service.distancePrice != null && widget.service.distancePrice! > 0) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        widget.service.distancePrice! == 0 ? language.distanceFare : '${language.distanceFare} ( ${fareDistance.toStringAsFixed(2)} * ${widget.service.perDistance} )',
                        style: primaryTextStyle(),
                      )
                    ],
                  ),
                  printAmountWidgetForEstimate(amount: '${widget.service.distancePrice!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, sign: "+")
                ],
              ),
            ],
            if ((widget.service.perMinuteDrive ?? 0) > 0 || (widget.service.surgeAmount ?? 0) > 0) ...[
              if (widget.service.timePrice != null && widget.service.timePrice! > 0) ...[
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(language.extraRideTime, style: primaryTextStyle()), printAmountWidgetForEstimate(amount: '${widget.service.timePrice!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, sign: "+")],
                ),
              ],
              SizedBox(height: 8),
            ],
            Divider(),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(language.subTotal, style: boldTextStyle()), printAmountWidget(amount: '${widget.service.subtotal!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.bold)],
            ),
            SizedBox(height: 8),
            if (widget.service.surgeAmount != null && widget.service.surgeAmount! > 0) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(language.highDemandCharge, style: primaryTextStyle(color: Colors.red)), printAmountWidgetForEstimate(amount: '${widget.service.surgeAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.red, sign: "+")],
              ),
            ],
            if (widget.service.coinsUsed != null && widget.service.coinsUsed! > 0) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('Coins', style: primaryTextStyle(color: Colors.green)), printAmountWidgetForEstimate(amount: '${widget.service.coinsUsed!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.green, sign: "-")],
              ),
              SizedBox(height: 8),
            ],
            if (widget.service.discountAmount != null && widget.service.discountAmount! > 0) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(language.couponDiscount, style: primaryTextStyle(color: Colors.green)), printAmountWidgetForEstimate(amount: '${widget.service.discountAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.green, sign: "-")],
              ),
              SizedBox(height: 8),
            ],
            Divider(),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(language.totalFare, style: boldTextStyle(size: 24)), printAmountWidget(amount: '${widget.service.totalAmountAfterDiscount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.bold, size: 24)],
            ),
          ],
          SizedBox(height: 8),
          Text(widget.service.description.validate(), style: secondaryTextStyle(), textAlign: TextAlign.justify),
          SizedBox(height: 8),
          AppButtonWidget(
            text: language.close,
            width: MediaQuery.of(context).size.width,
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
