import 'package:flutter/material.dart';

void showDamagePopup(
  BuildContext context, {
  required int overdueDamage,
  required int habitDamage,
}) {
  final total = overdueDamage + habitDamage;

  if (total <= 0) return; // no popup if no damage today

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Daily Damage Report",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overdueDamage > 0) Text("Overdue Tasks: -$overdueDamage HP"),
            if (habitDamage > 0) Text("Incomplete Habits: -$habitDamage HP"),
            const SizedBox(height: 12),
            Divider(),
            Text(
              "Total Damage: -$total HP",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 211, 70, 70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Got it"),
          ),
        ],
      );
    },
  );
}
