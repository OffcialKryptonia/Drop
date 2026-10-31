import 'package:flutter/material.dart';

import 'LanguageDataConstant.dart';

class BaseLanguage {
  static BaseLanguage? of(BuildContext context) => Localizations.of<BaseLanguage>(context, BaseLanguage);

  String get appName => getContentValueFromKey(1);

  String get thisFieldRequired => getContentValueFromKey(2);

  String get email => getContentValueFromKey(3);

  String get password => getContentValueFromKey(4);

  String get forgotPassword => getContentValueFromKey(5);

  String get logIn => getContentValueFromKey(6);

  String get orLogInWith => getContentValueFromKey(7);

  String get donHaveAnAccount => getContentValueFromKey(8);

  String get signUp => getContentValueFromKey(9);

  String get firstName => getContentValueFromKey(11);

  String get lastName => getContentValueFromKey(12);

  String get userName => getContentValueFromKey(13);

  String get phoneNumber => getContentValueFromKey(14);

  String get changePassword => getContentValueFromKey(16);

  String get oldPassword => getContentValueFromKey(17);

  String get newPassword => getContentValueFromKey(18);

  String get confirmPassword => getContentValueFromKey(19);

  String get passwordDoesNotMatch => getContentValueFromKey(20);

  String get passwordInvalid => getContentValueFromKey(21);

  String get yes => getContentValueFromKey(22);

  String get no => getContentValueFromKey(23);

  String get writeMessage => getContentValueFromKey(24);

  String get enterTheEmailAssociatedWithYourAccount => getContentValueFromKey(25);

  String get submit => getContentValueFromKey(26);

  String get language => getContentValueFromKey(27);

  String get notification => getContentValueFromKey(28);

  String get useInCaseOfEmergency => getContentValueFromKey(29);

  String get notifyAdmin => getContentValueFromKey(30);

  String get notifiedSuccessfully => getContentValueFromKey(31);

  String get complain => getContentValueFromKey(32);

  String get pleaseEnterSubject => getContentValueFromKey(33);

  String get writeDescription => getContentValueFromKey(34);

  String get saveComplain => getContentValueFromKey(35);

  String get address => getContentValueFromKey(37);

  String get updateProfile => getContentValueFromKey(36);

  String get notChangeUsername => getContentValueFromKey(39);

  String get notChangeEmail => getContentValueFromKey(40);

  String get profileUpdateMsg => getContentValueFromKey(41);

  String get emergencyContact => getContentValueFromKey(42);

  String get areYouSureYouWantDeleteThisNumber => getContentValueFromKey(43);

  String get addContact => getContentValueFromKey(44);

  String get save => getContentValueFromKey(45);

  String get availableBalance => getContentValueFromKey(46);

  String get recentTransactions => getContentValueFromKey(47);

  String get moneyDeposited => getContentValueFromKey(48);

  String get addMoney => getContentValueFromKey(49);

  String get cancel => getContentValueFromKey(50);

  String get pleaseSelectAmount => getContentValueFromKey(51);

  String get amount => getContentValueFromKey(52);

  String get confirm => getContentValueFromKey(57);

  String get wallet => getContentValueFromKey(60);

  String get paymentDetail => getContentValueFromKey(61);

  String get rideId => getContentValueFromKey(62);

  String get viewHistory => getContentValueFromKey(63);

  String get paymentDetails => getContentValueFromKey(64);

  String get paymentType => getContentValueFromKey(65);

  String get paymentStatus => getContentValueFromKey(66);

  String get priceDetail => getContentValueFromKey(67);

  String get basePrice => getContentValueFromKey(68);

  String get distancePrice => getContentValueFromKey(69);

  String get waitTime => getContentValueFromKey(70);

  String get extraCharges => getContentValueFromKey(71);

  String get couponDiscount => getContentValueFromKey(72);

  String get total => getContentValueFromKey(73);

  String get payment => getContentValueFromKey(74);

  String get cash => getContentValueFromKey(75);

  String get waitingForDriverConformation => getContentValueFromKey(77);

  String get tip => getContentValueFromKey(80);

