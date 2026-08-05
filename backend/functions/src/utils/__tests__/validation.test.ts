import {
  tripSchema,
  syncTripsBody,
  tripIdParam,
  kMaxSyncBatchTrips,
  kMaxBreaksPerTrip,
  kMaxStuckSegmentsPerTrip,
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
    totalPausedSeconds: 0,
    isEdited: false,
    directionSource: 'time',
    breaks: [],
    stuckSegments: [],
    ...overrides,
  };
}

/** One well-formed stuck stretch, for array-building in the tests below. */
function makeStuckSegment(): Record<string, unknown> {
  return {
    startPointIndex: 4,
    endPointIndex: 11,
    startTime: '2026-06-01T08:12:00.000Z',
    endTime: '2026-06-01T08:14:30.000Z',
  };
}

/** Trip payload with the 4 Phase 26 keys omitted entirely (old-client shape). */
function makeLegacyTrip(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  const trip = makeValidTrip(overrides);
  delete trip.totalPausedSeconds;
  delete trip.isEdited;
  delete trip.directionSource;
  delete trip.breaks;
  return trip;
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

describe('tripSchema — Phase 26 metadata fields', () => {
  it('defaults all 4 new fields when omitted entirely (old-client compatibility)', () => {
    const parsed = tripSchema.safeParse(makeLegacyTrip());
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.totalPausedSeconds).toBe(0);
      expect(parsed.data.isEdited).toBe(false);
      expect(parsed.data.directionSource).toBe('time');
      expect(parsed.data.breaks).toEqual([]);
    }
  });

  it('accepts a trip with a breaks array present', () => {
    const result = tripSchema.safeParse(
      makeValidTrip({
        breaks: [
          { startTime: '2026-06-01T08:10:00.000Z', endTime: '2026-06-01T08:15:00.000Z' },
        ],
      }),
    );
    expect(result.success).toBe(true);
  });

  it('rejects a breaks array over kMaxBreaksPerTrip (51 entries)', () => {
    const breaks = Array.from({ length: kMaxBreaksPerTrip + 1 }, () => ({
      startTime: '2026-06-01T08:10:00.000Z',
      endTime: '2026-06-01T08:15:00.000Z',
    }));
    expect(tripSchema.safeParse(makeValidTrip({ breaks })).success).toBe(false);
  });

  it('accepts a breaks array at the kMaxBreaksPerTrip cap (50 entries)', () => {
    const breaks = Array.from({ length: kMaxBreaksPerTrip }, () => ({
      startTime: '2026-06-01T08:10:00.000Z',
      endTime: '2026-06-01T08:15:00.000Z',
    }));
    expect(tripSchema.safeParse(makeValidTrip({ breaks })).success).toBe(true);
  });

  it('rejects an invalid directionSource value', () => {
    expect(
      tripSchema.safeParse(makeValidTrip({ directionSource: 'bogus' })).success,
    ).toBe(false);
  });
});

describe('tripSchema — stuckSegments', () => {
  it('defaults stuckSegments to [] when omitted (old-client compatibility)', () => {
    // Every client older than this release, and every document already in
    // Firestore, omits the key entirely. Both must keep validating.
    const trip = makeValidTrip();
    delete trip.stuckSegments;
    const parsed = tripSchema.safeParse(trip);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.stuckSegments).toEqual([]);
    }
  });

  it('accepts a trip carrying stuck segments and preserves the indices', () => {
    const parsed = tripSchema.safeParse(
      makeValidTrip({ stuckSegments: [makeStuckSegment()] }),
    );
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.stuckSegments).toHaveLength(1);
      // The indices address the decoded polyline — losing them would strand
      // the segment with no way back to a map position.
      expect(parsed.data.stuckSegments[0].startPointIndex).toBe(4);
      expect(parsed.data.stuckSegments[0].endPointIndex).toBe(11);
    }
  });

  it('accepts an array at the kMaxStuckSegmentsPerTrip cap', () => {
    const stuckSegments = Array.from(
      { length: kMaxStuckSegmentsPerTrip },
      makeStuckSegment,
    );
    expect(tripSchema.safeParse(makeValidTrip({ stuckSegments })).success).toBe(true);
  });

  it('rejects an array over kMaxStuckSegmentsPerTrip', () => {
    const stuckSegments = Array.from(
      { length: kMaxStuckSegmentsPerTrip + 1 },
      makeStuckSegment,
    );
    expect(tripSchema.safeParse(makeValidTrip({ stuckSegments })).success).toBe(false);
  });

  it('allows far more stuck segments than breaks — a busy commute has many', () => {
    // Guards the deliberate asymmetry: capping stuck stretches at the breaks
    // limit would truncate real data on exactly the commutes this measures.
    expect(kMaxStuckSegmentsPerTrip).toBeGreaterThan(kMaxBreaksPerTrip);
    const stuckSegments = Array.from(
      { length: kMaxBreaksPerTrip + 1 },
      makeStuckSegment,
    );
    expect(tripSchema.safeParse(makeValidTrip({ stuckSegments })).success).toBe(true);
  });

  it('rejects a non-integer point index', () => {
    expect(
      tripSchema.safeParse(
        makeValidTrip({
          stuckSegments: [{ ...makeStuckSegment(), startPointIndex: 2.5 }],
        }),
      ).success,
    ).toBe(false);
  });

  it('rejects a negative point index', () => {
    expect(
      tripSchema.safeParse(
        makeValidTrip({
          stuckSegments: [{ ...makeStuckSegment(), endPointIndex: -1 }],
        }),
      ).success,
    ).toBe(false);
  });

  it('rejects a malformed segment timestamp', () => {
    expect(
      tripSchema.safeParse(
        makeValidTrip({
          stuckSegments: [{ ...makeStuckSegment(), startTime: 'not-a-date' }],
        }),
      ).success,
    ).toBe(false);
  });
});

describe('tripSchema — directionSource enum', () => {
  it.each(['manual', 'geofence', 'time'])(
    'accepts directionSource %s (matches client kDirectionSource* constants)',
    (value) => {
      expect(
        tripSchema.safeParse(makeValidTrip({ directionSource: value })).success,
      ).toBe(true);
    },
  );

  it('rejects a break entry with a non-ISO startTime', () => {
    const result = tripSchema.safeParse(
      makeValidTrip({
        breaks: [{ startTime: 'not-a-date', endTime: '2026-06-01T08:15:00.000Z' }],
      }),
    );
    expect(result.success).toBe(false);
  });

  it('rejects a negative totalPausedSeconds', () => {
    expect(
      tripSchema.safeParse(makeValidTrip({ totalPausedSeconds: -1 })).success,
    ).toBe(false);
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
