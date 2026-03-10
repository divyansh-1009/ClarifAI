import 'package:flutter/material.dart';
import './pages/quiz_page.dart';
import './services/api_service.dart';
import './models/assessment_model.dart';

void main() {
  runApp(const ClarifAIApp());
}

class ClarifAIApp extends StatelessWidget {
  const ClarifAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClarifAI Assessment',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AssessmentEntryPage(),
    );
  }
}

class AssessmentEntryPage extends StatefulWidget {
  const AssessmentEntryPage({super.key});

  @override
  State<AssessmentEntryPage> createState() => _AssessmentEntryPageState();
}

class _AssessmentEntryPageState extends State<AssessmentEntryPage> {
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _startQuiz() async {
    setState(() => _isLoading = true);
    try {
      final assessment = await _apiService.fetchAssessment();
      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuizPage(assessment: assessment),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClarifAI Quiz Assistant'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_outlined, size: 100, color: Colors.teal),
            const SizedBox(height: 24),
            const Text(
              'Interactive Assessment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Analyze your progress with AI-generated questions from your topic.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startQuiz,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Fetch My Quiz', style: TextStyle(fontSize: 18)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
