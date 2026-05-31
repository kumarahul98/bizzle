import {
  getFirestore,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import type { TripDoc } from '../types/trip';

/**
 * Typed converter for trip documents (D-09/D-10). Reads/writes map to the
 * {@link TripDoc} interface so handlers never touch untyped `DocumentData`.
 */
export const tripConverter: FirestoreDataConverter<TripDoc> = {
  toFirestore: (trip: TripDoc) => trip,
  fromFirestore: (snapshot: QueryDocumentSnapshot): TripDoc =>
    snapshot.data() as TripDoc,
};

/**
 * The top-level `trips` collection, typed via {@link tripConverter}. Document
 * id is the client trip UUID (D-09).
 */
export const tripsCollection = () =>
  getFirestore().collection('trips').withConverter(tripConverter);
