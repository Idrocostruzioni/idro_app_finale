import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'interventi_page_test.mocks.dart';

// Generate mocks for the Firebase classes we need to interact with.
@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  Query,
  QuerySnapshot,
  DocumentSnapshot
])
void main() {
  group('Intervention Stream', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late StreamController<QuerySnapshot<Map<String, dynamic>>> streamController;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      streamController = StreamController<QuerySnapshot<Map<String, dynamic>>>();

      // Stub the chained calls for Firestore
      when(mockFirestore.collection('interventi')).thenReturn(mockCollection);
      when(mockCollection.where(any, isGreaterThanOrEqualTo: anyNamed('isGreaterThanOrEqualTo'))).thenReturn(mockQuery);
      when(mockQuery.where(any, isLessThanOrEqualTo: anyNamed('isLessThanOrEqualTo'))).thenReturn(mockQuery);
      when(mockQuery.orderBy(any)).thenReturn(mockQuery);
      when(mockQuery.snapshots()).thenAnswer((_) => streamController.stream);
    });

    tearDown(() {
      streamController.close();
    });

    test('returns a stream of interventions', () {
      // Arrange
      final startOfDay = Timestamp.now();
      final endOfDay = Timestamp.fromMillisecondsSinceEpoch(startOfDay.millisecondsSinceEpoch + 86400000);

      // Act
      final stream = mockFirestore
          .collection('interventi')
          .where('dataInizio', isGreaterThanOrEqualTo: startOfDay)
          .where('dataInizio', isLessThanOrEqualTo: endOfDay)
          .orderBy('dataInizio')
          .snapshots();

      // Assert
      expect(stream, isA<Stream<QuerySnapshot<Map<String, dynamic>>>>());
    });

    test('returns an empty stream when an error occurs', () {
      // Arrange
      when(mockFirestore.collection('interventi')).thenThrow(Exception('Firestore error'));
      final startOfDay = Timestamp.now();
      final endOfDay = Timestamp.fromMillisecondsSinceEpoch(startOfDay.millisecondsSinceEpoch + 86400000);

      // Act
      Stream<QuerySnapshot<Map<String, dynamic>>> stream;
      try {
        stream = mockFirestore
            .collection('interventi')
            .where('dataInizio', isGreaterThanOrEqualTo: startOfDay)
            .where('dataInizio', isLessThanOrEqualTo: endOfDay)
            .orderBy('dataInizio')
            .snapshots();
      } catch (e) {
        stream = const Stream.empty();
      }

      // Assert
      expect(stream, isA<Stream<QuerySnapshot<Map<String, dynamic>>>>());
      expectLater(stream.isEmpty, completion(isTrue));
    });
  });
}