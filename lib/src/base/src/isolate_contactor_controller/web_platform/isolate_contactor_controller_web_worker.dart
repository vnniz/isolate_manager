import 'dart:async';
import 'dart:js_interop';

import 'package:isolate_manager/src/base/src/models/isolate_state.dart';
import 'package:web/web.dart';

import '../../isolate_contactor.dart';
import '../../models/exception.dart';
import '../isolate_contactor_controller_web.dart';

class IsolateContactorControllerImplWorker<R, P>
    implements IsolateContactorControllerImpl<R, P> {
  late Worker _delegate;

  final StreamController<R> _mainStreamController =
      StreamController.broadcast();
  final StreamController<P> _isolateStreamController =
      StreamController.broadcast();

  final void Function()? onDispose;
  final IsolateConverter<R> workerConverter;
  dynamic _initialParams;

  @override
  Completer<void> ensureInitialized = Completer();

  IsolateContactorControllerImplWorker(
    dynamic params, {
    required this.onDispose,
    required IsolateConverter<R> converter, // Converter for native
    required this.workerConverter, // Converter for Worker (Web Only)
  }) {
    if (params is List) {
      _delegate = params.last.controller as Worker;
      _initialParams = params.first;
    } else {
      _delegate = params as Worker;
    }

    _delegate.onmessage = (MessageEvent event) {
      if (IsolateState.dispose.isValidJson(event.data)) {
        onDispose!();
        close();
        return;
      }

      if (IsolateState.initialized.isValidJson(event.data)) {
        if (!ensureInitialized.isCompleted) {
          ensureInitialized.complete();
        }
        return;
      }

      if (IsolateException.isValidObject(event.data)) {
        final exception = IsolateException.fromJson(event.data);
        _mainStreamController.addError(
            exception.error.toString(), StackTrace.empty);
        return;
      }

      // Decode json from string which sent from isolate
      _mainStreamController.add(workerConverter(event.data));
    }.toJS;
  }

  /// Get this Worker
  @override
  Worker get controller => _delegate;

  /// Get initial params for `createCustom`
  @override
  dynamic get initialParams => _initialParams;

  @override
  Stream<R> get onMessage => _mainStreamController.stream;

  @override
  Stream<P> get onIsolateMessage => _isolateStreamController.stream;

  @override
  Future<void> initialized() => throw UnimplementedError();

  @override
  void sendIsolate(P message) {
    _delegate.postMessage(message as dynamic);
  }

  @override
  void sendIsolateState(IsolateState state) {
    _delegate.postMessage(state.toJson().toJS);
  }

  @override
  void sendResult(R message) => throw UnimplementedError();

  @override
  void sendResultError(IsolateException exception) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {
    _delegate.terminate();
    await Future.wait([
      _mainStreamController.close(),
      _isolateStreamController.close(),
    ]);
  }
}
