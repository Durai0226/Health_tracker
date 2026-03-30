import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../data/question_bank_data.dart';

/// Question card widget for practice and tests
class QuestionCard extends StatefulWidget {
  final QuestionBankItem question;
  final int questionNumber;
  final int? selectedOption;
  final bool showAnswer;
  final bool isBookmarked;
  final ValueChanged<int>? onOptionSelected;
  final VoidCallback? onBookmark;
  final VoidCallback? onReport;

  const QuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    this.selectedOption,
    this.showAnswer = false,
    this.isBookmarked = false,
    this.onOptionSelected,
    this.onBookmark,
    this.onReport,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    if (widget.showAnswer) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showAnswer && !oldWidget.showAnswer) {
      _controller.forward();
    } else if (!widget.showAnswer && oldWidget.showAnswer) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getDifficultyColor() {
    switch (widget.question.difficulty) {
      case 'easy':
        return ExamPrepTheme.success;
      case 'medium':
        return ExamPrepTheme.warning;
      case 'hard':
        return ExamPrepTheme.error;
      default:
        return ExamPrepTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final difficultyColor = _getDifficultyColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ExamPrepTheme.primary.withOpacity(0.1),
                  ExamPrepTheme.primaryLight.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: ExamPrepTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Q${widget.questionNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: difficultyColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.question.difficulty.toUpperCase(),
                    style: TextStyle(
                      color: difficultyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onBookmark,
                  icon: Icon(
                    widget.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    color: widget.isBookmarked ? ExamPrepTheme.warning : Colors.grey,
                  ),
                  iconSize: 22,
                ),
                IconButton(
                  onPressed: widget.onReport,
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  color: Colors.grey,
                  iconSize: 22,
                ),
              ],
            ),
          ),

          // Question text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.question.question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.5,
              ),
            ),
          ),

          // Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(
                widget.question.options.length,
                (index) => _buildOption(context, index),
              ),
            ),
          ),

          // Explanation (shown when answer is revealed)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  heightFactor: _controller.value,
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ExamPrepTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ExamPrepTheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: ExamPrepTheme.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Explanation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ExamPrepTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.question.explanation,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = widget.selectedOption == index;
    final isCorrect = index == widget.question.correctIndex;
    final showResult = widget.showAnswer;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (showResult) {
      if (isCorrect) {
        backgroundColor = ExamPrepTheme.success.withOpacity(0.15);
        borderColor = ExamPrepTheme.success;
        textColor = ExamPrepTheme.success;
      } else if (isSelected && !isCorrect) {
        backgroundColor = ExamPrepTheme.error.withOpacity(0.15);
        borderColor = ExamPrepTheme.error;
        textColor = ExamPrepTheme.error;
      } else {
        backgroundColor = Colors.transparent;
        borderColor = isDark ? Colors.white24 : Colors.grey.shade300;
        textColor = isDark ? Colors.white70 : Colors.black54;
      }
    } else {
      if (isSelected) {
        backgroundColor = ExamPrepTheme.primary.withOpacity(0.15);
        borderColor = ExamPrepTheme.primary;
        textColor = ExamPrepTheme.primary;
      } else {
        backgroundColor = Colors.transparent;
        borderColor = isDark ? Colors.white24 : Colors.grey.shade300;
        textColor = isDark ? Colors.white70 : Colors.black87;
      }
    }

    return GestureDetector(
      onTap: widget.showAnswer
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onOptionSelected?.call(index);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected || (showResult && isCorrect)
                    ? (showResult
                        ? (isCorrect ? ExamPrepTheme.success : ExamPrepTheme.error)
                        : ExamPrepTheme.primary)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected || (showResult && isCorrect)
                      ? Colors.transparent
                      : borderColor,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: showResult && (isCorrect || isSelected)
                    ? Icon(
                        isCorrect ? Icons.check : Icons.close,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        String.fromCharCode(65 + index), // A, B, C, D
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.question.options[index],
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: isSelected || (showResult && isCorrect)
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact question card for list view
class QuestionListTile extends StatelessWidget {
  final QuestionBankItem question;
  final int index;
  final bool isAttempted;
  final bool isCorrect;
  final VoidCallback? onTap;

  const QuestionListTile({
    super.key,
    required this.question,
    required this.index,
    this.isAttempted = false,
    this.isCorrect = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isAttempted
              ? (isCorrect ? ExamPrepTheme.success : ExamPrepTheme.error)
                  .withOpacity(0.2)
              : ExamPrepTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: isAttempted
              ? Icon(
                  isCorrect ? Icons.check : Icons.close,
                  color: isCorrect ? ExamPrepTheme.success : ExamPrepTheme.error,
                  size: 20,
                )
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ExamPrepTheme.primary,
                  ),
                ),
        ),
      ),
      title: Text(
        question.question,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Row(
        children: [
          _buildTag(question.difficulty, _getDifficultyColor(question.difficulty)),
          const SizedBox(width: 8),
          _buildTag(question.topicId, ExamPrepTheme.primary),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white38 : Colors.grey,
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return ExamPrepTheme.success;
      case 'medium':
        return ExamPrepTheme.warning;
      case 'hard':
        return ExamPrepTheme.error;
      default:
        return ExamPrepTheme.primary;
    }
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
