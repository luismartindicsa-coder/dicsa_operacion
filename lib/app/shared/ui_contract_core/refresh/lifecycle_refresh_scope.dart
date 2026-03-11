import 'package:flutter/widgets.dart';

class LifecycleRefreshScope extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onResume;

  const LifecycleRefreshScope({super.key, required this.child, this.onResume});

  @override
  State<LifecycleRefreshScope> createState() => _LifecycleRefreshScopeState();
}

class _LifecycleRefreshScopeState extends State<LifecycleRefreshScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onResume?.call();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
