import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String duration;
  final Color? color;
  final IconData? icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.duration,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color ?? Theme.of(context).primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? _getIconForLocation(title),
                color: color ?? Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    duration,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (title != 'Traveling')
              Icon(
                Icons.location_on,
                color: Colors.green,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLocation(String title) {
    switch (title.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'office':
        return Icons.work;
      case 'traveling':
        return Icons.directions_car;
      default:
        return Icons.location_on;
    }
  }
}