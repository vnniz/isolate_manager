import 'dart:async';

import 'package:isolate_manager/isolate_manager.dart';

import 'isolate_worker/isolate_worker_web.dart'
    if (dart.library.io) 'isolate_worker/isolate_worker_stub.dart';

/// A callback for the [IsolateManagerFunction.customFunction] that will be executed only one time
/// before all events.
typedef IsolateOnInitialCallback<T> = FutureOr<void> Function(
    IsolateManagerController controller, T initialParams);

/// A callback for the [IsolateManagerFunction.customFunction] that will be executed only one time
/// before all events.
typedef IsolateOnDisposeCallback<T> = void Function(
    IsolateManagerController controller);

/// A callback for the [IsolateManagerFunction.customFunction] that will be executed every time
/// the [message] is received from the `sendMessage` or `execute` method.
typedef IsolateOnEventCallback<R, P> = FutureOr<R> Function(
    IsolateManagerController controller, P message);

class IsolateManagerFunction {
  /// No-op
  IsolateManagerFunction._(); // coverage:ignore-line

  /// Create a custom isolate function.
  ///
  /// The [onInitial] and [onDispose] will be executed only one time in the beginning
  /// and at the end. The [onEvent] will be executed every time the `message` is received
  /// from the main isolate. You can set the [autoHandleException] to `false` if
  /// you want to `controller.sendResultError` by yourself, and set the [autoHandleResult]
  /// if you want to `controller.sendResult` yourself. By defaults, when the [onEvent]
  /// was executed, the result will be sent to the main isolate and the `Exception`
  /// will also be sent.
  ///
  /// ```dart
  /// void customIsolateFunction(dynamic params) {
  ///   IsolateManagerFunction.customFunction<int, int>(
  ///     params,
  ///     onEvent: (controller, message) {
  ///       /* This event will be executed every time the `message` is received from the main isolate */
  ///       return fetchAndDecode(message);
  ///     },
  ///     onInitial: (controller, initialParams) {
  ///        // This event will be executed before all the other events
  ///        //
  ///        // This event can be a `Future` but you need to set the `autoInitialize` in
  ///        // the `create` and `createCustom` to `false` to make it works.
  ///     },
  ///     onDispose: (controller) {
  ///        /* This event will be executed after all the other events and should NOT be a `Future` event */
  ///     },
  ///   );
  /// }
  /// ```
  static Future<void> customFunction<R, P>(
    dynamic params, {
    required IsolateOnEventCallback<R, P> onEvent,
    IsolateOnInitialCallback? onInitial,
    IsolateOnDisposeCallback? onDispose,
    bool autoHandleException = true,
    bool autoHandleResult = true,
  }) async {
    // Initialize the controller for the child isolate. This function will be declared
    // with `Map<String, dynamic>` as the return type (.sendResult) and `String` as the parameter type (.sendMessage).
    late IsolateManagerController controller;
    controller = IsolateManagerController(
      params,
      onDispose: onDispose == null
          ? null
          : () {
              onDispose(controller);
              controller.close();
            },
    );

    if (onInitial != null) {
      final completer = Completer<void>();
      completer.complete(onInitial(controller, controller.initialParams));
      await completer.future;
    }

    // Listen to messages received from the main isolate; this code will be called each time
    // you use `compute` or `sendMessage`.
    controller.onIsolateMessage.listen((message) {
      Completer completer = Completer();
      completer.future.then(
        (value) => autoHandleResult ? controller.sendResult(value) : null,
        onError: autoHandleException
            ? (err, stack) =>
                controller.sendResultError(IsolateException(err, stack))
            : null,
      );

      // Use try-catch to send the exception to the main app
      try {
        completer.complete(onEvent(controller, message));
      } catch (err, stack) {
        // Send the exception to your main app
        if (autoHandleException) {
          completer.completeError(err, stack);
        } else {
          rethrow;
        }
      }
    });

    controller.initialized();
  }

  // coverage:ignore-start
  // Tested by compiling to `js` for the Web Worker.
  //
  /// Create a worker in your `main`.
  ///
  /// ```dart
  /// import 'package:isolate_manager/isolate_manager.dart';

