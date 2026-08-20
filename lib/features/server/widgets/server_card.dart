import 'package:flutter/material.dart';
import '../../speed_test/models/test_server.dart';

class ServerCard extends StatelessWidget {
  final TestServer server;
  final bool isSelected;
  final VoidCallback onTap;

  const ServerCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
        title: Text(
          server.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          [
            server.location,
            if (server.country.isNotEmpty) server.country,
            if (server.distanceKm != null) '${server.distanceKm} km',
          ].join(' · '),
        ),
        trailing: server.isDefault
            ? const Chip(
                label: Text('Default', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
