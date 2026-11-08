import '../main.dart';

List<String> getCancelReasonList() {
  List<String> list = [];
  list.add(language.riderNotAnswer);
  list.add(language.accidentAccept);
  list.add(language.riderNotOnTime);
  list.add(language.dontFeelSafe);
  list.add(language.wrongTurn);
  list.add(language.vehicleProblem);
  list.add(language.other);
  return list;
}
