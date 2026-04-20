import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';

class NoteProvider extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final _uuid = const Uuid();

  List<NoteModel> _notes = [];
  List<FolderModel> _folders = [];
  String _selectedFolderId = 'all';
  String _viewMode = 'list';
  bool _isLoading = false;
  bool _lockedFolderUnlocked = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _foldersSub;

  NoteProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadGuestData();
  }

  List<NoteModel> get notes => _notes;
  List<FolderModel> get folders => _folders;
  List<FolderModel> get visibleFolders =>
      _folders.where((f) => !f.isLocked).toList();

  String get selectedFolderId => _selectedFolderId;
  String get viewMode => _viewMode;
  bool get isLoading => _isLoading;
  bool get lockedFolderUnlocked => _lockedFolderUnlocked;

  String get selectedFolderName {
    if (_selectedFolderId == 'all') return 'Semua';
    if (_selectedFolderId == 'trash') return 'Baru Dihapus';
    if (_selectedFolderId == 'locked') return 'Terkunci';

    final folder = _folders.firstWhere(
      (f) => f.id == _selectedFolderId,
      orElse: () => FolderModel(
        id: 'all',
        name: 'Semua',
        userId: '',
        createdAt: DateTime.now(),
      ),
    );
    return folder.name;
  }

  List<NoteModel> get lockedNotes => _notes
      .where((n) => !n.isDeleted && n.type == 'note' && n.isLocked)
      .toList();

  List<NoteModel> get filteredNotes {
    if (_selectedFolderId == 'trash') {
      return _notes.where((n) => n.isDeleted && n.type == 'note').toList();
    }

    if (_selectedFolderId == 'locked') {
      if (!_lockedFolderUnlocked) return [];
      return lockedNotes;
    }

    if (_selectedFolderId == 'all') {
      return _notes
          .where(
            (n) =>
                !n.isDeleted &&
                n.type == 'note' &&
                !n.isLocked,
          )
          .toList();
    }

    return _notes
        .where(
          (n) =>
              !n.isDeleted &&
              n.type == 'note' &&
              !n.isLocked &&
              n.folderId == _selectedFolderId,
        )
        .toList();
  }

  List<NoteModel> get pinnedNotes =>
      filteredNotes.where((n) => n.isPinned).toList();

  List<NoteModel> get unpinnedNotes =>
      filteredNotes.where((n) => !n.isPinned).toList();

  List<NoteModel> get tasks =>
      _notes.where((n) => !n.isDeleted && n.type == 'task').toList();

  void setViewMode(String mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void setFolder(String folderId) {
    final leavingLockedFolder =
        _selectedFolderId == 'locked' && folderId != 'locked';

    if (leavingLockedFolder) {
      _lockedFolderUnlocked = false;
    }

    _selectedFolderId = folderId;
    notifyListeners();
  }

  void unlockLockedFolderSession() {
    _lockedFolderUnlocked = true;
    _selectedFolderId = 'locked';
    notifyListeners();
  }

  void lockLockedFolderSession({bool resetFolder = true}) {
    _lockedFolderUnlocked = false;
    if (resetFolder && _selectedFolderId == 'locked') {
      _selectedFolderId = 'all';
    }
    notifyListeners();
  }

  Future<void> loadNotes() async {
    final uid = _authService.currentUser?.uid;

    _isLoading = true;
    notifyListeners();

    await _notesSub?.cancel();
    await _foldersSub?.cancel();

    if (uid == null) {
      await _loadGuestData();
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _notesSub = _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        _notes = snapshot.docs
            .map((doc) => NoteModel.fromMap(doc.data()))
            .toList();
        notifyListeners();
      });

      _foldersSub = _firestore
          .collection('users')
          .doc(uid)
          .collection('folders')
          .snapshots()
          .listen((snapshot) {
        _folders = snapshot.docs
            .map((doc) => FolderModel.fromMap(doc.data()))
            .toList();
        notifyListeners();
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadGuestData() async {
    final noteMaps = LocalStorageService.notesBox.values.toList();
    final folderMaps = LocalStorageService.foldersBox.values.toList();

    _notes = noteMaps
        .map((e) => NoteModel.fromLocalMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _folders = folderMaps
        .map((e) => FolderModel.fromLocalMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    notifyListeners();
  }

  Future<void> _persistGuestNotes() async {
    final box = LocalStorageService.notesBox;
    await box.clear();

    for (final note in _notes) {
      await box.put(note.id, note.toLocalMap());
    }
  }

  Future<void> _persistGuestFolders() async {
    final box = LocalStorageService.foldersBox;
    await box.clear();

    for (final folder in _folders) {
      await box.put(folder.id, folder.toLocalMap());
    }
  }

  Future<NoteModel> createNote({
    String type = 'note',
    String folderId = 'all',
  }) async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    final id = _uuid.v4();
    final now = DateTime.now();

    final note = NoteModel(
      id: id,
      title: '',
      content: '[]',
      folderId: folderId == 'all' ? 'all' : folderId,
      userId: uid,
      createdAt: now,
      updatedAt: now,
      type: type,
    );

    if (uid != 'guest') {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(id)
          .set(note.toMap());
    } else {
      _notes.insert(0, note);
      await _persistGuestNotes();
      notifyListeners();
    }

    return note;
  }

  Future<void> saveNote(NoteModel note) async {
    final uid = _authService.currentUser?.uid;
    final updated = note.copyWith(updatedAt: DateTime.now());

    if (uid == null) {
      final index = _notes.indexWhere((n) => n.id == updated.id);
      if (index != -1) {
        _notes[index] = updated;
      } else {
        _notes.insert(0, updated);
      }

      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _persistGuestNotes();
      notifyListeners();
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(note.id)
        .set(updated.toMap());
  }

  Future<void> deleteNote(String noteId) async {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      final index = _notes.indexWhere((n) => n.id == noteId);
      if (index != -1) {
        _notes[index] = _notes[index].copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        );
        await _persistGuestNotes();
        notifyListeners();
      }
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .update({'isDeleted': true, 'updatedAt': Timestamp.now()});
  }

  Future<void> restoreNote(String noteId) async {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      final index = _notes.indexWhere((n) => n.id == noteId);
      if (index != -1) {
        _notes[index] = _notes[index].copyWith(
          isDeleted: false,
          updatedAt: DateTime.now(),
        );
        await _persistGuestNotes();
        notifyListeners();
      }
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .update({'isDeleted': false, 'updatedAt': Timestamp.now()});
  }

  Future<void> permanentDelete(String noteId) async {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      _notes.removeWhere((n) => n.id == noteId);
      await _persistGuestNotes();
      notifyListeners();
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .delete();
  }

  Future<void> togglePin(NoteModel note) async {
    await saveNote(note.copyWith(isPinned: !note.isPinned));
  }

  Future<void> createFolder(String name, {int colorIndex = 0}) async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    final id = _uuid.v4();

    final folder = FolderModel(
      id: id,
      name: name,
      userId: uid,
      colorIndex: colorIndex,
      createdAt: DateTime.now(),
    );

    if (uid == 'guest') {
      _folders.add(folder);
      await _persistGuestFolders();
      notifyListeners();
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('folders')
        .doc(id)
        .set(folder.toMap());
  }

  Future<void> emptyTrash() async {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      _notes.removeWhere((n) => n.isDeleted);
      await _persistGuestNotes();
      notifyListeners();
      return;
    }

    final trashedNotes = _notes.where((n) => n.isDeleted).toList();
    final batch = _firestore.batch();

    for (final note in trashedNotes) {
      final ref = _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(note.id);
      batch.delete(ref);
    }

    await batch.commit();
  }

  List<NoteModel> searchNotes(String query) {
    if (query.isEmpty) return filteredNotes;
    return filteredNotes
        .where(
          (n) =>
              n.title.toLowerCase().contains(query.toLowerCase()) ||
              n.content.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_lockedFolderUnlocked || _selectedFolderId == 'locked') {
        _lockedFolderUnlocked = false;
        if (_selectedFolderId == 'locked') {
          _selectedFolderId = 'all';
        }
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesSub?.cancel();
    _foldersSub?.cancel();
    super.dispose();
  }
}