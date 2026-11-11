/// Countries DROP supports for phone numbers. Nigeria is first and the default.
class DropCountry {
  const DropCountry(this.iso, this.name, this.dial, this.minDigits, this.maxDigits);

  final String iso;
  final String name;
  final String dial; // e.g. +234
  final int minDigits; // national number length without the leading 0
  final int maxDigits;

  /// Flag emoji built from the two-letter ISO code.
  String get flag => String.fromCharCodes(iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
}

const List<DropCountry> dropCountries = [
  DropCountry('NG', 'Nigeria', '+234', 10, 10),
  DropCountry('GH', 'Ghana', '+233', 9, 9),
  DropCountry('BJ', 'Benin', '+229', 8, 10),
  DropCountry('TG', 'Togo', '+228', 8, 8),
  DropCountry('CI', "Côte d'Ivoire", '+225', 8, 10),
  DropCountry('BF', 'Burkina Faso', '+226', 8, 8),
  DropCountry('NE', 'Niger', '+227', 8, 8),
  DropCountry('SN', 'Senegal', '+221', 9, 9),
  DropCountry('GM', 'Gambia', '+220', 7, 7),
  DropCountry('GN', 'Guinea', '+224', 9, 9),
  DropCountry('GW', 'Guinea-Bissau', '+245', 7, 9),
  DropCountry('LR', 'Liberia', '+231', 7, 9),
  DropCountry('SL', 'Sierra Leone', '+232', 8, 8),
  DropCountry('ML', 'Mali', '+223', 8, 8),
  DropCountry('MR', 'Mauritania', '+222', 8, 8),
  DropCountry('CV', 'Cabo Verde', '+238', 7, 7),
];

const DropCountry defaultDropCountry = DropCountry('NG', 'Nigeria', '+234', 10, 10);

/// Digits only, without a leading 0 (the local trunk prefix).
String dropNationalNumber(String input) => input.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
