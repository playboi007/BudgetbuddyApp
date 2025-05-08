import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data models/course_model.dart';
import '../services/course_provider.dart';

class QuizPage extends StatefulWidget {
  final Quiz quiz;

  const QuizPage({super.key, required this.quiz});

  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int? selectedOptionIndex;
  bool hasSubmitted = false;
  bool isCorrect = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(TextStrings.quizPage),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question
            Text(
              widget.quiz.question,
              style: TtextTheme.lightText.titleLarge,
            ),
            const SizedBox(height: 24),

            // Options list
            ...List.generate(
              widget.quiz.options.length,
              (index) => OptionCard(
                option: widget.quiz.options[index],
                index: index,
                isSelected: selectedOptionIndex == index,
                isCorrect: hasSubmitted
                    ? index == widget.quiz.correctOptionIndex
                    : null,
                isIncorrect: hasSubmitted
                    ? selectedOptionIndex == index &&
                        index != widget.quiz.correctOptionIndex
                    : null,
                onTap: hasSubmitted
                    ? null
                    : () {
                        setState(() {
                          selectedOptionIndex = index;
                        });
                      },
              ),
            ),

            const Spacer(),
            if (!hasSubmitted) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedOptionIndex == null
                      ? null
                      : () {
                          setState(() {
                            hasSubmitted = true;
                            isCorrect = selectedOptionIndex ==
                                widget.quiz.correctOptionIndex;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Submit Answer'),
                ),
              ),
            ] else ...[
              // Feedback
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCorrect ? 'Correct!' : 'Incorrect!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCorrect
                          ? TextStrings.correctAns
                          : 'The correct answer was: ${widget.quiz.options[widget.quiz.correctOptionIndex]}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Mark quiz as completed
                    if (isCorrect) {
                      Provider.of<CourseProvider>(context, listen: false)
                          .completeQuiz(widget.quiz);
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OptionCard extends StatelessWidget {
  final String option;
  final int index;
  final bool isSelected;
  final bool? isCorrect;
  final bool? isIncorrect;
  final VoidCallback? onTap;

  const OptionCard({
    super.key,
    required this.option,
    required this.index,
    required this.isSelected,
    this.isCorrect,
    this.isIncorrect,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine card color based on state
    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.black;
    IconData? trailingIcon;
    Color? iconColor;

    if (isCorrect == true) {
      cardColor = Colors.green.shade50;
      borderColor = Colors.green;
      textColor = Colors.green.shade800;
      trailingIcon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (isIncorrect == true) {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red;
      textColor = Colors.red.shade800;
      trailingIcon = Icons.cancel;
      iconColor = Colors.red;
    } else if (isSelected) {
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue;
      textColor = Colors.blue.shade800;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Option letter
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D...
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Option text
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(fontSize: 16, color: textColor),
                ),
              ),

              // Status icon
              if (trailingIcon != null) Icon(trailingIcon, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}
