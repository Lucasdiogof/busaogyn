export type VehicleStatus = 'in_service' | 'interval' | 'out_of_service' | 'unknown';

export interface VehiclePosition {
  latitude: number;
  longitude: number;
}

export interface Vehicle {
  id: string;
  vehicleNumber: string;
  routeId: string | null;
  destination: string | null;
  position: VehiclePosition | null;
  accessible: boolean | null;
  status: VehicleStatus;
  sourceStatus: string | null;
}
