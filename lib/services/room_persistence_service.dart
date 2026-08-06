import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';

class RoomLocationDetails {
  final String block;
  final String floor;
  final String roomName;
  final int floorNumber;

  const RoomLocationDetails({
    required this.block,
    required this.floor,
    required this.roomName,
    required this.floorNumber,
  });

  String get formattedLocation => '$block • $floor • $roomName';
}

class RoomPersistenceService {
  static const String _key = 'iris_rooms';

  /// Parse any COMSATS room ID (e.g. A2.4, B2, C1.1, C-204) into Block, Floor, and Room
  static RoomLocationDetails parseRoomCode(String roomId) {
    final raw = roomId.trim().toUpperCase();
    String block = 'Other';
    String floor = 'Ground Floor';
    int floorNumber = 0;
    String roomName = raw;

    final blockMatch = RegExp(r'^([A-E|W|M|S])').firstMatch(raw);
    if (blockMatch != null) {
      final letter = blockMatch.group(1)!;
      switch (letter) {
        case 'A': block = 'A Block'; break;
        case 'B': block = 'B Block'; break;
        case 'C': block = 'C Block'; break;
        case 'D': block = 'D Block'; break;
        case 'E': block = 'E Block'; break;
        case 'W': block = 'Workshop Block'; break;
        case 'M': block = 'Main Building'; break;
        case 'S': block = 'Seminar Block'; break;
      }
    } else if (raw.startsWith('CS') || raw.startsWith('C-')) {
      block = 'C Block';
    } else if (raw.startsWith('ME')) {
      block = 'Workshop Block';
    } else if (raw.startsWith('BE')) {
      block = 'B Block';
    }

    // Format 1: Dot format e.g. A1.5, A2.4, B0.2, C1.12
    final dotMatch = RegExp(r'^[A-E|W|M|S]\s*(\d)\.(\d+)$').firstMatch(raw);
    if (dotMatch != null) {
      floorNumber = int.parse(dotMatch.group(1)!);
      final roomNum = dotMatch.group(2)!;
      floor = floorNumber == 0 ? 'Ground Floor' : '${floorNumber}${_floorSuffix(floorNumber)} Floor';
      roomName = 'Room $roomNum';
    } else {
      // Format 2: Dash format e.g. C-204, A-101
      final dashMatch = RegExp(r'^[A-E]\-?(\d)(\d{2})$').firstMatch(raw);
      if (dashMatch != null) {
        floorNumber = int.parse(dashMatch.group(1)!);
        final roomNum = int.parse(dashMatch.group(2)!);
        floor = floorNumber == 0 ? 'Ground Floor' : '${floorNumber}${_floorSuffix(floorNumber)} Floor';
        roomName = 'Room $roomNum';
      } else {
        // Format 3: Single digit format e.g. B2 (B Block Ground Floor Room 2), A5 (A Block Ground Floor Room 5)
        final singleDigitMatch = RegExp(r'^[A-E](\d)$').firstMatch(raw);
        if (singleDigitMatch != null) {
          floorNumber = 0; // Ground Floor (no zero in room numbers)
          final roomNum = singleDigitMatch.group(1)!;
          floor = 'Ground Floor';
          roomName = 'Room $roomNum';
        }
      }
    }

    if (raw.contains('LAB')) {
      roomName = raw;
    }

    return RoomLocationDetails(
      block: block,
      floor: floor,
      roomName: roomName,
      floorNumber: floorNumber,
    );
  }

  static String _floorSuffix(int n) {
    if (n == 1) return 'st';
    if (n == 2) return 'nd';
    if (n == 3) return 'rd';
    return 'th';
  }

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
    final details = parseRoomCode(roomId);
    final normalizedRoom = roomId.trim().toUpperCase();
    final isLab = normalizedRoom.contains('LAB');
    final amenities = isLab 
        ? ['PC', 'Internet', 'AC', 'Whiteboard'] 
        : ['Whiteboard', 'AC'];

    return Room(
      id: roomId,
      building: details.block,
      capacity: isLab ? 30 : 40,
      amenities: amenities,
      registeredAt: DateTime.now(),
    );
  }
}
