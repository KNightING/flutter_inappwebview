import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../platform_util.dart';
import '_static_channel.dart';

const Map<String, SystemMouseCursor> _cursors = {
  'none': SystemMouseCursors.none,
  'basic': SystemMouseCursors.basic,
  'click': SystemMouseCursors.click,
  'forbidden': SystemMouseCursors.forbidden,
  'wait': SystemMouseCursors.wait,
  'progress': SystemMouseCursors.progress,
  'contextMenu': SystemMouseCursors.contextMenu,
  'help': SystemMouseCursors.help,
  'text': SystemMouseCursors.text,
  'verticalText': SystemMouseCursors.verticalText,
  'cell': SystemMouseCursors.cell,
  'precise': SystemMouseCursors.precise,
  'move': SystemMouseCursors.move,
  'grab': SystemMouseCursors.grab,
  'grabbing': SystemMouseCursors.grabbing,
  'noDrop': SystemMouseCursors.noDrop,
  'alias': SystemMouseCursors.alias,
  'copy': SystemMouseCursors.copy,
  'disappearing': SystemMouseCursors.disappearing,
  'allScroll': SystemMouseCursors.allScroll,
  'resizeLeftRight': SystemMouseCursors.resizeLeftRight,
  'resizeUpDown': SystemMouseCursors.resizeUpDown,
  'resizeUpLeftDownRight': SystemMouseCursors.resizeUpLeftDownRight,
  'resizeUpRightDownLeft': SystemMouseCursors.resizeUpRightDownLeft,
  'resizeUp': SystemMouseCursors.resizeUp,
  'resizeDown': SystemMouseCursors.resizeDown,
  'resizeLeft': SystemMouseCursors.resizeLeft,
  'resizeRight': SystemMouseCursors.resizeRight,
  'resizeUpLeft': SystemMouseCursors.resizeUpLeft,
  'resizeUpRight': SystemMouseCursors.resizeUpRight,
  'resizeDownLeft': SystemMouseCursors.resizeDownLeft,
  'resizeDownRight': SystemMouseCursors.resizeDownRight,
  'resizeColumn': SystemMouseCursors.resizeColumn,
  'resizeRow': SystemMouseCursors.resizeRow,
  'zoomIn': SystemMouseCursors.zoomIn,
  'zoomOut': SystemMouseCursors.zoomOut,
};

SystemMouseCursor _getCursorByName(String name) =>
    _cursors[name] ?? SystemMouseCursors.basic;

/// Pointer button type
// Order must match InAppWebViewPointerEventKind (see in_app_webview.h)
enum PointerButton { none, primary, secondary, tertiary }

/// Pointer Event kind
// Order must match InAppWebViewPointerEventKind (see in_app_webview.h)
enum InAppWebViewPointerEventKind {
  activate,
  down,
  enter,
  leave,
  up,
  update,
  cancel,
}

/// Attempts to translate a button constant such as [kPrimaryMouseButton]
/// to a [PointerButton]
PointerButton _getButton(int value) {
  switch (value) {
    case kPrimaryMouseButton:
      return PointerButton.primary;
    case kSecondaryMouseButton:
      return PointerButton.secondary;
    case kTertiaryButton:
      return PointerButton.tertiary;
    default:
      return PointerButton.none;
  }
}

const MethodChannel _pluginChannel = IN_APP_WEBVIEW_STATIC_CHANNEL;

class CustomFlutterViewControllerValue {
  const CustomFlutterViewControllerValue({required this.isInitialized});

  final bool isInitialized;