  String get pay => getContentValueFromKey(81);

  String get howWasYourRide => getContentValueFromKey(82);

  String get addReviews => getContentValueFromKey(86);

  String get writeYourComments => getContentValueFromKey(87);

  String get continueD => getContentValueFromKey(88);

  String get detailScreen => getContentValueFromKey(258);

  String get rideHistory => getContentValueFromKey(90);

  String get emergencyContacts => getContentValueFromKey(91);

  String get logOut => getContentValueFromKey(92);

  String get areYouSureYouWantToLogoutThisApp => getContentValueFromKey(93);

  String get destinationLocation => getContentValueFromKey(97);

  String get profile => getContentValueFromKey(99);

  String get privacyPolicy => getContentValueFromKey(100);

  String get helpSupport => getContentValueFromKey(101);

  String get termsConditions => getContentValueFromKey(102);

  String get aboutUs => getContentValueFromKey(103);

  String get rides => getContentValueFromKey(107);

  String get sendOTP => getContentValueFromKey(112);

  String get vehicleModel => getContentValueFromKey(113);

  String get sos => getContentValueFromKey(114);

  String get signInUsingYourMobileNumber => getContentValueFromKey(116);

  String get newRideRequested => getContentValueFromKey(118);

  String get accepted => getContentValueFromKey(119);

  String get arriving => getContentValueFromKey(120);

  String get arrived => getContentValueFromKey(121);

  String get inProgress => getContentValueFromKey(122);

  String get cancelled => getContentValueFromKey(123);

  String get completed => getContentValueFromKey(124);

  String get pleaseEnableLocationPermission => getContentValueFromKey(125);

  String get pending => getContentValueFromKey(126);

  String get failed => getContentValueFromKey(127);

  String get paid => getContentValueFromKey(128);

  String get male => getContentValueFromKey(129);

  String get female => getContentValueFromKey(130);

  String get other => getContentValueFromKey(131);

  String get addExtraCharges => getContentValueFromKey(276);

  String get enterAmount => getContentValueFromKey(277);

  String get pleaseAddAmount => getContentValueFromKey(278);

  String get title => getContentValueFromKey(279);

  String get saveCharges => getContentValueFromKey(280);

  String get bankName => getContentValueFromKey(212);

  String get bankCode => getContentValueFromKey(213);

  String get accountHolderName => getContentValueFromKey(214);

  String get accountNumber => getContentValueFromKey(215);

  String get updateBankDetail => getContentValueFromKey(216);

  String get addBankDetail => getContentValueFromKey(217);

  String get bankInfoUpdated => getContentValueFromKey(210);

  String get close => getContentValueFromKey(245);

  String get youAreOnlineNow => getContentValueFromKey(281);

  String get youAreOfflineNow => getContentValueFromKey(282);

  String get requests => getContentValueFromKey(283);

  String get areYouSureYouWantToCancelThisRequest => getContentValueFromKey(284);

  String get decline => getContentValueFromKey(285);

  String get accept => getContentValueFromKey(286);

  String get areYouSureYouWantToAcceptThisRequest => getContentValueFromKey(287);

  String get call => getContentValueFromKey(288);

  String get areYouSureYouWantToArriving => getContentValueFromKey(289);

  String get areYouSureYouWantToArrived => getContentValueFromKey(290);

  String get enterOtp => getContentValueFromKey(291);

  String get pleaseEnterValidOtp => getContentValueFromKey(292);

  String get pleaseSelectService => getContentValueFromKey(293);

  String get userDetail => getContentValueFromKey(294);

  String get selectService => getContentValueFromKey(295);

  String get vehicleColor => getContentValueFromKey(296);

  String get vehiclePlateNumber => getContentValueFromKey(297);

  String get vehicleProductionYear => getContentValueFromKey(298);

  String get withDraw => getContentValueFromKey(186);

  String get withdrawHistory => getContentValueFromKey(187);

  String get approved => getContentValueFromKey(188);

  String get requested => getContentValueFromKey(189);

  String get updateVehicle => getContentValueFromKey(299);

  String get userNotApproveMsg => getContentValueFromKey(300);