  /// main() {
  ///   // The function `fetchAndDecode` MUST NOT depend on any Flutter library
  ///   IsolateManagerFunction.workerFunction(
  ///     fetchAndDecode,
  ///     onInitial: () {
  ///       // This is optional.
  ///       //
  ///       // You have to set the parameter `autoInitialze` in the `create` and `createCustom`
  ///       // to `false` when using this.
  ///     }
  ///   );
  /// }
  /// ```
  ///
  /// Build it with `dart compile js worker.dart -o worker.js -O4` and copy the `worker.js` to
  /// your Web folder.
  ///
  /// When you're using the [onInitial], you have to set the `autoInitialize` parameter
  /// of the `create` and `createCustom` to `false`. Without it, the `Worker` will
  /// be stucked forever.
  ///
  /// If you need to throw an exception, you should only throw the `message`
  /// instead of a whole Object because it may not be shown as expected when
  /// sending back to the main app.
  ///
  /// ``` dart
  ///  return throw 'This is an error that you need to catch in your main app';
  /// ```
  static Future<void> workerFunction<R, P>(
    IsolateWorkerFunction<R, P> function, {
    FutureOr<void> Function()? onInitial,
  }) {
    return isolateWorkerImpl<R, P>(function, onInitial);
  }
  // coverage:ignore-end
}

// coverage:ignore-start
@Deprecated('Use `IsolateManagerFunction` instead')
class IsolateFunctionHelper {
  /// Create a custom isolate function.
  ///
  /// The [onInitial] and [onDispose] will be executed only one time in the beginning
  /// and at the end. The [onEvent] will be executed every time the `message` is received
  /// from the main isolate. You can set the [autoHandleException] to `false` if
  /// you want to `controller.sendResultError` by yourself, and set the [autoHandleResult]
  /// if you want to `controller.sendResult` yourself. By defaults, when the [onEvent]
  /// was executed, the result will be sent to the main isolate and the `Exception`
  /// will also be sent.
  ///
  /// ```dart
  /// void customIsolateFunction(dynamic params) {
  ///   IsolateFunctionHelper.customFunction<int, int>(
  ///     params,
  ///     onEvent: (controller, message) {
  ///       /* This event will be executed every time the `message` is received from the main isolate */
  ///       return fetchAndDecode(message);
  ///     },
  ///     onInitial: (controller, initialParams) {
  ///        // This event will be executed before all the other events
  ///        //
  ///        // This event can be a `Future` but you need to set the `autoInitialize` in
  ///        // the `create` and `createCustom` to `false` to make it works.
  ///     },
  ///     onDispose: (controller) {
  ///        /* This event will be executed after all the other events and should NOT be a `Future` event */
  ///     },
  ///   );
  /// }
  /// ```
  @Deprecated('Use `IsolateManagerFunction.customFunction` instead')
  static Future<void> customFunction<R, P>(
    dynamic params, {
    required IsolateOnEventCallback<R, P> onEvent,
    IsolateOnInitialCallback? onInitial,
    IsolateOnDisposeCallback? onDispose,
    bool autoHandleException = true,
    bool autoHandleResult = true,
  }) =>
      IsolateManagerFunction.customFunction(
        params,
        onEvent: onEvent,
        onInitial: onInitial,
        onDispose: onDispose,
        autoHandleException: autoHandleException,
        autoHandleResult: autoHandleResult,
      );

  // Tested by compiling to `js` for the Web Worker.
  //
  /// Create a worker in your `main`.
  ///
  /// ```dart
  /// main() {
  ///   // The function `fetchAndDecode` MUST NOT depend on any Flutter library
  ///   IsolateFunctionHelper.workerFunction(
  ///     fetchAndDecode,
  ///     onInitial: () {
  ///       // This is optional.
  ///       //
  ///       // You have to set the parameter `autoInitialze` in the `create` and `createCustom`
  ///       // to `false` when using this.
  ///     }
  ///   );
  /// }
  /// ```
  ///
  /// Build it with `dart compile js worker.dart -o worker.js -O4` and copy the `worker.js` to
  /// your Web folder.
  ///
  /// When you're using the [onInitial], you have to set the `autoInitialize` parameter
  /// of the `create` and `createCustom` to `false`. Without it, the `Worker` will
  /// be stucked forever.
  ///
  /// If you need to throw an exception, you should only throw the `message`
  /// instead of a whole Object because it may not be shown as expected when
  /// sending back to the main app.
  ///
  /// ``` dart
  ///  return throw 'This is an error that you need to catch in your main app';
  /// ```
  @Deprecated('Use `IsolateManagerFunction.workerFunction` instead')
  static Future<void> workerFunction<R, P>(
    IsolateWorkerFunction<R, P> function, {
    FutureOr<void> Function()? onInitial,
  }) =>
      IsolateManagerFunction.workerFunction(function, onInitial: onInitial);
}
// coverage:ignore-end
