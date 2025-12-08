import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class MultiProfileScreen extends StatelessWidget {
  const MultiProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text("Main Profile"),
            subtitle: const Text("Default profile"),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () {},
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text("Dad's Profile"),
            subtitle: const Text("Linked profile"),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }
}