  String get uploadFileConfirmationMsg => getContentValueFromKey(301);

  String get selectDocument => getContentValueFromKey(302);

  String get addDocument => getContentValueFromKey(303);

  String get areYouSureYouWantToDeleteThisDocument => getContentValueFromKey(304);

  String get expireDate => getContentValueFromKey(305);

  String get goDashBoard => getContentValueFromKey(306);

  String get deleteAccount => getContentValueFromKey(132);

  String get account => getContentValueFromKey(133);

  String get areYouSureYouWantPleaseReadAffect => getContentValueFromKey(134);

  String get deletingAccountEmail => getContentValueFromKey(135);

  String get areYouSureYouWantDeleteAccount => getContentValueFromKey(136);

  String get yourInternetIsNotWorking => getContentValueFromKey(137);

  String get allow => getContentValueFromKey(138);

  String get mostReliableMightyDriverApp => getContentValueFromKey(307);

  String get toEnjoyYourRideExperiencePleaseAllowPermissions => getContentValueFromKey(140);

  String get cashCollected => getContentValueFromKey(308);

  String get areYouSureCollectThisPayment => getContentValueFromKey(309);

  String get txtURLEmpty => getContentValueFromKey(141);

  String get lblFollowUs => getContentValueFromKey(142);

  String get bankInfo => getContentValueFromKey(211);

  String get duration => getContentValueFromKey(143);

  String get moneyDebit => getContentValueFromKey(156);

  String get demoMsg => getContentValueFromKey(145);

  String get youCannotChangePhoneNumber => getContentValueFromKey(150);

  String get offLine => getContentValueFromKey(310);

  String get online => getContentValueFromKey(311);

  String get aboutRider => getContentValueFromKey(312);

  String get pleaseEnterMsg => getContentValueFromKey(153);

  String get pleaseSelectRating => getContentValueFromKey(155);

  String get serviceInfo => getContentValueFromKey(313);

  String get youCannotChangeService => getContentValueFromKey(314);

  String get vehicleInfoUpdateSucessfully => getContentValueFromKey(315);

  String get isMandatoryDocument => getContentValueFromKey(316);

  String get someRequiredDocumentAreNotUploaded => getContentValueFromKey(317);

  String get areYouCertainOffline => getContentValueFromKey(318);

  String get areYouCertainOnline => getContentValueFromKey(319);

  String get pleaseAcceptTermsOfServicePrivacyPolicy => getContentValueFromKey(157);

  String get rememberMe => getContentValueFromKey(158);

  String get agreeToThe => getContentValueFromKey(159);

  String get riderInformation => getContentValueFromKey(320);

  String get invoice => getContentValueFromKey(165);

  String get customerName => getContentValueFromKey(166);

  String get sourceLocation => getContentValueFromKey(167);

  String get invoiceNo => getContentValueFromKey(168);

  String get invoiceDate => getContentValueFromKey(169);

  String get orderedDate => getContentValueFromKey(170);

  String get totalEarning => getContentValueFromKey(321);

  String get pleaseSelectFromDateAndToDate => getContentValueFromKey(322);

  String get fromDate => getContentValueFromKey(323);

  String get toDate => getContentValueFromKey(324);

  String get lblRide => getContentValueFromKey(172);

  String get weeklyOrderCount => getContentValueFromKey(325);

  String get distance => getContentValueFromKey(176);

  String get iAgreeToThe => getContentValueFromKey(159);

  String get today => getContentValueFromKey(326);

  String get weekly => getContentValueFromKey(327);

  String get report => getContentValueFromKey(328);

  String get todayEarning => getContentValueFromKey(329);

  String get yourAccountIs => getContentValueFromKey(330);

  String get pleaseContactSystemAdministrator => getContentValueFromKey(331);

  String get applyExtraCharges => getContentValueFromKey(332);

  String get pleaseSelectExtraCharges => getContentValueFromKey(333);

  String get unsupportedPlateForm => getContentValueFromKey(204);

  String get description => getContentValueFromKey(206);

  String get price => getContentValueFromKey(207);

