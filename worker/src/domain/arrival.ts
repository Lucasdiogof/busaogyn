export type ArrivalQuality = 'realtime' | 'scheduled' | 'unknown';

export interface Arrival {
  vehicleId: string | null;
  vehicleNumber: string | null;
  minutes: number | null;
  plannedArrival: string | null;
  predictedArrival: string | null;
  realtime: boolean;
  quality: ArrivalQuality;
  sourceQuality: string | null;
}

export interface ArrivalGroup {
  routeId: string;
  destination: string | null;
  next: Arrival;
  following: Arrival | null;
}
