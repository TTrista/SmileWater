import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/history_entry.dart';

class HistoryRecordsListPage extends StatefulWidget {
  const HistoryRecordsListPage({super.key});

  @override
  State<HistoryRecordsListPage> createState() => _HistoryRecordsListPageState();
}

class _HistoryRecordsListPageState extends State<HistoryRecordsListPage> {
  final List<HistoryEntry> _records = [];
  final List<DocumentSnapshot> _documentSnapshots = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 10;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _loadMoreRecords();
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoading || !_hasMore) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('records')
        .orderBy('time', descending: true)
        .limit(_limit);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDoc = snapshot.docs.last;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final rawTime = data['time'];
        final parsedTime =
            rawTime is Timestamp
                ? rawTime.toDate()
                : DateTime.tryParse(rawTime.toString()) ?? DateTime.now();

        _records.add(
          HistoryEntry(
            ph: (data['ph'] as num).toDouble(),
            turbidity: (data['turbidity'] as num).toDouble(),
            time: parsedTime,
          ),
        );
        _documentSnapshots.add(doc);
      }
    }

    if (snapshot.docs.length < _limit) _hasMore = false;

    setState(() => _isLoading = false);
  }

  Future<void> _deleteRecord(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text('Are you sure you want to delete this record? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = _documentSnapshots[index];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('records')
        .doc(doc.id)
        .delete();

    setState(() {
      _records.removeAt(index);
      _documentSnapshots.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('	History Records'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1,
            ),
            body: Center(
              child: RichText(
                text: TextSpan(
                  text: 'Please ',
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  children: [
                    TextSpan(
                      text: 'Log in',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushNamed(context, '/profile');
                            },
                    ),
                    const TextSpan(text: ' 	to view records'),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildRecordsList();
      },
    );
  }

  Widget _buildRecordsList() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('	History Records'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _records.length + 1,
              itemBuilder: (context, index) {
                if (index == _records.length) {
                  return _hasMore
                      ? TextButton(
                        onPressed: _loadMoreRecords,
                        child: const Text('Load more'),
                      )
                      : const SizedBox();
                }

                final entry = _records[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 4,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      'pH: ${entry.ph.toStringAsFixed(2)}    	Turbidity: ${entry.turbidity.toStringAsFixed(2)} NTU',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '	Time: ${entry.time.toString().substring(0, 16)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRecord(index),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
