import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalRepository {
  PersonalRepository(this.uid, {FirebaseFirestore? database})
    : db = database ?? FirebaseFirestore.instance;
  final String uid;
  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> collection(String name) =>
    db.collection('users').doc(uid).collection(name);

  Query<Map<String, dynamic>> journalQuery(int limit) => collection('journal')
    .orderBy('createdAt', descending: true).limit(limit);

  Query<Map<String, dynamic>> monthQuery(DateTime month) => collection('transactions')
    .where('month', isEqualTo: '${month.year}-${month.month.toString().padLeft(2, '0')}');

  Future<void> saveJournal(String id, Map<String, dynamic> data) =>
    save('journal', id, data);

  Future<void> saveTransaction(String id, Map<String, dynamic> data) =>
    save('transactions', id, data);

  Future<void> save(String name, String id, Map<String, dynamic> data) => db.runTransaction<void>((transaction) async {
    final ref = collection(name).doc(id);
    final previous = await transaction.get(ref);
    transaction.set(ref, {...data, 'createdAt': previous.data()?['createdAt'] ?? data['createdAt']});
  }).timeout(const Duration(seconds: 20));

  Future<void> delete(String collectionName, String id) =>
    collection(collectionName).doc(id).delete().timeout(const Duration(seconds: 20));

  Future<Map<String, dynamic>> exportAll() async {
    Future<List<Map<String, dynamic>>> read(String name) async {
      final records = <Map<String, dynamic>>[];
      DocumentSnapshot<Map<String, dynamic>>? last;
      while (true) {
        Query<Map<String, dynamic>> query = collection(name)
          .orderBy(FieldPath.documentId).limit(250);
        if (last != null) query = query.startAfterDocument(last);
        final batch = await query.get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
        for (final doc in batch.docs) {
          records.add({'id': doc.id, ...doc.data().map((key, value) =>
            MapEntry(key, value is Timestamp ? value.toDate().toIso8601String() : value))});
        }
        if (batch.docs.length < 250) break;
        last = batch.docs.last;
      }
      return records;
    }
    return {'schemaVersion': 1, 'exportedAt': DateTime.now().toIso8601String(),
      'journal': await read('journal'), 'transactions': await read('transactions')};
  }
}
