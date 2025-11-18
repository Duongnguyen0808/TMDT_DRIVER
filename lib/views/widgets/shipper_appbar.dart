import 'package:flutter/material.dart';

class ShipperAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShipperAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      elevation: 0,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
