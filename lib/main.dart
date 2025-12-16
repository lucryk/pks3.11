import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'models/note.dart';
import 'widgets/loading_indicator.dart';
import 'dart:async';  // Добавьте эту строку в самом верху
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Notes Feed',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const NotesListPage(),
    );
  }
}

class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  final ApiService _apiService = ApiService();
  List<Note> _notes = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String _error = '';
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _hasMore = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes({bool reset = false}) async {
    if (_isLoading) return;
    
    if (reset) {
      setState(() {
        _currentPage = 1;
        _notes.clear();
        _hasMore = true;
        _isInitialLoading = true;
      });
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final newNotes = await _apiService.getNotes(
        page: _currentPage,
        limit: _itemsPerPage,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      setState(() {
        if (reset) {
          _notes = newNotes;
        } else {
          _notes.addAll(newNotes);
        }
        _hasMore = newNotes.isNotEmpty;
        if (_hasMore) _currentPage++;
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadNotes(reset: true);
  }

  Future<void> _loadMore() async {
    if (_hasMore && !_isLoading) {
      await _loadNotes();
    }
  }

  Future<void> _createNote() async {
    final result = await showDialog<Note>(
      context: context,
      builder: (context) => NoteEditDialog(),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Отправляем запрос на создание
        final createdNote = await _apiService.createNote(result);
        
        // Добавляем в начало списка (имитация успешного создания)
        setState(() {
          _notes.insert(0, createdNote);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Запись создана (демо)'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Отмена',
                onPressed: () {
                  setState(() {
                    _notes.removeAt(0);
                  });
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка создания: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteNote(int index) async {
    final noteToDelete = _notes[index];
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Показываем Snackbar с отменой
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Удаляем "${noteToDelete.title}"'),
        action: SnackBarAction(
          label: 'Отмена',
          onPressed: () {
            // Отмена удаления
          },
        ),
      ),
    );

    try {
      // Отправляем запрос на удаление
      await _apiService.deleteNote(noteToDelete.id);
      
      // Удаляем из списка
      setState(() {
        _notes.removeAt(index);
      });
      
      // Показываем подтверждение
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Запись удалена (демо)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Ошибка удаления: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onSearchChanged(String value) {
    // Дебаунс 300мс
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadNotes(reset: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Notes Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          // Поле поиска
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по заголовку...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadNotes(reset: true);
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Статус загрузки/ошибки
          if (_isInitialLoading)
            const Expanded(child: LoadingIndicator(message: 'Загружаем записи...'))
          else if (_error.isNotEmpty && _notes.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  itemCount: _notes.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _notes.length) {
                      // Индикатор загрузки внизу
                      if (_hasMore) {
                        _loadMore();
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return const SizedBox();
                    }

                    final note = _notes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(note.id.toString()),
                        ),
                        title: Text(
                          note.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          note.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteNote(index),
                          tooltip: 'Удалить',
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NoteDetailsPage(
                                noteId: note.id,
                                apiService: _apiService,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        child: const Icon(Icons.add),
        tooltip: 'Создать запись',
      ),
    );
  }
}

class NoteDetailsPage extends StatefulWidget {
  final int noteId;
  final ApiService apiService;

  const NoteDetailsPage({
    super.key,
    required this.noteId,
    required this.apiService,
  });

  @override
  State<NoteDetailsPage> createState() => _NoteDetailsPageState();
}

class _NoteDetailsPageState extends State<NoteDetailsPage> {
  late Future<Note> _noteFuture;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _noteFuture = _loadNote();
  }

  Future<Note> _loadNote() async {
    try {
      return await widget.apiService.getNoteById(widget.noteId);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _noteFuture = _loadNote();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Запись #${widget.noteId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<Note>(
        future: _noteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Загружаем запись...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final note = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text('ID: ${note.id}'),
                      backgroundColor: Colors.blue[100],
                    ),
                    Chip(
                      label: Text('User: ${note.userId}'),
                      backgroundColor: Colors.green[100],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      note.body,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Назад'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Демо редактирования
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Редактирование (демо)'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Редактировать'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NoteEditDialog extends StatefulWidget {
  const NoteEditDialog({super.key});

  @override
  State<NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<NoteEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая запись'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Заголовок',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите заголовок';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Текст',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите текст';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final note = Note(
                id: 0, // Новый ID будет присвоен сервером
                title: _titleController.text,
                body: _bodyController.text,
                userId: 1,
              );
              Navigator.pop(context, note);
            }
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}