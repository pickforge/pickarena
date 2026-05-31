import 'package:flutter/material.dart';

class ExpandableListTile extends StatefulWidget {
  const ExpandableListTile({
    super.key,
    required this.title,
    required this.details,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final Widget title;
  final Widget details;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<ExpandableListTile> createState() => _ExpandableListTileState();
}

class _ExpandableListTileState extends State<ExpandableListTile>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    if (_isExpanded) {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.animateTo(0.5);
      } else {
        _controller.animateTo(0.0);
      }
      widget.onExpansionChanged?.call(_isExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: widget.title,
          trailing: RotationTransition(
            turns: _controller,
            child: const Icon(Icons.keyboard_arrow_down),
          ),
          onTap: _toggle,
        ),
        if (_isExpanded) widget.details,
      ],
    );
  }
}
