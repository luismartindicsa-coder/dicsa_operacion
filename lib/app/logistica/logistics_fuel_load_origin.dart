const String kLogisticsFuelLoadOriginPatio = 'PATIO';
const String kLogisticsFuelLoadOriginGasStation = 'GASOLINERA';

String logisticsFuelLoadOriginLabel(String value) {
  return value == kLogisticsFuelLoadOriginGasStation ? 'Gasolinera' : 'Patio';
}

bool logisticsFuelIsLoadedAtPatio(String value) {
  return value != kLogisticsFuelLoadOriginGasStation;
}
