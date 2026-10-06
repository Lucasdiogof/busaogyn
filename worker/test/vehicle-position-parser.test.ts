import { describe, expect, it } from 'vitest';
import { parseTrackedVehiclePayload } from '../src/sources/rmtc/vehicle-position.source';

describe('RMTC individual vehicle parser', () => {
  it('parses the live simapp vehicle response without inventing identifiers', () => {
    const vehicle = parseTrackedVehiclePayload({
      status: 'true',
      mensagem: '',
      data: [{
        Numero: 50614,
        PontoParada: {
          PontoId: 513,
          PontoEndereco: 'Avenida 85, St. Bueno - Goiania',
        },
        Linha: {
          LinhaNumero: '008',
          LinhaItinerario: 'T. Veiga Jardim / Eixo 85 / T. Paulo Garcia',
        },
        Destino: { DestinoNome: 'T VEIGA JARDIM' },
        Posicao: { Latitude: -16.7071, Longitude: -49.2640 },
        Situacao: 'Atrasado',
        Acessivel: 1,
        Previsao: {
          HoraChegadaPrevista: '2026-10-06T18:10:00-03:00',
          PrevisaoChegada: 39,
        },
      }],
    });

    expect(vehicle).toMatchObject({
      id: 'rmtc:50614',
      vehicleNumber: '50614',
      routeId: '008',
      destination: 'T VEIGA JARDIM',
      accessible: true,
      punctuality: { status: 'delayed', sourceStatus: 'Atrasado' },
      referenceStop: { sourceStopId: '513' },
      prediction: { minutes: 39 },
    });
  });

  it('maps on-time status and empty data safely', () => {
    expect(parseTrackedVehiclePayload({
      data: [{ Numero: '20552', Situacao: 'NoHorario' }],
    })?.punctuality.status).toBe('on_time');

    expect(parseTrackedVehiclePayload({ data: [] })).toBeNull();
  });
});
