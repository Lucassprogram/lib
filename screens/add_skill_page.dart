import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AddSkillPage extends StatefulWidget {
  const AddSkillPage({super.key});

  @override
  State<AddSkillPage> createState() => _AddSkillPageState();
}

class _AddSkillPageState extends State<AddSkillPage> {
  final TextEditingController skillController = TextEditingController();
  String message = '';
  bool isLoading = false;

  Future<void> handleAddSkill() async {
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      message = '';
    });

    final String skillName = skillController.text.trim();
    if (skillName.isEmpty) {
      setState(() {
        message = 'Please enter a skill first.';
        isLoading = false;
      });
      return;
    }

    final Map<String, dynamic> result = await ApiService.addSkill(skillName);

    if (!mounted) {
      return;
    }

    final String feedback = result['error'] ?? 'Skill added successfully!';
    setState(() {
      message = feedback;
      isLoading = false;
    });

    if (!feedback.toLowerCase().contains('error')) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    skillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Skill')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Add a new skill',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let others know what you can offer or what you want to learn.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: skillController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Skill name',
                        hintText: 'e.g. UX Research, Python',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : handleAddSkill,
                        child: Text(isLoading ? 'Adding...' : 'Add Skill'),
                      ),
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: message.toLowerCase().contains('error')
                              ? theme.colorScheme.error
                              : AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
