import '../models/air_conditioner.dart';
import '../models/provisioning.dart';

abstract interface class AirConditionerRepository {
  Future<List<AirConditioner>> fetchAll();

  Future<AirProvisioningReservation> reserve(
    AirProvisioningRequest request,
  );

  Future<void> sendCommand(AirConditioner air);

  Future<void> enterSetupMode(String deviceId);

  Future<void> rename(String deviceId, String name);

  Future<void> remove(String deviceId);
}
