import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/note.dart';

class ApiService {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';
  static const Duration timeoutDuration = Duration(seconds: 10);

  Future<List<Note>> getNotes({
    int page = 1,
    int limit = 20,
    String? searchQuery,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/posts');
      
      final response = await http
          .get(uri)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Применяем пагинацию на клиенте (т.к. JSONPlaceholder не поддерживает)
        int startIndex = (page - 1) * limit;
        int endIndex = startIndex + limit;
        
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final filtered = data.where((item) {
            final title = item['title']?.toString().toLowerCase() ?? '';
            final body = item['body']?.toString().toLowerCase() ?? '';
            final query = searchQuery.toLowerCase();
            return title.contains(query) || body.contains(query);
          }).toList();
          
          final paginated = filtered.sublist(
            startIndex.clamp(0, filtered.length),
            endIndex.clamp(0, filtered.length),
          );
          
          return paginated.map((json) => Note.fromJson(json)).toList();
        } else {
          final paginated = data.sublist(
            startIndex.clamp(0, data.length),
            endIndex.clamp(0, data.length),
          );
          
          return paginated.map((json) => Note.fromJson(json)).toList();
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка сети: $e');
    }
  }

  Future<Note> getNoteById(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/posts/$id'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return Note.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('Запись не найдена');
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Note> createNote(Note note) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/posts'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(note.toJson()),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 201) {
        return Note.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Ошибка создания: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Note> updateNote(Note note) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/posts/${note.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(note.toJson()),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return Note.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Ошибка обновления: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<bool> deleteNote(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/posts/$id'))
          .timeout(timeoutDuration);

      return response.statusCode == 200;
    } on TimeoutException {
      throw Exception('Превышено время ожидания');
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }
}