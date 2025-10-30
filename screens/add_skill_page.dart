import 'package:flutter/material.dart';
import 'package:skillswap_mobile/services/api_service.dart';

class AddSkillPage extends StatefulWidget {
  const AddSkillPage({super.key});

  @override
  State<AddSkillPage> createState() => _AddSkillPageState();
}

class _AddSkillPageState extends State<AddSkillPage> {
  final skillController = TextEditingController();
  String message = '';
  bool isLoading = false;

  Future<void> handleAddSkill() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    // ✅ just send the skill (no userId or email needed)
    final result = await ApiService.addSkill(skillController.text.trim());

    setState(() {
      message = result['error'] ?? '✅ Skill added!';
    });

    // ✅ Return to home & refresh list
    if (!message.contains('Error') && !message.contains('⚠️')) {
      Navigator.pop(context, true); // tells HomePage to refresh
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Skill'),
        backgroundColor: const Color(0xFF3A4DA3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: skillController,
              decoration: const InputDecoration(
                labelText: 'Enter a new skill',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : handleAddSkill,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A4DA3),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
              child: Text(isLoading ? 'Adding...' : 'Add Skill'),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: message.contains('Error') ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
