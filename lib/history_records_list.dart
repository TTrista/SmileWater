import 'package:flutter/material.dart';

class HistoryRecordsListPage extends StatelessWidget {
  const HistoryRecordsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History Records List',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: const Center(
        child: Text(
          'This is the history records list page.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
} 
