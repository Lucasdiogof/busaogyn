export type VehiclePunctuality = 'on_time' | 'delayed' | 'early' | 'unknown';

export interface TrackedVehicle {
  id: string;
  vehicleNumber: string;
  routeId: string | null;
  routeName: string | null;
  destination: string | null;
  position: {
    latitude: number;
    longitude: number;
  } | null;
  accessible: boolean | null;
  punctuality: {
    status: VehiclePunctuality;
    sourceStatus: string | null;
  };
  referenceStop: {
    sourceStopId: string | null;
    address: string | null;
  } | null;
  prediction: {
    predictedArrival: string | null;
    minutes: number | null;
  } | null;
}
