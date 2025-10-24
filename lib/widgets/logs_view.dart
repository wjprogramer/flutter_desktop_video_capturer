import 'package:flutter/material.dart';

class LogsView extends StatefulWidget {
  const LogsView({super.key, required this.logs});

  final List<String> logs;

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  final _scrollController = ScrollController();

  List<String> get _logs => widget.logs;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Container(
        color: Colors.black,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _logs.length,
          reverse: true,
          itemBuilder: (context, index) {
            return Text(
              _logs[index],
              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
            );
          },
        ),
      ),
    );
  }
}