  String get gallery => getContentValueFromKey(208);

  String get camera => getContentValueFromKey(209);

  String get locationNotAvailable => getContentValueFromKey(218);

  String get bankInfoNotFound => getContentValueFromKey(259);

  String get minimum => getContentValueFromKey(185);

  String get maximum => getContentValueFromKey(183);

  String get required => getContentValueFromKey(184);

  String get paymentFailed => getContentValueFromKey(220);

  String get checkConsoleForError => getContentValueFromKey(221);

  String get transactionFailed => getContentValueFromKey(222);

  String get transactionSuccessful => getContentValueFromKey(223);

  String get payWithCard => getContentValueFromKey(224);

  String get success => getContentValueFromKey(225);

  String get declined => getContentValueFromKey(227);

  String get endRide => getContentValueFromKey(334);

  String get startRide => getContentValueFromKey(335);

  String get invoiceCapital => getContentValueFromKey(205);

  String get validateOtp => getContentValueFromKey(228);

  String get otpCodeHasBeenSentTo => getContentValueFromKey(229);

  String get pleaseEnterOtp => getContentValueFromKey(230);

  String get selectSources => getContentValueFromKey(231);

  String get file => getContentValueFromKey(336);

  String get documents => getContentValueFromKey(337);

  String get earnings => getContentValueFromKey(338);

  String get noteSelectFromDate => getContentValueFromKey(339);

  String get settings => getContentValueFromKey(239);

  String get skip => getContentValueFromKey(226);

  String get via => getContentValueFromKey(233);

  String get status => getContentValueFromKey(234);

  String get minutePrice => getContentValueFromKey(236);

  String get waitingTimePrice => getContentValueFromKey(237);

  String get additionalFees => getContentValueFromKey(238);

  String get welcome => getContentValueFromKey(240);

  String get signContinue => getContentValueFromKey(241);

  String get writeReasonHere => getContentValueFromKey(194);

  String get cancelRide => getContentValueFromKey(191);

  String get cancelledReason => getContentValueFromKey(192);

  String get networkErr => getContentValueFromKey(254);

  String get tryAgain => getContentValueFromKey(255);

  String get noConnected => getContentValueFromKey(256);

  String get iban => getContentValueFromKey(261);

  String get swift => getContentValueFromKey(262);

  String get routingNumber => getContentValueFromKey(263);

  String get fixedPrice => getContentValueFromKey(264);

  String get viewDropLocations => getContentValueFromKey(265);

  String get viewMore => getContentValueFromKey(266);

  String get riderReview => getContentValueFromKey(340);

  String get fileSizeValidateMsg => getContentValueFromKey(341);

  String get chatWithAdmin => getContentValueFromKey(342);

  String get updateVehicleInfo => getContentValueFromKey(343);

  String get minimumFees => getContentValueFromKey(344);

  String get tips => getContentValueFromKey(345);

  String get updateDrop => getContentValueFromKey(346);

  String get finishMsg => getContentValueFromKey(347);

  String get extraFees => getContentValueFromKey(348);

  String get startRideAskOTP => getContentValueFromKey(349);

  String get lessWalletAmountMsg => getContentValueFromKey(350);

  String get chooseMap => getContentValueFromKey(351);

  String get ridingPerson => getContentValueFromKey(352);

  String get riderNotAnswer => getContentValueFromKey(353);

  String get accidentAccept => getContentValueFromKey(354);

  String get riderNotOnTime => getContentValueFromKey(355);

  String get vehicleProblem => getContentValueFromKey(356);

  String get paymentSuccess => getContentValueFromKey(357);

  String get estAmount => getContentValueFromKey(358);

  String get dontFeelSafe => getContentValueFromKey(359);

  String get wrongTurn => getContentValueFromKey(360);

  String get rideCanceledByRider => getContentValueFromKey(361);

  String get driver_walkthrough_title_1 => getContentValueFromKey(362);

  String get driver_walkthrough_title_2 => getContentValueFromKey(363);

  String get driver_walkthrough_title_3 => getContentValueFromKey(364);

  String get driver_walkthrough_subtitle_1 => getContentValueFromKey(365);

