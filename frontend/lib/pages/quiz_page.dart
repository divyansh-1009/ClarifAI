import 'package:flutter/material.dart';
import '../models/assessment_model.dart';

class QuizPage extends StatefulWidget {
  final Assessment assessment;

  const QuizPage({super.key, required this.assessment});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};

  void _nextQuestion() {
    if (_currentIndex < widget.assessment.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showResults();
    }
  }

  void _showResults() {
    int score = 0;
    for (int i = 0; i < widget.assessment.questions.length; i++) {
        if (widget.assessment.questions[i].answerKey != null && 
            _userAnswers[i] == widget.assessment.questions[i].answerKey) {
          score += widget.assessment.questions[i].marks;
        }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Completed!'),
        content: Text('Your estimated score: $score / ${widget.assessment.metadata.totalMarks}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to setup
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment.metadata.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.assessment.questions.length,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.assessment.questions.length,
        itemBuilder: (context, index) {
          final question = widget.assessment.questions[index];
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${index + 1} of ${widget.assessment.questions.length}',
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  question.question_text,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 30),
                if (question.type == 'multiple_choice' && question.options != null)
                  ...question.options!.map((opt) => RadioListTile<String>(
                        title: Text(opt),
                        value: opt,
                        groupValue: _userAnswers[index],
                        onChanged: (val) {
                          setState(() => _userAnswers[index] = val!);
                        },
                      ))
                else
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Type your answer here',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (val) => _userAnswers[index] = val,
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _userAnswers.containsKey(index) ? _nextQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_currentIndex == widget.assessment.questions.length - 1
                        ? 'Finish Test'
                        : 'Next Question'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
