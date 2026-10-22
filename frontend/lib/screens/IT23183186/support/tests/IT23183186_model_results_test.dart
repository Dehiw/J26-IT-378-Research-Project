import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:frontend/utils/theme.dart';
import 'package:frontend/services/environment_analysis_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/IT23183186_model_results.dart';
import 'package:frontend/widgets/bee_image_upload_zone.dart';
import 'package:frontend/screens/image_model_analysis_screen.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('MODEL_RESULTS_QA')) {
      final bytes = File('assets/fonts/Inter-Regular.ttf').readAsBytesSync();
      await (FontLoader(
        'Inter',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  const prediction = <String, dynamic>{
    'status': 'complete',
    'model_version': 'fixture-a',
    'predicted_class': 'healthy',
    'class_scores': {'healthy': .8, 'varroa_positive': .2},
    'limitations': ['Fixture only'],
  };
  const report = <String, dynamic>{
    'run_id': 'fixture-run',
    'summary': {'dataset': 'test fixture', 'architecture': 'MobileNetV2'},
    'evaluation': {
      'accuracy': .7,
      'test_count': 10,
      'confusion_matrix': [
        [4, 1],
        [2, 3],
      ],
      'confusion_matrix_labels_order': ['healthy', 'varroa_positive'],
      'per_class': {
        'macro avg': {'f1-score': .69},
        'weighted avg': {'f1-score': .7},
        'healthy': {
          'precision': .66,
          'recall': .8,
          'f1-score': .72,
          'support': 5,
        },
      },
    },
    'history': [
      {'epoch': 1, 'train_loss': .8, 'val_loss': .9},
      {'epoch': 2, 'train_loss': .5, 'val_loss': .6, 'val_accuracy': .7},
    ],
  };
  Future<void> show(
    WidgetTester tester, {
    required double width,
    required Map<String, dynamic> data,
    String modelKey = 'model_a',
    Map<String, dynamic> result = prediction,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: const bool.fromEnvironment('MODEL_RESULTS_QA')
              ? 'Inter'
              : null,
          scaffoldBackgroundColor: AppColors.bgPrimary,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('qa-capture'),
            child: SingleChildScrollView(
              child: ModelAnalysisResults(
                modelKey: modelKey,
                result: result,
                reportFuture: Future.value(data),
                image: const bool.fromEnvironment('MODEL_RESULTS_QA')
                    ? XFile.fromData(
                        File('lib/utils/images/05_bees_on_honeycomb.png')
                            .readAsBytesSync(),
                        name: 'qa-fixture.png',
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (const bool.fromEnvironment('MODEL_RESULTS_QA')) {
      await tester.runAsync(() async {
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        for (final image in images) {
          await precacheImage(
            image.image,
            tester.element(find.byType(ModelAnalysisResults)),
          );
        }
      });
    }
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('MODEL_RESULTS_QA')) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('qa-capture')),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/qa/results-$modelKey-${width.toInt()}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }

  testWidgets(
    'desktop separates prediction score from held-out accuracy and renders real series',
    (tester) async {
      await show(tester, width: 1400, data: report);
      expect(find.text('80.0%'), findsNWidgets(2));
      expect(find.text('70.0%'), findsNWidgets(2));
      expect(find.text('Model performance'), findsOneWidget);
      expect(find.text('Confusion matrix'), findsOneWidget);
      expect(find.text('Training history'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('80.0%'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mobile missing evaluation never reuses prediction confidence as accuracy',
    (tester) async {
      await show(tester, width: 360, data: {});
      expect(find.text('80.0%'), findsOneWidget);
      await tester.tap(find.text('Evaluation'));
      await tester.pumpAndSettle();
      expect(find.text('Test evaluation unavailable'), findsOneWidget);
      expect(find.text('80.0%'), findsNothing);
      await tester.tap(find.text('Training'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Training history unavailable.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'detector outputs retain per-object labels and unavailable test state',
    (tester) async {
      await show(
        tester,
        width: 1400,
        data: {},
        modelKey: 'model_b',
        result: {
          'status': 'complete',
          'model_version': 'fixture-b',
          'detections': [
            {
              'class_name': 'BeeHiveFrame',
              'confidence': .9,
              'bbox_xyxy': [1, 2, 3, 4],
            },
          ],
        },
      );
      expect(find.text('1 structural detections'), findsOneWidget);
      expect(find.text('Predicted class: healthy'), findsNothing);
      expect(find.textContaining('BeeHiveFrame  90.0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real latency is distinct from timestamp and model labels omit academic IDs',
    (tester) async {
      await show(
        tester,
        width: 1400,
        data: report,
        result: {
          ...prediction,
          'model_version': 'IT23183186_ModelA_MobileNetV2',
          'inference_duration_ms': 37.5,
          'inference_timestamp': '2026-10-21T08:30:00Z',
        },
      );
      expect(find.text('Inference latency: 37.5 ms'), findsOneWidget);
      expect(find.textContaining(RegExp(r'IT\d{8}')), findsNothing);
      expect(find.textContaining('Analyzed:'), findsOneWidget);
    },
  );

  testWidgets(
    'analysis draft remains visible when returning to the image screen',
    (tester) async {
      EnvironmentAnalysisSession.put('retained-hive', null, null, {
        'model_a': prediction,
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageModelAnalysisScreen(hiveId: 'retained-hive'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Model A analysis results'), findsOneWidget);
      expect(find.text('Predicted class: Healthy bee'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'one upload zone per model with no duplicate upper chooser cards',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ImageModelAnalysisScreen()),
      );
      expect(find.byType(BeeImageUploadZone), findsNWidgets(2));
      expect(find.text('Choose photo'), findsNothing);
      expect(find.text('Individual bee - Model A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
