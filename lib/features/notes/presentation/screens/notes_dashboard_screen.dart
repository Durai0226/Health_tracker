import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';
import '../../data/models/folder_model.dart';
import '../../data/repositories/notes_repository.dart';
import '../widgets/note_card.dart';
import '../widgets/folder_card.dart';
import 'note_editor_screen.dart';
import '../delegates/notes_search_delegate.dart';
import '../../../backup/presentation/screens/backup_settings_screen.dart';

class NotesDashboardScreen extends StatefulWidget {
  const NotesDashboardScreen({super.key});

  @override
  State<NotesDashboardScreen> createState() => _NotesDashboardScreenState();
}

class _NotesDashboardScreenState extends State<NotesDashboardScreen> {
  final NotesRepository _repository = NotesRepository();

  String? _currentFolderId;
  
  // Filter State
  String _sortBy = 'updated'; // 'updated', 'created', 'title'
  bool _sortAscending = false;
  bool _showPinnedOnly = false;
  bool _showRemindersOnly = false;

  @override
  void initState() {
    super.initState();
  }

  void _navigateToFolder(String folderId) {
    setState(() {
      _currentFolderId = folderId;
    });
  }

  void _navigateUp() {
    if (_currentFolderId == null) return;
    
    // Find current folder to get parent
    final currentFolder = Hive.box<FolderModel>('folders').get(_currentFolderId);
    setState(() {
      _currentFolderId = currentFolder?.parentId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_currentFolderId == null ? "My Notes" : (Hive.box<FolderModel>('folders').get(_currentFolderId)?.name ?? "Folder")),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentFolderId != null)
            IconButton(
              icon: const Icon(Icons.arrow_upward_rounded),
              onPressed: _navigateUp,
            ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              showSearch(
                context: context,
                delegate: NotesSearchDelegate(
                   notes: _repository.getAllNotes(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
               if (value == 'settings') {
                 // Open Backup/Settings Screen
                 // We don't have a main settings screen yet, so we go directly to Backup for now 
                 // or we can wrap it. Let's send to BackupSettingsScreen.
                 await Navigator.push(
                   context,
                   MaterialPageRoute(builder: (_) => const BackupSettingsScreen()),
                 );
                 // Refresh if restore happened? The app might need restart.
               }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text("Settings", style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folders Section
            ValueListenableBuilder<Box<FolderModel>>(
              valueListenable: _repository.foldersListenable,
              builder: (context, box, _) {
                final allFolders = box.values.toList();
                final folders = allFolders.where((f) => f.parentId == _currentFolderId).toList();
                
                if (folders.isEmpty && _currentFolderId == null) {
                  // Only show 'Add Folder' if at root and empty? 
                  // or always show add folder?
                  return Column(
                    children: [
                      _buildAddFolderButton(),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Folders",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Manage folders
                          },
                          child: const Text("Edit"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: folders.length + 1, // +1 for "Add Folder"
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildAddFolderCard();
                          }
                          return GestureDetector(
                            onTap: () => _navigateToFolder(folders[index - 1].id),
                            child: FolderCard(folder: folders[index - 1]),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // Recent Notes Section
            Text(
              "Recent Notes",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ValueListenableBuilder<Box<NoteModel>>(
              valueListenable: _repository.notesListenable,
              builder: (context, box, _) {
                final allNotes = box.values.toList();
                final notes = allNotes.where((n) => n.folderId == _currentFolderId).toList();

                // Filtering Logic
                notes.sort((a, b) {
                  int comparison;
                  
                  // Primary Sort: Pinned
                  if (a.isPinned != b.isPinned) {
                     return a.isPinned ? -1 : 1; 
                  }
                  
                  // Secondary Sort: Selected Criteria
                  switch (_sortBy) {
                    case 'title':
                      comparison = a.title.compareTo(b.title);
                      break;
                    case 'created':
                      comparison = a.createdAt.compareTo(b.createdAt);
                      break;
                    case 'updated':
                    default:
                      comparison = a.updatedAt.compareTo(b.updatedAt);
                      break;
                  }
                  
                  return _sortAscending ? comparison : -comparison;
                });
                
                // Filtering
                if (_showPinnedOnly) {
                   notes.retainWhere((n) => n.isPinned);
                }
                
                if (_showRemindersOnly) {
                   notes.retainWhere((n) => n.reminderId != null);
                }

                if (notes.isEmpty) {
                  String message = "No notes here yet";
                  IconData icon = Icons.note_add_outlined;
                  
                  if (_showPinnedOnly || _showRemindersOnly) {
                     message = "No matching notes found";
                     icon = Icons.filter_list_off_rounded;
                  } else if (_currentFolderId != null) {
                     message = "This folder is empty";
                     icon = Icons.folder_open_rounded;
                  }

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 64, color: AppColors.textLight.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            message,
                            style: const TextStyle(color: AppColors.textLight, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          if (!_showPinnedOnly && !_showRemindersOnly)
                          TextButton(
                            onPressed: () {
                               Navigator.of(context).push(
                                 MaterialPageRoute(builder: (_) => NoteEditorScreen(
                                   folderId: _currentFolderId,
                                 )),
                               );
                            },
                            child: const Text("Create a note"),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return MasonryGridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    return NoteCard(note: notes[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
             Navigator.of(context).push(
               MaterialPageRoute(builder: (_) => NoteEditorScreen(
                 folderId: _currentFolderId,
               )),
             );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Widget _buildAddFolderCard() {
    return GestureDetector(
      onTap: _showCreateFolderDialog,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.create_new_folder_rounded, color: AppColors.primary, size: 32),
            SizedBox(height: 8),
            Text(
              "New",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFolderButton() {
    return GestureDetector(
        onTap: _showCreateFolderDialog,
        child: Row(
            children: const [
                Icon(Icons.create_new_folder_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                    "Create Folder",
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                    ),
                ),
            ],
        ),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Folder"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Folder Name",
            filled: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                // Pass current folder as parent
                await _repository.createFolder(controller.text, parentId: _currentFolderId);
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (context, setStateSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text("Filter & Sort", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                     TextButton(
                       onPressed: () {
                          setState(() {
                             _sortBy = 'updated';
                             _sortAscending = false;
                             _showPinnedOnly = false;
                             _showRemindersOnly = false;
                          });
                          setStateSheet(() {});
                       },
                       child: const Text("Reset"),
                     ),
                   ],
                ),
                const SizedBox(height: 16),
                
                const Text("Sort By", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildSortChip(setStateSheet, 'updated', 'Date Modified'),
                    _buildSortChip(setStateSheet, 'created', 'Date Created'),
                    _buildSortChip(setStateSheet, 'title', 'Title'),
                  ],
                ),
                const SizedBox(height: 16),
                
                const Text("Order", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text("Descending"),
                        value: false,
                        groupValue: _sortAscending,
                        onChanged: (v) {
                          setState(() => _sortAscending = v!);
                          setStateSheet(() {});
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text("Ascending"),
                        value: true,
                        groupValue: _sortAscending,
                        onChanged: (v) {
                           setState(() => _sortAscending = v!);
                           setStateSheet(() {});
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Text("Filter", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                SwitchListTile(
                  title: const Text("Only Pinned"),
                  value: _showPinnedOnly,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) {
                     setState(() => _showPinnedOnly = v);
                     setStateSheet(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text("Has Reminders"),
                  value: _showRemindersOnly,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) {
                     setState(() => _showRemindersOnly = v);
                     setStateSheet(() {});
                  },
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildSortChip(StateSetter setStateSheet, String value, String label) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
           setState(() => _sortBy = value);
           setStateSheet(() {});
        }
      },
    );
  }
}
