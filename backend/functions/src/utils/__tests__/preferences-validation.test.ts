import { savedLocationsSchema, syncPreferencesBody } from '../validation';

/**
 * Unit suite for the Phase 29 saved-locations schema (LOC-03, T-29-04).
 *
 * The range and pair-consistency rules are the only thing standing between a
 * malformed coordinate and the client's geofence resolver, where a bad value
 * does not throw — it silently mislabels the direction of every future trip.
 * These tests exist to pin that boundary.
 */

function locations(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    homeLat: 12.9716,
    homeLng: 77.5946,
    officeLat: 12.9352,
    officeLng: 77.6245,
    ...overrides,
  };
}

describe('savedLocationsSchema', () => {
  describe('happy path', () => {
    it('accepts a fully populated set', () => {
      const parsed = savedLocationsSchema.safeParse(locations());
      expect(parsed.success).toBe(true);
    });

    it('accepts all-null — the user who never set a location (SC#5)', () => {
      const parsed = savedLocationsSchema.safeParse({
        homeLat: null,
        homeLng: null,
        officeLat: null,
        officeLng: null,
      });
      expect(parsed.success).toBe(true);
    });

    it('defaults missing keys to null rather than rejecting (SC#5)', () => {
      const parsed = savedLocationsSchema.safeParse({});
      expect(parsed.success).toBe(true);
      if (parsed.success) {
        expect(parsed.data).toEqual({
          homeLat: null,
          homeLng: null,
          officeLat: null,
          officeLng: null,
        });
      }
    });

    it('accepts Home set with Office unset', () => {
      const parsed = savedLocationsSchema.safeParse(
        locations({ officeLat: null, officeLng: null }),
      );
      expect(parsed.success).toBe(true);
    });

    it('accepts the exact boundary values', () => {
      expect(
        savedLocationsSchema.safeParse(
          locations({ homeLat: 90, homeLng: 180, officeLat: -90, officeLng: -180 }),
        ).success,
      ).toBe(true);
    });
  });

  describe('range rejection (T-29-04)', () => {
    it.each([
      ['latitude above 90', { homeLat: 90.0001 }],
      ['latitude below -90', { homeLat: -90.0001 }],
      ['longitude above 180', { homeLng: 180.0001 }],
      ['longitude below -180', { homeLng: -180.0001 }],
      ['office latitude out of range', { officeLat: 91 }],
      ['office longitude out of range', { officeLng: -181 }],
    ])('rejects %s', (_label, override) => {
      expect(savedLocationsSchema.safeParse(locations(override)).success).toBe(false);
    });

    it('rejects NaN', () => {
      expect(savedLocationsSchema.safeParse(locations({ homeLat: NaN })).success).toBe(
        false,
      );
    });

    it.each([
      ['Infinity', Infinity],
      ['-Infinity', -Infinity],
    ])('rejects %s — the reason .finite() is on the schema', (_label, value) => {
      // z.number() rejects NaN but ACCEPTS Infinity. Without .finite(), a
      // -Infinity latitude would satisfy .min(-90) and reach Firestore.
      expect(savedLocationsSchema.safeParse(locations({ homeLat: value })).success).toBe(
        false,
      );
    });

    it('rejects a coordinate sent as a string', () => {
      expect(
        savedLocationsSchema.safeParse(locations({ homeLat: '12.9716' })).success,
      ).toBe(false);
    });
  });

  describe('pair consistency', () => {
    it('rejects a latitude without its longitude', () => {
      expect(savedLocationsSchema.safeParse(locations({ homeLng: null })).success).toBe(
        false,
      );
    });

    it('rejects a longitude without its latitude', () => {
      expect(savedLocationsSchema.safeParse(locations({ homeLat: null })).success).toBe(
        false,
      );
    });

    it('rejects a half-set office pair', () => {
      expect(
        savedLocationsSchema.safeParse(locations({ officeLat: null })).success,
      ).toBe(false);
    });

    it('treats 0,0 as a set pair, not as absent', () => {
      // Null Island is a valid coordinate. Any implementation that used
      // falsiness instead of an explicit null check would wrongly reject this.
      const parsed = savedLocationsSchema.safeParse(
        locations({ homeLat: 0, homeLng: 0 }),
      );
      expect(parsed.success).toBe(true);
    });
  });
});

describe('syncPreferencesBody', () => {
  it('accepts a well-formed body', () => {
    expect(
      syncPreferencesBody.safeParse({ savedLocations: locations() }).success,
    ).toBe(true);
  });

  it('rejects a body missing savedLocations entirely', () => {
    expect(syncPreferencesBody.safeParse({}).success).toBe(false);
  });

  it('rejects a body whose savedLocations fails validation', () => {
    expect(
      syncPreferencesBody.safeParse({ savedLocations: locations({ homeLat: 500 }) })
        .success,
    ).toBe(false);
  });
});
