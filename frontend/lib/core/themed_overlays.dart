import 'package:flutter/material.dart';
import 'theme.dart';

Future<T?> showAppDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showDialog<T>(context: context, builder: (dialogContext) => AppThemedPage(builder: (_, __) => builder(dialogContext)));
}

Future<T?> showAppBottomSheet<T>({required BuildContext context, required WidgetBuilder builder, bool isScrollControlled = false, bool isDismissible = true}) {
  return showModalBottomSheet<T>(context: context, isScrollControlled: isScrollControlled, isDismissible: isDismissible, builder: (sheetContext) => AppThemedPage(builder: (_, __) => builder(sheetContext)));
}
