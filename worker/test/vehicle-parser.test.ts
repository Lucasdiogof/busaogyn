import { describe, expect, it } from 'vitest';
import { parseRmtcVehicle, parseRmtcVehiclePayload } from '../src/sources/rmtc/cconaweb.source';

describe('RMTC vehicle parser', () => {
  it('normalizes a valid vehicle and preserves the public prefix', () => {
    const vehicle = parseRmtcVehicle({
      Numero: '20529',
      Latitude: '-16.7123',
      Longitude: '-49.2567',
      Acessivel: true,
      Situacao: 'EmOperacao',
      Linha: { LinhaNumero: '020' },
      Destino: { DestinoCurto: 'T. BIBLIA' },
    });

    expect(vehicle).toMatchObject({
      id: 'rmtc:20529',
      vehicleNumber: '20529',
      routeId: '020',
      destination: 'T. BIBLIA',
      accessible: true,
      status: 'unknown',
      sourceStatus: 'EmOperacao',
      position: { latitude: -16.7123, longitude: -49.2567 },
    });
  });

  it('does not invent destination or coordinates', () => {
    const vehicle = parseRmtcVehicle({
      Numero: '20529',
      Latitude: 'x',
      Longitude: '-49.2',
      Linha: { LinhaNumero: 20 },
      Destino: null,
    });
    expect(vehicle?.routeId).toBe('020');
    expect(vehicle?.destination).toBeNull();
    expect(vehicle?.position).toBeNull();
  });

  it('recognizes inactive source statuses', () => {
    expect(parseRmtcVehicle({ Numero: '1', Situacao: 'ForaServico' })?.status).toBe('out_of_service');
    expect(parseRmtcVehicle({ Numero: '2', Situacao: 'Intervalo' })?.status).toBe('interval');
  });

  it('accepts the cconaweb object envelope', () => {
    expect(parseRmtcVehiclePayload({ onibus: [{ Numero: '1' }, { Numero: '2' }] })).toHaveLength(2);
  });
});