  String get driver_walkthrough_subtitle_2 => getContentValueFromKey(366);

  String get driver_walkthrough_subtitle_3 => getContentValueFromKey(367);

  String get bid_under_review => getContentValueFromKey(376);

  String get bid_under_review_note => getContentValueFromKey(377);

  String get cancel_my_bid => getContentValueFromKey(379);

  String get note => getContentValueFromKey(380);

  String get note_optional => getContentValueFromKey(375);

  String get bid_for_ride => getContentValueFromKey(369);

  String get place_bid => getContentValueFromKey(373);

  String get place_your_bid => getContentValueFromKey(374);

  String get platformFee => getContentValueFromKey(384);

  String get youWillGet => getContentValueFromKey(385);

  String get enterValidAmount => getContentValueFromKey(386);

  String get updateAvailable => getContentValueFromKey(387);

  String get updateNote => getContentValueFromKey(388);

  String get updateNow => getContentValueFromKey(389);

  String get schedule => getContentValueFromKey(390);
  String get schedule_at => getContentValueFromKey(391);
  String get now => getContentValueFromKey(392);
  String get schedule_list_title => getContentValueFromKey(393);
  String get schedule_list_desc => getContentValueFromKey(394);

  String get refer_and_earn => getContentValueFromKey(395);
  String get earned_reward => getContentValueFromKey(396);
  String get referral_code => getContentValueFromKey(397);

  String get regular => getContentValueFromKey(398);
  String get airPickup => getContentValueFromKey(399);
  String get airDropOff => getContentValueFromKey(400);
  String get zoneWise => getContentValueFromKey(401);
  String get zoneToAir => getContentValueFromKey(402);
  String get airToZone => getContentValueFromKey(403);

  String get lblUpcomingService => getContentValueFromKey(404);

  String get lblReferTitle => getContentValueFromKey(405);
  String get lblReferSubtitle => getContentValueFromKey(406);
  String get lblReferralHistory => getContentValueFromKey(407);
  String get lblEarnedReward => getContentValueFromKey(408);

  String get flightDetails => getContentValueFromKey(409);
  String get flightNumber => getContentValueFromKey(410);
  String get flightTacking => getContentValueFromKey(411);
  String get overRollFlightStatus => getContentValueFromKey(412);
  String get flightDate => getContentValueFromKey(413);
  String get DepInformation => getContentValueFromKey(414);
  String get airport => getContentValueFromKey(415);
  String get scheduledDep => getContentValueFromKey(416);
  String get estimatedDep => getContentValueFromKey(417);
  String get actualDep => getContentValueFromKey(418);

  String get terminalAddress => getContentValueFromKey(419);
  String get terminalHelperText => getContentValueFromKey(420);
  String get preferredPickupTime => getContentValueFromKey(421);
  String get preferredDropTime => getContentValueFromKey(422);
  String get track => getContentValueFromKey(423);
  String get collectAmount => getContentValueFromKey(424);
  String get collectOrder => getContentValueFromKey(425);
  String get completeDelivery => getContentValueFromKey(426);
  String get paymentReceive => getContentValueFromKey(427);
  String get paymentReceiveDesc => getContentValueFromKey(428);
  String get name => getContentValueFromKey(429);

  String get AircraftInfo => getContentValueFromKey(430);
  String get AirCraftType => getContentValueFromKey(431);

  String get selectAirport => getContentValueFromKey(432);
  String get searchAirport => getContentValueFromKey(433);

  String get scheduledArri => getContentValueFromKey(434);
  String get estimatedArri => getContentValueFromKey(435);
  String get actualArri => getContentValueFromKey(436);
  String get AirFlightDetails => getContentValueFromKey(437);
  String get airline => getContentValueFromKey(438);
  String get registration => getContentValueFromKey(439);
  String get pickupdistance => getContentValueFromKey(440);
  String get bagClaim => getContentValueFromKey(441);

  String get tripType => getContentValueFromKey(442);
  String get bookService => getContentValueFromKey(443);

