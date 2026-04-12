import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';

void main() {
  group('Drift migration scaffold (D-10)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('schema v1 opens cleanly via SchemaVerifier', () async {
      final connection = await verifier.startAt(1);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      // Trivial sanity query — proves the connection is live.
      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });
  });
}
