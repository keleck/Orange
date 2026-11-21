import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/payment/widgets/sliding_filter_button.dart';
import 'package:fl_clash/xboard/widgets/navigation/mobile_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('筛选按钮拖拽切换档位', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) => SlidingFilterButton(
                  selectedIndex: index,
                  labels: const ['全部', '周期性', '一次性'],
                  onChanged: (i) => setState(() => index = i),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(index, 0);
    // 单档宽 96，拖 130 应吸附到第 2 档
    await tester.drag(find.byType(SlidingFilterButton), const Offset(130, 0));
    await tester.pumpAndSettle();
    expect(index, 1);

    // 继续右拖到第 3 档
    await tester.drag(find.byType(SlidingFilterButton), const Offset(130, 0));
    await tester.pumpAndSettle();
    expect(index, 2);

    // 已到最右，再拖不应越界
    await tester.drag(find.byType(SlidingFilterButton), const Offset(130, 0));
    await tester.pumpAndSettle();
    expect(index, 2);

    // 左拖回第 2 档
    await tester.drag(find.byType(SlidingFilterButton), const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(index, 1);
  });

  testWidgets('底部导航拖拽切换 tab', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder: (context, setState) => MobileNavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => index = i),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(index, 0);
    // 单档宽约 117，拖 140 应吸附到第 2 档
    await tester.drag(find.byType(MobileNavigationBar), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(index, 1);

    await tester.drag(find.byType(MobileNavigationBar), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(index, 2);

    await tester.drag(find.byType(MobileNavigationBar), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(index, 1);
  });
}
