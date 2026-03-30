import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/stroke_model.dart';
import '../../../data/models/page_model.dart';

/// Controller for managing canvas state, strokes, and undo/redo functionality
class CanvasController extends ChangeNotifier {
  final _uuid = const Uuid();
  
  // Current page being edited
  PageModel? _currentPage;
  
  // All strokes on the canvas
  List<StrokeModel> _strokes = [];
  
  // Current stroke being drawn
  StrokeModel? _currentStroke;
  
  // Undo/Redo stacks
  final List<List<StrokeModel>> _undoStack = [];
  final List<List<StrokeModel>> _redoStack = [];
  static const int _maxUndoSteps = 50;
  
  // Drawing settings
  DrawingTool _currentTool = DrawingTool.pen;
  String _currentColor = '#1A1D26';
  double _currentStrokeWidth = 3.0;
  
  // Audio recording state
  String? _activeAudioClipId;
  bool _isRecording = false;
  
  // Canvas state
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  bool _isDrawing = false;
  bool _hasChanges = false;

  // Getters
  PageModel? get currentPage => _currentPage;
  List<StrokeModel> get strokes => List.unmodifiable(_strokes);
  StrokeModel? get currentStroke => _currentStroke;
  DrawingTool get currentTool => _currentTool;
  String get currentColor => _currentColor;
  double get currentStrokeWidth => _currentStrokeWidth;
  double get zoomLevel => _zoomLevel;
  Offset get panOffset => _panOffset;
  bool get isDrawing => _isDrawing;
  bool get hasChanges => _hasChanges;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isRecording => _isRecording;
  String? get activeAudioClipId => _activeAudioClipId;

  /// Initialize controller with a page
  void initWithPage(PageModel page) {
    _currentPage = page;
    _strokes = List.from(page.strokes);
    _undoStack.clear();
    _redoStack.clear();
    _hasChanges = false;
    notifyListeners();
  }

  /// Set the current drawing tool
  void setTool(DrawingTool tool) {
    _currentTool = tool;
    notifyListeners();
  }

  /// Set the current stroke color
  void setColor(String color) {
    _currentColor = color;
    notifyListeners();
  }

  /// Set the current stroke width
  void setStrokeWidth(double width) {
    _currentStrokeWidth = width;
    notifyListeners();
  }

  /// Start a new stroke
  void startStroke(Offset position, {double pressure = 1.0}) {
    _saveUndoState();
    _isDrawing = true;
    
    _currentStroke = StrokeModel.create(
      id: _uuid.v4(),
      color: _currentTool == DrawingTool.eraser ? '#FFFFFF' : _currentColor,
      strokeWidth: _currentTool == DrawingTool.eraser ? 30.0 : _currentStrokeWidth,
      tool: _currentTool,
      linkedAudioClipId: _activeAudioClipId,
    );
    
    _currentStroke = _currentStroke!.addPoint(
      StrokePoint.fromOffset(position, pressure: pressure),
    );
    
    notifyListeners();
  }

  /// Continue the current stroke
  void updateStroke(Offset position, {double pressure = 1.0}) {
    if (_currentStroke == null || !_isDrawing) return;
    
    _currentStroke = _currentStroke!.addPoint(
      StrokePoint.fromOffset(position, pressure: pressure),
    );
    
    notifyListeners();
  }

  /// End the current stroke
  void endStroke() {
    if (_currentStroke == null) return;
    
    _isDrawing = false;
    
    if (_currentStroke!.isValid) {
      if (_currentTool == DrawingTool.eraser) {
        _eraseStrokesAt(_currentStroke!);
      } else {
        _strokes.add(_currentStroke!);
      }
      _hasChanges = true;
    }
    
    _currentStroke = null;
    _redoStack.clear(); // Clear redo when new action is taken
    notifyListeners();
  }

  /// Erase strokes that intersect with eraser path
  void _eraseStrokesAt(StrokeModel eraserStroke) {
    final eraserBounds = eraserStroke.boundingBox;
    
    _strokes = _strokes.where((stroke) {
      final strokeBounds = stroke.boundingBox;
      // Simple bounds intersection check
      return !strokeBounds.overlaps(eraserBounds.inflate(eraserStroke.strokeWidth));
    }).toList();
  }

  /// Save current state for undo
  void _saveUndoState() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo the last action
  void undo() {
    if (!canUndo) return;
    
    _redoStack.add(List.from(_strokes));
    _strokes = _undoStack.removeLast();
    _hasChanges = true;
    notifyListeners();
  }

  /// Redo the last undone action
  void redo() {
    if (!canRedo) return;
    
    _undoStack.add(List.from(_strokes));
    _strokes = _redoStack.removeLast();
    _hasChanges = true;
    notifyListeners();
  }

  /// Clear all strokes
  void clear() {
    if (_strokes.isEmpty) return;
    
    _saveUndoState();
    _strokes.clear();
    _hasChanges = true;
    _redoStack.clear();
    notifyListeners();
  }

  /// Set zoom level
  void setZoom(double zoom) {
    _zoomLevel = zoom.clamp(0.5, 3.0);
    notifyListeners();
  }

  /// Set pan offset
  void setPan(Offset offset) {
    _panOffset = offset;
    notifyListeners();
  }

  /// Reset zoom and pan
  void resetView() {
    _zoomLevel = 1.0;
    _panOffset = Offset.zero;
    notifyListeners();
  }

  /// Start audio recording
  void startRecording(String audioClipId) {
    _activeAudioClipId = audioClipId;
    _isRecording = true;
    notifyListeners();
  }

  /// Stop audio recording
  void stopRecording() {
    _activeAudioClipId = null;
    _isRecording = false;
    notifyListeners();
  }

  /// Get updated page model with current strokes
  PageModel? getUpdatedPage() {
    if (_currentPage == null) return null;
    
    return _currentPage!.copyWith(
      strokes: _strokes,
      updatedAt: DateTime.now(),
      scrollOffsetX: _panOffset.dx,
      scrollOffsetY: _panOffset.dy,
      zoomLevel: _zoomLevel,
    );
  }

  /// Mark changes as saved
  void markSaved() {
    _hasChanges = false;
    notifyListeners();
  }

  /// Delete a specific stroke by ID
  void deleteStroke(String strokeId) {
    _saveUndoState();
    _strokes.removeWhere((s) => s.id == strokeId);
    _hasChanges = true;
    _redoStack.clear();
    notifyListeners();
  }

  /// Select strokes within a rectangle
  List<StrokeModel> selectStrokesInRect(Rect rect) {
    return _strokes.where((stroke) {
      return stroke.boundingBox.overlaps(rect);
    }).toList();
  }

  /// Get strokes linked to an audio clip
  List<StrokeModel> getStrokesForAudioClip(String audioClipId) {
    return _strokes.where((s) => s.linkedAudioClipId == audioClipId).toList();
  }

  @override
  void dispose() {
    _undoStack.clear();
    _redoStack.clear();
    super.dispose();
  }
}
