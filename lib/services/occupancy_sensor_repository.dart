import '../models/provisioning.dart';

abstract interface class OccupancySensorRepository {
  Future<OccupancyProvisioningReservation> reserve(
    OccupancyProvisioningRequest request,
  );

  Future<void> enterSetupMode(String deviceId);

  Future<void> remove(String deviceId);
}
