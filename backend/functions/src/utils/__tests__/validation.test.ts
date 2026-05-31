import {
  tripSchema,
  syncTripsBody,
  tripIdParam,
  kMaxSyncBatchTrips,
} from '../validation';

const VALID_UUID = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

function makeValidTrip(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: VALID_UUID,
    startTime: '2026-06-01T08:00:00.000Z',
    endTime: '2026-06-01T08:45:00.000Z',
    durationSeconds: 2700,
    distanceMeters: 12500.5,
    routePolyline: null,
    direction: 'to_office',
    timeMovingSeconds: 2400,
    timeStuckSeconds: 300,
    isManualEntry: false,
    createdAt: '2026-06-01T08:45:01.000Z',
    updatedAt: '2026-06-01T08:45:01.000Z',
    ...overrides,
  };
}

describe('tripSchema', () => {
  it('accepts a fully-valid trip (UUID id, ISO timestamps, enum direction, null polyline)', () => {
    expect(tripSchema.safeParse(makeValidTrip()).success).toBe(true);
  });

  it('accepts a trip with userId omitted (server forces it)', () => {
    const trip = makeValidTrip();
    expect('userId' in trip).toBe(false);
    expect(tripSchema.safeParse(trip).success).toBe(true);
  });

  it('accepts a trip with a present routePolyline string', () => {
    expect(
      tripSchema.safeParse(makeValidTrip({ routePolyline: '_p~iF~ps|U_ulLnnqC' })).success,
    ).toBe(true);
  });

  it('rejects a missing id', () => {
    const trip = makeValidTrip();
    delete trip.id;
    expect(tripSchema.safeParse(trip).success).toBe(false);
  });

  it('rejects a non-UUID id', () => {
    expect(tripSchema.safeParse(makeValidTrip({ id: 'not-a-uuid' })).success).toBe(false);
  });

  it('rejects an invalid direction value', () => {
    expect(tripSchema.safeParse(makeValidTrip({ direction: 'sideways' })).success).toBe(false);
  });

  it('rejects a non-ISO startTime', () => {
    expect(tripSchema.safeParse(makeValidTrip({ startTime: 'June 1 2026' })).success).toBe(false);
  });

  it('rejects distanceMeters as a string', () => {
    expect(tripSchema.safeParse(makeValidTrip({ distanceMeters: '12500' })).success).toBe(false);
  });

  it('rejects a non-integer durationSeconds', () => {
    expect(tripSchema.safeParse(makeValidTrip({ durationSeconds: 27.5 })).success).toBe(false);
  });

  it('rejects a routePolyline over the length cap', () => {
    const tooLong = 'x'.repeat(100001);
    expect(tripSchema.safeParse(makeValidTrip({ routePolyline: tooLong })).success).toBe(false);
  });

  it('accepts a routePolyline at the length cap', () => {
    const atCap = 'x'.repeat(100000);
    expect(tripSchema.safeParse(makeValidTrip({ routePolyline: atCap })).success).toBe(true);
  });
});

describe('syncTripsBody', () => {
  it('accepts a body with one valid trip', () => {
    expect(syncTripsBody.safeParse({ trips: [makeValidTrip()] }).success).toBe(true);
  });

  it('accepts a body with exactly kMaxSyncBatchTrips trips', () => {
    const trips = Array.from({ length: kMaxSyncBatchTrips }, () => makeValidTrip());
    expect(syncTripsBody.safeParse({ trips }).success).toBe(true);
  });

  it('rejects an empty trips array (min 1)', () => {
    expect(syncTripsBody.safeParse({ trips: [] }).success).toBe(false);
  });

  it('rejects more than kMaxSyncBatchTrips trips (DoS cap)', () => {
    const trips = Array.from({ length: kMaxSyncBatchTrips + 1 }, () => makeValidTrip());
    expect(syncTripsBody.safeParse({ trips }).success).toBe(false);
  });

  it('rejects trips as a non-array', () => {
    expect(syncTripsBody.safeParse({ trips: 'x' }).success).toBe(false);
  });

  it('rejects a body missing trips', () => {
    expect(syncTripsBody.safeParse({}).success).toBe(false);
  });
});

describe('tripIdParam', () => {
  it('accepts a valid UUID tripId', () => {
    expect(tripIdParam.safeParse({ tripId: VALID_UUID }).success).toBe(true);
  });

  it('rejects a non-UUID tripId', () => {
    expect(tripIdParam.safeParse({ tripId: 'not-a-uuid' }).success).toBe(false);
  });

  it('rejects an empty tripId', () => {
    expect(tripIdParam.safeParse({ tripId: '' }).success).toBe(false);
  });
});