  CustomFlutterViewControllerValue copyWith({bool? isInitialized}) {
    return CustomFlutterViewControllerValue(
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  CustomFlutterViewControllerValue.uninitialized() : this(isInitialized: false);
}

/// Controls a WebView and provides streams for various change events.
class CustomPlatformViewController
    extends ValueNotifier<CustomFlutterViewControllerValue> {
  Completer<void> _creatingCompleter = Completer<void>();
  int _textureId = 0;
  bool _isDisposed = false;

  Future<void> get ready => _creatingCompleter.future;

  late MethodChannel _methodChannel;
  late EventChannel _eventChannel;
  StreamSubscription? _eventStreamSubscription;

  final StreamController<SystemMouseCursor> _cursorStreamController =
      StreamController<SystemMouseCursor>.broadcast();

  /// A stream reflecting the current cursor style.
  Stream<SystemMouseCursor> get _cursor => _cursorStreamController.stream;

  CustomPlatformViewController()
    : super(CustomFlutterViewControllerValue.uninitialized());

  /// Initializes the underlying platform view.
  Future<void> initialize({
    Function(int id)? onPlatformViewCreated,
    dynamic arguments,
  }) async {
    if (_isDisposed) {
      return;
    }
    _textureId = (await _pluginChannel.invokeMethod<int>(
      'createInAppWebView',
      arguments,
    ))!;

    _methodChannel = MethodChannel(
      'com.pichillilorenzo/custom_platform_view_$_textureId',
    );
    _eventChannel = EventChannel(
      'com.pichillilorenzo/custom_platform_view_${_textureId}_events',
    );
    _eventStreamSubscription = _eventChannel.receiveBroadcastStream().listen((
      event,
    ) {
      final map = event as Map<dynamic, dynamic>;
      switch (map['type']) {
        case 'cursorChanged':
          _cursorStreamController.add(_getCursorByName(map['value']));
          break;
      }
    });

    _methodChannel.setMethodCallHandler((call) {
      throw MissingPluginException('Unknown method ${call.method}');
    });

    value = value.copyWith(isInitialized: true);

    _creatingCompleter.complete();

    onPlatformViewCreated?.call(_textureId);
  }

  @override
  Future<void> dispose() async {
    await _creatingCompleter.future;
    if (!_isDisposed) {
      _isDisposed = true;
      await _eventStreamSubscription?.cancel();
      await _pluginChannel.invokeMethod('dispose', {"id": _textureId});
    }
    super.dispose();
  }

  /// Limits the number of frames per second to the given value.
  Future<void> setFpsLimit([int? maxFps = 0]) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setFpsLimit', maxFps);
  }

  /// Sends a Pointer (Touch) update
  Future<void> _setPointerUpdate(
    InAppWebViewPointerEventKind kind,
    int pointer,
    Offset position,
    double size,
    double pressure,
  ) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setPointerUpdate', [
      pointer,
      kind.index,
      position.dx,
      position.dy,
      size,
      pressure,
    ]);
  }

  /// Moves the virtual cursor to [position].
  Future<void> _setCursorPos(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setCursorPos', [
      position.dx,
      position.dy,
    ]);
  }

  /// Indicates whether the specified [button] is currently down.
  Future<void> _setPointerButtonState(
    InAppWebViewPointerEventKind kind,
    PointerButton button,
  ) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setPointerButton', <String, dynamic>{
      'kind': kind.index,
      'button': button.index,
    });
  }

  /// Drops the sub-unit scroll remainder held natively.
  ///
  /// Called at both ends of a trackpad gesture so a fraction left behind by one gesture
  /// cannot be spent by the next, which would show up as a small jump on first touch.
  Future<void> _resetScrollRemainder() async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('resetScrollRemainder');
  }

  /// Sets the horizontal and vertical scroll delta.
  Future<void> _setScrollDelta(double dx, double dy) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setScrollDelta', [dx, dy]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setSize(Size size, double scaleFactor) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setSize', [
      size.width,
      size.height,
      scaleFactor,
    ]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setPosition(Offset position, double scaleFactor) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setPosition', [
      position.dx,
      position.dy,
      scaleFactor,
    ]);
  }
}

class CustomPlatformView extends StatefulWidget {
  /// An optional scale factor. Defaults to [FlutterView.devicePixelRatio] for
  /// rendering in native resolution.
  /// Setting this to 1.0 will disable high-DPI support.
  /// This should only be needed to mimic old behavior before high-DPI support
  /// was available.
  final double? scaleFactor;

  /// The [FilterQuality] used for scaling the texture's contents.
  /// Defaults to [FilterQuality.none] as this renders in native resolution
  /// unless specifying a [scaleFactor].
  final FilterQuality filterQuality;

  final dynamic creationParams;

  final Function(int id)? onPlatformViewCreated;

  const CustomPlatformView({
    this.creationParams,
    this.onPlatformViewCreated,
    this.scaleFactor,
    this.filterQuality = FilterQuality.none,
  });

  @override
  _CustomPlatformViewState createState() => _CustomPlatformViewState();
}