  String get selectZone => getContentValueFromKey(444);
  String get searchZone => getContentValueFromKey(445);
  String get estimate => getContentValueFromKey(446);

  String get driverToPickupDistance => getContentValueFromKey(447);
  String get pickupToDropDistance => getContentValueFromKey(448);
  String get lblfaq => getContentValueFromKey(449);
  String get totalFare => getContentValueFromKey(450);
  String get distanceFare => getContentValueFromKey(451);
  String get fareBreakdown => getContentValueFromKey(452);
  String get discount => getContentValueFromKey(453);
  String get highDemandCharge => getContentValueFromKey(454);
  String get additionalCharges => getContentValueFromKey(455);
  String get extraRideTime => getContentValueFromKey(456);
  String get subTotal => getContentValueFromKey(457);
  String get promotions => getContentValueFromKey(458);
  String get timeToPickup => getContentValueFromKey(459);
  String get timeToDropOff => getContentValueFromKey(460);
  String get upcomingRideStartsIn => getContentValueFromKey(461);
  String get startingNow => getContentValueFromKey(462);
  String get bidAmountLesEarning => getContentValueFromKey(463);
  String get estimateFare => getContentValueFromKey(464);
  String get arrivingAtDropOff => getContentValueFromKey(465);
  String get arrivingAtPickup => getContentValueFromKey(466);
  String get walletBalance => getContentValueFromKey(467);
  String get walletBalanceOrCash => getContentValueFromKey(468);
  String get riderSettleCharge => getContentValueFromKey(469);
  String get estimatedFare => getContentValueFromKey(470);
  String get youEarned => getContentValueFromKey(471);
  String get additionalChargesSummary => getContentValueFromKey(472);
  String get youPaidFollowingCharges => getContentValueFromKey(473);
  String get riderSettleAmount => getContentValueFromKey(474);
  String get extraChargesPaidByYou => getContentValueFromKey(475);
  String get totalExtraAmount => getContentValueFromKey(476);
  String get extraChargeAlreadyPaidOn => getContentValueFromKey(477);
  String get noNeedToCollectFromTheCustomer => getContentValueFromKey(478);
  String get extraChargesCoveredByYou => getContentValueFromKey(479);
  String get youCoveredCharges => getContentValueFromKey(480);
  String get viewDetails => getContentValueFromKey(481);
  String get flight => getContentValueFromKey(482);
  String get terminal => getContentValueFromKey(483);
  String get ETA => getContentValueFromKey(484);
  String get arrivingNow => getContentValueFromKey(485);
  String get yourTripCompleted => getContentValueFromKey(486);
  String get driverCoveredFollowingCharge => getContentValueFromKey(487);
  String get totalAdditionalAmount => getContentValueFromKey(488);
  String get extraChargesNote => getContentValueFromKey(489);
  String get pleaseSelectPaymentMethod => getContentValueFromKey(490);
  String get extraChargesPayVia => getContentValueFromKey(491);
  String get settleAdditionalCharges => getContentValueFromKey(492);
  String get yourTripAlreadyPaid => getContentValueFromKey(493);
  String get driverPaidFollowingCharge => getContentValueFromKey(494);
  String get additionalChargesPaidByDriver => getContentValueFromKey(495);
  String get noAdditionalPaymentRequired => getContentValueFromKey(496);
  String get choosePaymentMethod => getContentValueFromKey(497);
  String get payViaWallet => getContentValueFromKey(498);
  String get lblWalletBalance => getContentValueFromKey(499);
  String get fastAndCashless => getContentValueFromKey(500);
  String get payInCashToDriver => getContentValueFromKey(501);
  String get amountHandelToDriver => getContentValueFromKey(502);
  String get insufficientWalletBalanceToPay => getContentValueFromKey(503);
  String get numberPlate => getContentValueFromKey(505);
  String get vehicleInformation => getContentValueFromKey(506);
  String get airportPickupInformation => getContentValueFromKey(507);
  String get reviews => getContentValueFromKey(508);
  String get ratedYou => getContentValueFromKey(509);
  String get noRating => getContentValueFromKey(510);
  String get comment => getContentValueFromKey(511);
}
