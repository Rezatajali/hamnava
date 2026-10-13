import 'package:cloud_firestore/cloud_firestore.dart';
import 'receipts.dart';

class PersonalRepository {
  PersonalRepository(this.uid, {FirebaseFirestore? database})
    : db = database ?? FirebaseFirestore.instance;
  final String uid;
  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      db.collection('users').doc(uid).collection(name);

  Query<Map<String, dynamic>> journalQuery(int limit) =>
      collection('journal').orderBy('createdAt', descending: true).limit(limit);

  Query<Map<String, dynamic>> monthQuery(DateTime month) =>
      collection('transactions').where(
        'month',
        isEqualTo: '${month.year}-${month.month.toString().padLeft(2, '0')}',
      );

  Future<void> saveJournal(String id, Map<String, dynamic> data) =>
      save('journal', id, data);

  Future<void> saveTransaction(
    String id,
    Map<String, dynamic> data, {
    List<ReceiptPhoto> added = const [],
    List<String> removed = const [],
  }) => db
      .runTransaction<void>((transaction) async {
        final ref = collection('transactions').doc(id);
        final previous = await transaction.get(ref);
        final oldIds = List<String>.from(
          previous.data()?['receiptIds'] as List? ?? const [],
        );
        final nextIds = {
          ...oldIds.where((id) => !removed.contains(id)),
          ...added.map((r) => r.id),
        }.toList();
        if (nextIds.length > 3)
          throw StateError('At most three receipts per transaction');
        final newReceipts = <ReceiptPhoto>[];
        for (final receipt in added) {
          if (oldIds.contains(receipt.id))
            continue; // Retry after an acknowledged or timed-out commit.
          final existing = await transaction.get(
            collection('receipts').doc(receipt.id),
          );
          if (existing.exists) throw StateError('Receipt ID already used');
          newReceipts.add(receipt);
        }
        transaction.set(ref, {
          ...data,
          'receiptIds': nextIds,
          'createdAt': previous.data()?['createdAt'] ?? data['createdAt'],
        });
        for (final receipt in newReceipts) {
          transaction.set(
            collection('receipts').doc(receipt.id),
            receipt.createData(id),
          );
        }
        for (final receiptId in removed.where(oldIds.contains)) {
          transaction.delete(collection('receipts').doc(receiptId));
        }
      })
      .timeout(const Duration(seconds: 30));

  Future<List<ReceiptPhoto>> transactionReceipts(
    Map<String, dynamic> data,
  ) async {
    final photos = <ReceiptPhoto>[];
    for (final id in List<String>.from(
      data['receiptIds'] as List? ?? const [],
    )) {
      final doc = await collection(
        'receipts',
      ).doc(id).get(const GetOptions(source: Source.server));
      if (doc.exists) photos.add(ReceiptPhoto.fromMap(doc.id, doc.data()!));
    }
    return photos;
  }

  Future<List<ReceiptPhoto>> monthReceipts(DateTime month) async {
    final transactions = await monthQuery(
      month,
    ).get(const GetOptions(source: Source.server));
    final photos = <ReceiptPhoto>[];
    for (final doc in transactions.docs) {
      photos.addAll(await transactionReceipts(doc.data()));
    }
    return photos;
  }

  Future<List<ReceiptPhoto>> allReceipts() async {
    final photos = <ReceiptPhoto>[];
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> query = collection(
        'receipts',
      ).orderBy(FieldPath.documentId).limit(25);
      if (last != null) query = query.startAfterDocument(last);
      final batch = await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      photos.addAll(
        batch.docs.map((doc) => ReceiptPhoto.fromMap(doc.id, doc.data())),
      );
      if (batch.docs.length < 25) break;
      last = batch.docs.last;
    }
    return photos;
  }

  Future<void> deleteTransaction(String id) => db
      .runTransaction<void>((transaction) async {
        final ref = collection('transactions').doc(id);
        final previous = await transaction.get(ref);
        if (!previous.exists) return;
        for (final receiptId in List<String>.from(
          previous.data()?['receiptIds'] as List? ?? const [],
        )) {
          transaction.delete(collection('receipts').doc(receiptId));
        }
        transaction.delete(ref);
      })
      .timeout(const Duration(seconds: 30));

  Future<void> save(String name, String id, Map<String, dynamic> data) => db
      .runTransaction<void>((transaction) async {
        final ref = collection(name).doc(id);
        final previous = await transaction.get(ref);
        transaction.set(ref, {
          ...data,
          'createdAt': previous.data()?['createdAt'] ?? data['createdAt'],
        });
      })
      .timeout(const Duration(seconds: 20));

  Future<void> delete(String collectionName, String id) => collection(
    collectionName,
  ).doc(id).delete().timeout(const Duration(seconds: 20));

  Future<Map<String, dynamic>> exportAll() async {
    Future<List<Map<String, dynamic>>> read(String name) async {
      final records = <Map<String, dynamic>>[];
      DocumentSnapshot<Map<String, dynamic>>? last;
      while (true) {
        Query<Map<String, dynamic>> query = collection(
          name,
        ).orderBy(FieldPath.documentId).limit(name == 'receipts' ? 25 : 250);
        if (last != null) query = query.startAfterDocument(last);
        final batch = await query
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 20));
        for (final doc in batch.docs) {
          records.add({
            'id': doc.id,
            ...doc.data().map(
              (key, value) => MapEntry(
                key,
                value is Timestamp ? value.toDate().toIso8601String() : value,
              ),
            ),
          });
        }
        if (batch.docs.length < (name == 'receipts' ? 25 : 250)) break;
        last = batch.docs.last;
      }
      return records;
    }

    return {
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'journal': await read('journal'),
      'transactions': await read('transactions'),
      'receipts': await read('receipts'),
    };
  }
}
