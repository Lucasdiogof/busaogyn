import { describe, expect, it } from 'vitest';
import { parseRmtcArrivalPayload } from '../src/sources/rmtc/arrivals.source';

describe('RMTC arrivals parser', () => {
  it('keeps realtime quality and vehicle identity explicit', () => {
    const result = parseRmtcArrivalPayload({
      status: 'ok',
      data: [{
        Linha: '020',
        Destino: 'T. BIBLIA',
        Proximo: {
          Qualidade: 'Tempo Real',
          NumeroOnibus: '20529',
          HoraChegadaPlanejada: '14:02',
          HoraChegadaPrevista: '14:06',
          PrevisaoChegada: 4,
        },
        Seguinte: null,
      }],
    });

    expect(result).toHaveLength(1);
    expect(result[0]?.next).toMatchObject({
      vehicleId: 'rmtc:20529',
      vehicleNumber: '20529',
      minutes: 4,
      realtime: true,
      quality: 'realtime',
    });
    expect(result[0]?.following).toBeNull();
  });

  it('preserves zero minutes for the less-than-one-minute UI case', () => {
    const result = parseRmtcArrivalPayload({
      data: [{ Linha: 20, Proximo: { Qualidade: 'Tempo Real', PrevisaoChegada: 0 } }],
    });
    expect(result[0]?.routeId).toBe('020');
    expect(result[0]?.next.minutes).toBe(0);
  });

  it('does not mark unknown quality as realtime', () => {
    const result = parseRmtcArrivalPayload({
      data: [{ Linha: '020', Proximo: { Qualidade: 'Outra', PrevisaoChegada: 3 } }],
    });
    expect(result[0]?.next.realtime).toBe(false);
    expect(result[0]?.next.quality).toBe('unknown');
  });
});
