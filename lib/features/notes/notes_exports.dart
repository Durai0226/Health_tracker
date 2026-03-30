/// Evernote-Style Notes Feature Exports
/// Dark theme with Lime Green (#CDDC39) accent

// Theme
export 'theme/evernote_theme.dart';

// Models
export 'data/models/note_model.dart';
export 'data/models/notebook_model.dart';
export 'data/models/page_model.dart';
export 'data/models/stroke_model.dart';
export 'data/models/audio_clip_model.dart';
export 'data/models/tag_model.dart';
export 'data/models/folder_model.dart';

// Services
export 'data/services/notes_service.dart';
export 'data/services/notebook_service.dart';

// Screens - Main entry points
export 'screens/notes_main_screen.dart';
export 'presentation/screens/premium_notes_screen.dart';
export 'presentation/screens/premium_note_editor_screen.dart';
export 'presentation/screens/notes_notebooks_screen.dart';
export 'presentation/screens/notes_tags_screen.dart';
export 'presentation/screens/notes_tasks_screen.dart';
export 'presentation/screens/notes_search_screen.dart';
export 'presentation/screens/notes_settings_screen.dart';

// Widgets - Cards
export 'presentation/widgets/note_card.dart';
export 'presentation/widgets/notes_header.dart';
export 'presentation/widgets/category_chips.dart';
export 'presentation/widgets/notes_search_bar.dart';

// Canvas widgets (for notebook/drawing feature)
export 'presentation/widgets/canvas/drawing_canvas.dart';
export 'presentation/widgets/canvas/canvas_controller.dart';
export 'presentation/widgets/canvas/stroke_painter.dart';
export 'presentation/widgets/canvas/paper_background.dart';

// Tools widgets
export 'presentation/widgets/tools/pen_toolbar.dart';
export 'presentation/widgets/tools/page_navigator.dart';
export 'presentation/widgets/tools/template_picker.dart';
export 'presentation/widgets/tools/audio_recorder_widget.dart';