class _CustomPlatformViewState extends State<CustomPlatformView>
    with PlatformUtilListener {
  final GlobalKey _key = GlobalKey();
  final _downButtons = <int, PointerButton>{};

  PointerDeviceKind _pointerKind = PointerDeviceKind.unknown;

  /// Axis the in-flight trackpad gesture is locked to, `null` until one is picked.
  Axis? _panAxis;

  /// Movement a gesture has to cover before its axis is decided, in logical pixels.
  ///
  /// The opening frames of a swipe are small and noisy, and whichever axis happens to lead
  /// there is not yet the axis the user is scrolling along. Waiting for a real displacement
  /// avoids locking to the wrong one.
  static const double _panAxisLockThreshold = 3.0;

  /// Movement accumulated since the gesture began, used only until the axis is locked.
  Offset _panTravel = Offset.zero;

  MouseCursor _cursor = SystemMouseCursors.basic;

  /// Decides which axis [delta] belongs to, locking it for the rest of the gesture.
  ///
  /// Only one axis may be forwarded per gesture: a trackpad reports a perpendicular component
  /// on nearly every frame, and letting a horizontal wheel interleave with the vertical ones
  /// makes Chromium read the whole sequence as horizontal and drop the vertical movement.
  /// Deciding per frame instead of per gesture is not enough either -- single frames where the
  /// minor axis happens to lead get sent to the wrong axis and their movement is lost, which
  /// shows up as a swipe travelling less than it should.
  ///
  /// Returns the axis and the movement to forward on it, or `null` while the gesture is still
  /// too small to call. On the frame that decides the axis, the returned movement covers
  /// everything accumulated since the gesture began, so the frames spent waiting are folded in
  /// rather than dropped.
  (Axis, Offset)? _latchPanAxis(Offset delta) {
    final axis = _panAxis;
    if (axis != null) {
      return (axis, delta);
    }

    _panTravel += delta;
    final dx = _panTravel.dx.abs();
    final dy = _panTravel.dy.abs();
    if (dx < _panAxisLockThreshold && dy < _panAxisLockThreshold) {
      return null;
    }

    _panAxis = dx > dy ? Axis.horizontal : Axis.vertical;
    final travel = _panTravel;
    _panTravel = Offset.zero;
    return (_panAxis!, travel);
  }

  final _controller = CustomPlatformViewController();
  final _focusNode = FocusNode();

  StreamSubscription? _cursorSubscription;

  late final AppLifecycleListener _listener;

  PlatformUtil _platformUtil = PlatformUtil.instance();

  @override
  void initState() {
    super.initState();

    _platformUtil.addListener(this);

    _controller.initialize(
      onPlatformViewCreated: (id) {
        widget.onPlatformViewCreated?.call(id);
        setState(() {});
      },
      arguments: widget.creationParams,
    );

    _listener = AppLifecycleListener(
      onStateChange: (state) {
        if ([
          AppLifecycleState.resumed,
          AppLifecycleState.hidden,
        ].contains(state)) {
          _reportSurfaceSize();
          _reportWidgetPosition();
        }
      },
    );

    // Report initial surface size and widget position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportSurfaceSize();
      _reportWidgetPosition();
    });

    _cursorSubscription = _controller._cursor.listen((cursor) {
      setState(() {
        _cursor = cursor;
      });
    });
  }

  @override
  void onWindowMove() {
    _reportSurfaceSize();
    _reportWidgetPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      canRequestFocus: true,
      debugLabel: "flutter_inappwebview_windows_custom_platform_view",
      onFocusChange: (focused) {},
      child: SizedBox.expand(key: _key, child: _buildInner()),
    );
  }

  Widget _buildInner() {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        _reportSurfaceSize();
        _reportWidgetPosition();
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: _controller.value.isInitialized
            ? Listener(
                onPointerHover: (ev) {
                  // ev.kind is for whatever reason not set to touch
                  // even on touch input
                  if (_pointerKind == PointerDeviceKind.touch) {
                    // Ignoring hover events on touch for now
                    return;
                  }
                  _controller._setCursorPos(ev.localPosition);
                },
                onPointerDown: (ev) {
                  _reportSurfaceSize();
                  _reportWidgetPosition();

                  if (!_focusNode.hasFocus) {
                    _focusNode.requestFocus();
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (!_focusNode.hasFocus) {
                        _focusNode.requestFocus();
                      }
                    });
                  }

                  _pointerKind = ev.kind;
                  if (ev.kind == PointerDeviceKind.touch) {
                    _controller._setPointerUpdate(
                      InAppWebViewPointerEventKind.down,
                      ev.pointer,
                      ev.localPosition,
                      ev.size,
                      ev.pressure,
                    );
                    return;
                  }
                  final button = _getButton(ev.buttons);
                  _downButtons[ev.pointer] = button;
                  _controller._setPointerButtonState(
                    InAppWebViewPointerEventKind.down,
                    button,
                  );
                },
                onPointerUp: (ev) {
                  _pointerKind = ev.kind;
                  if (ev.kind == PointerDeviceKind.touch) {
                    _controller._setPointerUpdate(
                      InAppWebViewPointerEventKind.up,
                      ev.pointer,
                      ev.localPosition,
                      ev.size,
                      ev.pressure,
                    );
                    return;
                  }
                  final button = _downButtons.remove(ev.pointer);
                  if (button != null) {
                    _controller._setPointerButtonState(
                      InAppWebViewPointerEventKind.up,
                      button,
                    );
                  }
                },
                onPointerCancel: (ev) {
                  _pointerKind = ev.kind;
                  final button = _downButtons.remove(ev.pointer);
                  if (button != null) {
                    _controller._setPointerButtonState(
                      InAppWebViewPointerEventKind.cancel,
                      button,
                    );
                  }
                },
                onPointerMove: (ev) {
                  _pointerKind = ev.kind;
                  if (ev.kind == PointerDeviceKind.touch) {
                    _controller._setPointerUpdate(
                      InAppWebViewPointerEventKind.update,
                      ev.pointer,
                      ev.localPosition,
                      ev.size,
                      ev.pressure,
                    );
                  } else {
                    _controller._setCursorPos(ev.localPosition);
                  }
                },
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent) {
                    _controller._setScrollDelta(
                      -signal.scrollDelta.dx,
                      -signal.scrollDelta.dy,
                    );
                  }
                },
                onPointerPanZoomStart: (ev) {
                  _panAxis = null;
                  _panTravel = Offset.zero;
                  // A gesture starts from a clean slate: any sub-unit remainder left over
                  // from the previous one would otherwise leak into its first frame.
                  _controller._resetScrollRemainder();
                },
                onPointerPanZoomUpdate: (ev) {
                  final latched = _latchPanAxis(ev.panDelta);
                  if (latched == null) {
                    return;
                  }
                  final (axis, delta) = latched;

                  // The signs differ per axis because the wheel's own two axes do: a positive
                  // vertical wheel scrolls the view up, a positive horizontal one scrolls it
                  // right. panDelta is direct-manipulation throughout -- the content follows
                  // the fingers -- so fingers moving down (positive dy) ask for the view to go
                  // up, which is already a positive wheel, while fingers moving right
                  // (positive dx) ask for the view to go left, which is a negative one. Both
                  // directions were verified on hardware 2026-08-15; flipping either inverts
                  // that axis.
                  if (axis == Axis.horizontal) {
                    _controller._setScrollDelta(-delta.dx, 0);
                  } else {
                    _controller._setScrollDelta(0, delta.dy);
                  }
                },
                onPointerPanZoomEnd: (ev) {
                  _panAxis = null;
                  _panTravel = Offset.zero;
                  _controller._resetScrollRemainder();
                },
                child: MouseRegion(
                  cursor: _cursor,
                  onEnter: (ev) {
                    final button = _getButton(ev.buttons);
                    _controller._setPointerButtonState(
                      InAppWebViewPointerEventKind.enter,
                      button,
                    );
                  },
                  onExit: (ev) {
                    final button = _getButton(ev.buttons);
                    _controller._setPointerButtonState(
                      InAppWebViewPointerEventKind.leave,
                      button,
                    );
                  },
                  child: Texture(
                    textureId: _controller._textureId,
                    filterQuality: widget.filterQuality,
                  ),
                ),
              )
            : const SizedBox(),
      ),
    );
  }

  void _reportSurfaceSize() async {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      await _controller.ready;
      unawaited(
        _controller._setSize(
          box.size,
          widget.scaleFactor ?? window.devicePixelRatio,
        ),
      );
    }
  }

  void _reportWidgetPosition() async {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      await _controller.ready;
      final position = box.localToGlobal(Offset.zero);
      unawaited(
        _controller._setPosition(
          position,
          widget.scaleFactor ?? window.devicePixelRatio,
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    _platformUtil.removeListener(this);
    _cursorSubscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _listener.dispose();
  }
}
