import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';

class RoomPersistenceService {
  static const String _key = 'iris_rooms';

  /// Save a list of rooms to SharedPreferences
  Future<void> saveRooms(List<Room> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(rooms.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Load rooms from SharedPreferences
  Future<List<Room>> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_key);
    if (encoded == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(encoded);
      return decoded.map((item) => Room.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Apply heuristics to a room ID to generate default metadata
  Room generateDefaultRoom(String roomId) {
    String building = 'Other';
    String normalizedRoom = roomId.trim().toUpperCase();
    
    // Improved naming logic: Map "C 1.1", "C-1", "CS-1", etc. to "C Block"
    final blockMatch = RegExp(r'^([A-E|W|M|S])[\s\-0-9]?').firstMatch(normalizedRoom);
    
    if (blockMatch != null) {
      String prefix = blockMatch.group(1)!;
      switch (prefix) {
        case 'A': building = 'A Block'; break;
        case 'B': building = 'B Block'; break;
        case 'C': building = 'C Block'; break;
        case 'D': building = 'D Block'; break;
        case 'E': building = 'E Block'; break;
        case 'W': building = 'Workshop Block'; break;
        case 'M': building = 'Main Building'; break;
        case 'S': building = 'Seminar Block'; break;
      }
    } else if (normalizedRoom.startsWith('CS') || normalizedRoom.startsWith('C-')) {
      building = 'C Block';
    } else if (normalizedRoom.startsWith('ME') || normalizedRoom.startsWith('A-')) {
      building = normalizedRoom.contains('LAB') ? 'Workshop Block' : 'A Block';
    } else if (normalizedRoom.startsWith('BE') || normalizedRoom.startsWith('B-')) {
      building = 'B Block';
    } else if (normalizedRoom.contains('CLAB') || normalizedRoom.contains('C LAB')) {
      final match = RegExp(r'(\d+)').firstMatch(normalizedRoom);
      if (match != null) {
        int labNum = int.parse(match.group(1)!);
        if (labNum == 9 || labNum == 10) building = 'A Block';
        else if (labNum == 14) building = 'B Block';
        else if ((labNum >= 1 && labNum <= 8) || (labNum >= 11 && labNum <= 13)) building = 'C Block';
      }
    } else if (normalizedRoom.contains('LIB') || normalizedRoom.contains('LIBRARY')) {
      building = 'A Block';
    } else if (normalizedRoom.contains('AUDI') || normalizedRoom.contains('AUDITORIUM')) {
      building = 'Main Building';
    }

    final isLab = normalizedRoom.contains('LAB');
    final amenities = isLab 
        ? ['PC', 'Internet', 'AC', 'Whiteboard'] 
        : ['Whiteboard', 'AC'];

    return Room(
      id: roomId,
      building: building,
      capacity: isLab ? 30 : 40,
      amenities: amenities,
      registeredAt: DateTime.now(),
    );
  }
}
