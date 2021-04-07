import 'package:flutter_biometrics/constants/available_biometrics_types.dart';
import 'package:flutter_biometrics/models/biometrics_type.dart';

class BiometricsTypeMapper {
  static List<BiometricsType> mapFrom({List<String>? list = const []}) {
    final List<BiometricsType> result = [];

    if(list == null) {
      return result;
    }

    list.forEach((type) {
      final biometricsType = from(type: type);

      if(biometricsType != BiometricsType.unknown && biometricsType != BiometricsType.none) {
        result.add(biometricsType);
      }
    });

    return result;
  }

  static BiometricsType from({String? type}) {
    switch (type) {
      case AvailableBiometricsTypes.faceId:
        return BiometricsType.faceId;
      case AvailableBiometricsTypes.fingerprint:
        return BiometricsType.fingerprint;
      case AvailableBiometricsTypes.iris:
        return BiometricsType.iris;
      case AvailableBiometricsTypes.none:
        return BiometricsType.none;
      case AvailableBiometricsTypes.undefined:
      default:
        return BiometricsType.unknown;
    }
  }
}
