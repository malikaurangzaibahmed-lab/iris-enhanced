import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum QueueOperationType { update, set, delete }

class QueueItem {
  final String id;
  final String collectionPath;
  final String documentId;
  final QueueOperationType operation;
  final Map<String, dynamic>? data;

  QueueItem({
    required this.id,
    required this.collectionPath,
    required this.documentId,
    required this.operation,
    this.data,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'],
      collectionPath: json['collectionPath'],
      documentId: json['documentId'],
      operation: QueueOperationType.values.firstWhere((e) => e.name == json['operation']),
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionPath': collectionPath,
    'documentId': documentId,
    'operation': operation.name,
    'data': data,
  };
}

/// Zero-Cost Offline Queue Service
/// Protects the 20k/day Free Tier Write limit via offline caching and state deduplication.
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const String _queueKey = 'iris_admin_offline_queue';

  /// Adds a write operation to local SharedPreferences.
  /// Does NOT contact Firebase, preserving 100% of write quotas.
  Future<void> enqueueWrite({
    required String collectionPath,
    required String documentId,
    required QueueOperationType operation,
    Map<String, dynamic>? data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<QueueItem> queue = await _getQueue(prefs);

    queue.add(QueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString() + collectionPath + documentId,
      collectionPath: collectionPath,
      documentId: documentId,
      operation: operation,
      data: data,
    ));

    await prefs.setString(_queueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
  }

  /// Flushes the queue, explicitly deduplicating rapid edits on the same document 
  /// before converting the remainder into a Firebase WriteBatch limit.
  Future<bool> flushQueue() async {
    final prefs = await SharedPreferences.getInstance();
    List<QueueItem> queue = await _getQueue(prefs);

    if (queue.isEmpty) return true; // Nothing to sync

    // -------------------------------------------------------------
    // QUOTA SHIELD: Deduplicate rapid offline changes 
    // E.g., Changing a toggle 10 times offline -> counts as 1 upload write
    // -------------------------------------------------------------
    Map<String, QueueItem> optimizedMap = {};
    for (var item in queue) {
      String dedupKey = "${item.collectionPath}_${item.documentId}";
      
      if (item.operation == QueueOperationType.delete) {
         // A delete completely overrides any previous set/update commands for this doc
         optimizedMap[dedupKey] = item;
      } else {
         if (optimizedMap.containsKey(dedupKey) && optimizedMap[dedupKey]!.operation != QueueOperationType.delete) {
            // Merge data maps to preserve independent field updates across commands
            var mergedData = Map<String, dynamic>.from(optimizedMap[dedupKey]!.data ?? {});
            mergedData.addAll(item.data ?? {});
            
            optimizedMap[dedupKey] = QueueItem(
               id: item.id,
               collectionPath: item.collectionPath,
               documentId: item.documentId,
               operation: QueueOperationType.set, // Elevate to 'set(merge)' to ensure fields merge safely
               data: mergedData,
            );
         } else {
            optimizedMap[dedupKey] = item;
         }
      }
    }

    List<QueueItem> optimizedQueue = optimizedMap.values.toList();
    
    // -------------------------------------------------------------
    // FIREBASE WRITE BATCH EXECUTION
    // -------------------------------------------------------------
    final firestore = FirebaseFirestore.instance;
    List<QueueItem> currentBatchItems = optimizedQueue.take(500).toList();
    WriteBatch batch = firestore.batch();

    for (var item in currentBatchItems) {
      DocumentReference docRef = firestore.collection(item.collectionPath).doc(item.documentId);
      
      switch (item.operation) {
        case QueueOperationType.update:
          batch.update(docRef, item.data ?? {});
          break;
        case QueueOperationType.set:
          batch.set(docRef, item.data ?? {}, SetOptions(merge: true));
          break;
        case QueueOperationType.delete:
          batch.delete(docRef);
          break;
      }
    }

    try {
      // Consumes EXACTLY the deduplicated minimum amount of writes
      await batch.commit();

      // Successfully pushed! Let's clear the local backup.
      // (Using original queue length to drop all raw entries that were just optimized)
      await prefs.remove(_queueKey);
      
      return true;
    } catch (e) {
      print("Network fail: Batch commit aborted. Queue preserved for later retry.");
      return false; 
    }
  }

  Future<List<QueueItem>> _getQueue(SharedPreferences prefs) async {
    String? raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      List<dynamic> jsonList = jsonDecode(raw);
      return jsonList.map((j) => QueueItem.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }
}
