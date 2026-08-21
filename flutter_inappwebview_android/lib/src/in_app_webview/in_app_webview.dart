import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import '../find_interaction/find_interaction_controller.dart';
import '../pull_to_refresh/pull_to_refresh_controller.dart';
import 'headless_in_app_webview.dart';
import 'in_app_webview_controller.dart';

/// Object specifying creation parameters for creating a [PlatformInAppWebViewWidget].
///
/// Platform specific implementations can add additional fields by extending
/// this class.
/// Whether Hybrid Composition++ is known to be usable on this device and application.
///
/// Only a positive answer is cached. The check is answered by the engine, and asking before the
/// engine has attached reports `false` even where HCPP is fully available -- observed on an
/// API 36 emulator, where the call made from [AndroidInAppWebViewPlatform.registerWith] returned
/// `false` while the same call a few hundred milliseconds later returned `true`. Caching that
/// first answer would disable HCPP for the whole session.
bool _hcppSupported = false;
Future<bool>? _hcppProbe;

/// Resolves whether Hybrid Composition++ is available, caching only a positive result.
///
/// HCPP needs Android API 34+, a Vulkan-capable device, AND the embedding application to have
/// opted in -- a plugin cannot turn it on by itself. The engine answers all of that at once.
///
/// Safe to call repeatedly: concurrent calls share one in-flight check, and once the answer is
/// `true` it is returned without asking again.
///
/// Await this before building the first [InAppWebView] if that WebView must get HCPP: the
/// platform view factory has to choose a mode synchronously, so a WebView built before any check
/// has succeeded falls back to Texture Layer Hybrid Composition.
Future<bool> precacheHybridCompositionPlusPlusSupport() {
  if (_hcppSupported) {
    return Future<bool>.value(true);
  }
  return _hcppProbe ??= HybridAndroidViewController.checkIfSupported()
      .then((supported) {
        _hcppSupported = supported;
        return supported;
      })
      .catchError((Object _) {
        // Engines without the HCPP channel answer with a MissingPluginException.
        return false;
      })
      .whenComplete(() {
        // Let a later call ask again: a negative answer may only mean "asked too early".
        _hcppProbe = null;
      });
}

/// Whether Hybrid Composition++ is known to be usable right now.
///
/// Reports `false` until a check has succeeded -- the mode must be decided synchronously, and an
/// unresolved check is not a confirmation.
bool get isHybridCompositionPlusPlusSupported => _hcppSupported;

/// The support check backing the automatic composition mode, memoised.
///
/// Memoising matters: a `FutureBuilder` handed a fresh future on every rebuild would fall back
/// to its waiting state and tear down a WebView that had already been created.
Future<bool>? _autoModeProbe;

Future<bool> _autoCompositionModeSupport() =>
    _autoModeProbe ??= precacheHybridCompositionPlusPlusSupport();

class AndroidInAppWebViewWidgetCreationParams
    extends PlatformInAppWebViewWidgetCreationParams {
  AndroidInAppWebViewWidgetCreationParams({
    super.controllerFromPlatform,
    super.key,
    super.layoutDirection,
    super.gestureRecognizers,
    super.headlessWebView,
    super.keepAlive,
    super.preventGestureDelay,
    super.windowId,
    super.onWebViewCreated,
    super.onLoadStart,
    super.onLoadStop,
    @Deprecated('Use onReceivedError instead') super.onLoadError,
    super.onReceivedError,
    @Deprecated("Use onReceivedHttpError instead") super.onLoadHttpError,
    super.onReceivedHttpError,
    super.onProgressChanged,
    super.onConsoleMessage,
    super.shouldOverrideUrlLoading,
    super.onLoadResource,
    super.onScrollChanged,
    @Deprecated('Use onDownloadStarting instead') super.onDownloadStart,
    @Deprecated('Use onDownloadStarting instead') super.onDownloadStartRequest,
    super.onDownloadStarting,
    @Deprecated('Use onLoadResourceWithCustomScheme instead')
    super.onLoadResourceCustomScheme,
    super.onLoadResourceWithCustomScheme,
    super.onCreateWindow,
    super.onCloseWindow,
    super.onJsAlert,
    super.onJsConfirm,
    super.onJsPrompt,
    super.onReceivedHttpAuthRequest,
    super.onReceivedServerTrustAuthRequest,
    super.onReceivedClientCertRequest,
    @Deprecated('Use FindInteractionController.onFindResultReceived instead')
    super.onFindResultReceived,
    super.shouldInterceptAjaxRequest,
    super.onAjaxReadyStateChange,
    super.onAjaxProgress,
    super.shouldInterceptFetchRequest,
    super.onUpdateVisitedHistory,
    @Deprecated("Use onPrintRequest instead") super.onPrint,
    super.onPrintRequest,
    super.onLongPressHitTestResult,
    super.onEnterFullscreen,
    super.onExitFullscreen,
    super.onPageCommitVisible,
    super.onTitleChanged,
    super.onWindowFocus,
    super.onWindowBlur,
    super.onOverScrolled,
    super.onZoomScaleChanged,
    @Deprecated('Use onSafeBrowsingHit instead') super.androidOnSafeBrowsingHit,
    super.onSafeBrowsingHit,
    @Deprecated('Use onPermissionRequest instead')
    super.androidOnPermissionRequest,
    super.onPermissionRequest,
    @Deprecated('Use onGeolocationPermissionsShowPrompt instead')
    super.androidOnGeolocationPermissionsShowPrompt,
    super.onGeolocationPermissionsShowPrompt,
    @Deprecated('Use onGeolocationPermissionsHidePrompt instead')
    super.androidOnGeolocationPermissionsHidePrompt,
    super.onGeolocationPermissionsHidePrompt,
    @Deprecated('Use shouldInterceptRequest instead')
    super.androidShouldInterceptRequest,
    super.shouldInterceptRequest,
    @Deprecated('Use onRenderProcessGone instead')
    super.androidOnRenderProcessGone,
    super.onRenderProcessGone,
    @Deprecated('Use onRenderProcessResponsive instead')
    super.androidOnRenderProcessResponsive,
    super.onRenderProcessResponsive,
    @Deprecated('Use onRenderProcessUnresponsive instead')
    super.androidOnRenderProcessUnresponsive,
    super.onRenderProcessUnresponsive,
    @Deprecated('Use onFormResubmission instead')
    super.androidOnFormResubmission,
    super.onFormResubmission,
    @Deprecated('Use onZoomScaleChanged instead') super.androidOnScaleChanged,
    @Deprecated('Use onReceivedIcon instead') super.androidOnReceivedIcon,
    super.onReceivedIcon,
    @Deprecated('Use onReceivedTouchIconUrl instead')
    super.androidOnReceivedTouchIconUrl,
    super.onReceivedTouchIconUrl,
    @Deprecated('Use onJsBeforeUnload instead') super.androidOnJsBeforeUnload,
    super.onJsBeforeUnload,
    @Deprecated('Use onReceivedLoginRequest instead')
    super.androidOnReceivedLoginRequest,
    super.onReceivedLoginRequest,
    super.onPermissionRequestCanceled,
    super.onRequestFocus,
    @Deprecated('Use onWebContentProcessDidTerminate instead')
    super.iosOnWebContentProcessDidTerminate,
    super.onWebContentProcessDidTerminate,
    @Deprecated(
      'Use onDidReceiveServerRedirectForProvisionalNavigation instead',
    )
    super.iosOnDidReceiveServerRedirectForProvisionalNavigation,
    super.onDidReceiveServerRedirectForProvisionalNavigation,
    @Deprecated('Use onNavigationResponse instead')
    super.iosOnNavigationResponse,
    super.onNavigationResponse,
    @Deprecated('Use shouldAllowDeprecatedTLS instead')
    super.iosShouldAllowDeprecatedTLS,
    super.shouldAllowDeprecatedTLS,
    super.onCameraCaptureStateChanged,
    super.onMicrophoneCaptureStateChanged,
    super.onContentSizeChanged,
    super.onShowFileChooser,
    super.initialUrlRequest,
    super.initialFile,
    super.initialData,
    @Deprecated('Use initialSettings instead') super.initialOptions,
    super.initialSettings,
    super.contextMenu,
    super.initialUserScripts,
    this.pullToRefreshController,
    this.findInteractionController,
  });

  /// Constructs a [AndroidInAppWebViewWidgetCreationParams] using a
  /// [PlatformInAppWebViewWidgetCreationParams].
  AndroidInAppWebViewWidgetCreationParams.fromPlatformInAppWebViewWidgetCreationParams(
    PlatformInAppWebViewWidgetCreationParams params,
  ) : this(
        controllerFromPlatform: params.controllerFromPlatform,
        key: params.key,
        layoutDirection: params.layoutDirection,
        gestureRecognizers: params.gestureRecognizers,
        headlessWebView: params.headlessWebView,
        keepAlive: params.keepAlive,
        preventGestureDelay: params.preventGestureDelay,
        windowId: params.windowId,
        onWebViewCreated: params.onWebViewCreated,
        onLoadStart: params.onLoadStart,
        onLoadStop: params.onLoadStop,
        onLoadError: params.onLoadError,
        onReceivedError: params.onReceivedError,
        onLoadHttpError: params.onLoadHttpError,
        onReceivedHttpError: params.onReceivedHttpError,
        onProgressChanged: params.onProgressChanged,
        onConsoleMessage: params.onConsoleMessage,
        shouldOverrideUrlLoading: params.shouldOverrideUrlLoading,
        onLoadResource: params.onLoadResource,
        onScrollChanged: params.onScrollChanged,
        onDownloadStart: params.onDownloadStart,
        onDownloadStartRequest: params.onDownloadStartRequest,
        onDownloadStarting: params.onDownloadStarting,
        onLoadResourceCustomScheme: params.onLoadResourceCustomScheme,
        onLoadResourceWithCustomScheme: params.onLoadResourceWithCustomScheme,
        onCreateWindow: params.onCreateWindow,
        onCloseWindow: params.onCloseWindow,
        onJsAlert: params.onJsAlert,
        onJsConfirm: params.onJsConfirm,
        onJsPrompt: params.onJsPrompt,
        onReceivedHttpAuthRequest: params.onReceivedHttpAuthRequest,
        onReceivedServerTrustAuthRequest:
            params.onReceivedServerTrustAuthRequest,
        onReceivedClientCertRequest: params.onReceivedClientCertRequest,
        onFindResultReceived: params.onFindResultReceived,
        shouldInterceptAjaxRequest: params.shouldInterceptAjaxRequest,
        onAjaxReadyStateChange: params.onAjaxReadyStateChange,
        onAjaxProgress: params.onAjaxProgress,
        shouldInterceptFetchRequest: params.shouldInterceptFetchRequest,
        onUpdateVisitedHistory: params.onUpdateVisitedHistory,
        onPrint: params.onPrint,
        onPrintRequest: params.onPrintRequest,
        onLongPressHitTestResult: params.onLongPressHitTestResult,
        onEnterFullscreen: params.onEnterFullscreen,
        onExitFullscreen: params.onExitFullscreen,
        onPageCommitVisible: params.onPageCommitVisible,
        onTitleChanged: params.onTitleChanged,
        onWindowFocus: params.onWindowFocus,
        onWindowBlur: params.onWindowBlur,
        onOverScrolled: params.onOverScrolled,
        onZoomScaleChanged: params.onZoomScaleChanged,
        androidOnSafeBrowsingHit: params.androidOnSafeBrowsingHit,
        onSafeBrowsingHit: params.onSafeBrowsingHit,
        androidOnPermissionRequest: params.androidOnPermissionRequest,
        onPermissionRequest: params.onPermissionRequest,
        androidOnGeolocationPermissionsShowPrompt:
            params.androidOnGeolocationPermissionsShowPrompt,
        onGeolocationPermissionsShowPrompt:
            params.onGeolocationPermissionsShowPrompt,
        androidOnGeolocationPermissionsHidePrompt:
            params.androidOnGeolocationPermissionsHidePrompt,
        onGeolocationPermissionsHidePrompt:
            params.onGeolocationPermissionsHidePrompt,
        androidShouldInterceptRequest: params.androidShouldInterceptRequest,
        shouldInterceptRequest: params.shouldInterceptRequest,
        androidOnRenderProcessGone: params.androidOnRenderProcessGone,
        onRenderProcessGone: params.onRenderProcessGone,
        androidOnRenderProcessResponsive:
            params.androidOnRenderProcessResponsive,
        onRenderProcessResponsive: params.onRenderProcessResponsive,
        androidOnRenderProcessUnresponsive:
            params.androidOnRenderProcessUnresponsive,
        onRenderProcessUnresponsive: params.onRenderProcessUnresponsive,
        androidOnFormResubmission: params.androidOnFormResubmission,
        onFormResubmission: params.onFormResubmission,
        androidOnScaleChanged: params.androidOnScaleChanged,
        androidOnReceivedIcon: params.androidOnReceivedIcon,
        onReceivedIcon: params.onReceivedIcon,
        androidOnReceivedTouchIconUrl: params.androidOnReceivedTouchIconUrl,
        onReceivedTouchIconUrl: params.onReceivedTouchIconUrl,
        androidOnJsBeforeUnload: params.androidOnJsBeforeUnload,
        onJsBeforeUnload: params.onJsBeforeUnload,
        androidOnReceivedLoginRequest: params.androidOnReceivedLoginRequest,
        onReceivedLoginRequest: params.onReceivedLoginRequest,
        onPermissionRequestCanceled: params.onPermissionRequestCanceled,
        onRequestFocus: params.onRequestFocus,
        iosOnWebContentProcessDidTerminate:
            params.iosOnWebContentProcessDidTerminate,
        onWebContentProcessDidTerminate: params.onWebContentProcessDidTerminate,
        iosOnDidReceiveServerRedirectForProvisionalNavigation:
            params.iosOnDidReceiveServerRedirectForProvisionalNavigation,
        onDidReceiveServerRedirectForProvisionalNavigation:
            params.onDidReceiveServerRedirectForProvisionalNavigation,
        iosOnNavigationResponse: params.iosOnNavigationResponse,
        onNavigationResponse: params.onNavigationResponse,
        iosShouldAllowDeprecatedTLS: params.iosShouldAllowDeprecatedTLS,
        shouldAllowDeprecatedTLS: params.shouldAllowDeprecatedTLS,
        onCameraCaptureStateChanged: params.onCameraCaptureStateChanged,
        onMicrophoneCaptureStateChanged: params.onMicrophoneCaptureStateChanged,
        onContentSizeChanged: params.onContentSizeChanged,
        onShowFileChooser: params.onShowFileChooser,
        initialUrlRequest: params.initialUrlRequest,
        initialFile: params.initialFile,
        initialData: params.initialData,
        initialOptions: params.initialOptions,
        initialSettings: params.initialSettings,
        contextMenu: params.contextMenu,
        initialUserScripts: params.initialUserScripts,
        pullToRefreshController:
            params.pullToRefreshController as AndroidPullToRefreshController?,
        findInteractionController:
            params.findInteractionController
                as AndroidFindInteractionController?,
      );

  @override
  final AndroidFindInteractionController? findInteractionController;

  @override
  final AndroidPullToRefreshController? pullToRefreshController;
}

///{@macro flutter_inappwebview_platform_interface.PlatformInAppWebViewWidget}
class AndroidInAppWebViewWidget extends PlatformInAppWebViewWidget {
  /// Constructs a [AndroidInAppWebViewWidget].
  ///
  ///{@macro flutter_inappwebview_platform_interface.PlatformInAppWebViewWidget}
  AndroidInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params)
    : super.implementation(
        params is AndroidInAppWebViewWidgetCreationParams
            ? params
            : AndroidInAppWebViewWidgetCreationParams.fromPlatformInAppWebViewWidgetCreationParams(
                params,
              ),
      );

  AndroidInAppWebViewWidgetCreationParams get _androidParams =>
      params as AndroidInAppWebViewWidgetCreationParams;

  AndroidInAppWebViewController? _controller;

  AndroidHeadlessInAppWebView? get _androidHeadlessInAppWebView =>
      params.headlessWebView as AndroidHeadlessInAppWebView?;

  static final AndroidInAppWebViewWidget _staticValue =
      AndroidInAppWebViewWidget(AndroidInAppWebViewWidgetCreationParams());

  factory AndroidInAppWebViewWidget.static() {
    return _staticValue;
  }

  @override
  Widget build(BuildContext context) {
    final initialSettings = params.initialSettings ?? InAppWebViewSettings();
    _inferInitialSettings(initialSettings);

    Map<String, dynamic> settingsMap =
        (params.initialSettings != null ? initialSettings.toMap() : null) ??
        // ignore: deprecated_member_use_from_same_package
        params.initialOptions?.toMap() ??
        initialSettings.toMap();

    Map<String, dynamic> pullToRefreshSettings =
        params.pullToRefreshController?.params.settings.toMap() ??
        // ignore: deprecated_member_use_from_same_package
        params.pullToRefreshController?.params.options.toMap() ??
        PullToRefreshSettings(enabled: false).toMap();

    if ((params.headlessWebView?.isRunning() ?? false) &&
        params.keepAlive != null) {
      final headlessId = params.headlessWebView?.id;
      if (headlessId != null) {
        // force keep alive id to match headless webview id
        params.keepAlive?.id = headlessId;
      }
    }

    if (!_isAutoCompositionMode(initialSettings)) {
      return _buildPlatformView(
        context: context,
        initialSettings: initialSettings,
        settingsMap: settingsMap,
        pullToRefreshSettings: pullToRefreshSettings,
        hcppSupported: isHybridCompositionPlusPlusSupported,
      );
    }

    // Auto mode has to know the answer before creating the view -- the composition mode is fixed
    // at creation and cannot be changed afterwards. Waiting here is what makes "use HCPP whenever
    // it works" actually hold; deciding early would silently pin this WebView to TLHC whenever
    // the check happened to still be in flight.
    //
    // The future is memoised, so a rebuild does not restart it and does not tear down a WebView
    // that has already been created. initialData short-circuits the wait once the answer is
    // already known, and the FutureBuilder stays in the tree either way so the shape never
    // changes under an existing platform view.
    return FutureBuilder<bool>(
      future: _autoCompositionModeSupport(),
      initialData: isHybridCompositionPlusPlusSupported ? true : null,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return _buildPlatformView(
          context: context,
          initialSettings: initialSettings,
          settingsMap: settingsMap,
          pullToRefreshSettings: pullToRefreshSettings,
          hcppSupported: snapshot.data!,
        );
      },
    );
  }

  /// Whether this WebView left the composition mode unspecified, and therefore gets whichever
  /// mode the device can actually run.
  ///
  /// The deprecated `useHybridComposition: true` still counts as a choice, so existing code that
  /// asked for Hybrid Composition keeps getting it.
  bool _isAutoCompositionMode(InAppWebViewSettings initialSettings) {
    final explicit = params.initialSettings != null
        ? initialSettings.androidCompositionMode
        : null;
    if (explicit != null) {
      return false;
    }
    final legacy =
        (params.initialSettings != null
            ? initialSettings.useHybridComposition
            // ignore: deprecated_member_use_from_same_package
            : params.initialOptions?.android.useHybridComposition) ??
        false;
    return !legacy;
  }

  Widget _buildPlatformView({
    required BuildContext context,
    required InAppWebViewSettings initialSettings,
    required Map<String, dynamic> settingsMap,
    required Map<String, dynamic> pullToRefreshSettings,
    required bool hcppSupported,
  }) {
    final compositionMode = _resolveCompositionMode(
      initialSettings,
      hcppSupported: hcppSupported,
    );

    // The native side branches on a single boolean that really asks "is the WebView in the real
    // view hierarchy?". HCPP is, exactly like Hybrid Composition, so both report true.
    settingsMap['useHybridComposition'] =
        compositionMode !=
        AndroidCompositionMode.TEXTURE_LAYER_HYBRID_COMPOSITION;

    return PlatformViewLink(
      key: params.key,
      viewType: 'com.pichillilorenzo/flutter_inappwebview',
      surfaceFactory:
          (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers:
                  params.gestureRecognizers ??
                  const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
      onCreatePlatformView: (PlatformViewCreationParams params) {
        return _createAndroidViewController(
            compositionMode: compositionMode,
            id: params.id,
            viewType: 'com.pichillilorenzo/flutter_inappwebview',
            layoutDirection:
                this.params.layoutDirection ??
                Directionality.maybeOf(context) ??
                TextDirection.rtl,
            creationParams: <String, dynamic>{
              'initialUrlRequest': this.params.initialUrlRequest?.toMap(),
              'initialFile': this.params.initialFile,
              'initialData': this.params.initialData?.toMap(),
              'initialSettings': settingsMap,
              'contextMenu': this.params.contextMenu?.toMap() ?? {},
              'windowId': this.params.windowId,
              'headlessWebViewId':
                  this.params.headlessWebView?.isRunning() ?? false
                  ? this.params.headlessWebView?.id
                  : null,
              'initialUserScripts':
                  this.params.initialUserScripts
                      ?.map((e) => e.toMap())
                      .toList() ??
                  [],
              'pullToRefreshSettings': pullToRefreshSettings,
              'keepAliveId': this.params.keepAlive?.id,
              'enabledHighFrequencyEvents': enabledHighFrequencyEvents(
                webviewParams: this.params,
                hasInAppBrowserEventHandler: false,
              ),
            },
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener((id) => _onPlatformViewCreated(id))
          ..create();
      },
    );
  }

  /// Which composition mode this WebView ends up with.
  ///
  /// [InAppWebViewSettings.androidCompositionMode] wins when set; otherwise the deprecated
  /// [InAppWebViewSettings.useHybridComposition] still decides, so existing code keeps its
  /// behaviour. With neither set the mode is chosen automatically: HCPP where it works, Texture
  /// Layer Hybrid Composition everywhere else.
  ///
  /// A request for HCPP -- automatic or explicit -- is downgraded to Texture Layer Hybrid
  /// Composition unless the device and application actually support it.
  AndroidCompositionMode _resolveCompositionMode(
    InAppWebViewSettings initialSettings, {
    required bool hcppSupported,
  }) {
    final auto = hcppSupported
        ? AndroidCompositionMode.HYBRID_COMPOSITION_PLUS_PLUS
        : AndroidCompositionMode.TEXTURE_LAYER_HYBRID_COMPOSITION;

    final requested =
        (params.initialSettings != null
            ? initialSettings.androidCompositionMode
            : null) ??
        ((params.initialSettings != null
                    ? initialSettings.useHybridComposition
                    // ignore: deprecated_member_use_from_same_package
                    : params.initialOptions?.android.useHybridComposition) ??
                false
            ? AndroidCompositionMode.HYBRID_COMPOSITION
            : auto);

    if (requested == AndroidCompositionMode.HYBRID_COMPOSITION_PLUS_PLUS &&
        !hcppSupported) {
      return AndroidCompositionMode.TEXTURE_LAYER_HYBRID_COMPOSITION;
    }
    return requested;
  }

  AndroidViewController _createAndroidViewController({
    required AndroidCompositionMode compositionMode,
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    required Map<String, dynamic> creationParams,
  }) {
    if (compositionMode ==
        AndroidCompositionMode.HYBRID_COMPOSITION_PLUS_PLUS) {
      return PlatformViewsService.initHybridAndroidView(
        id: id,
        viewType: viewType,
        layoutDirection: layoutDirection,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    if (compositionMode == AndroidCompositionMode.HYBRID_COMPOSITION) {
      return PlatformViewsService.initExpensiveAndroidView(
        id: id,
        viewType: viewType,
        layoutDirection: layoutDirection,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return PlatformViewsService.initSurfaceAndroidView(
      id: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  void _onPlatformViewCreated(int id) {
    dynamic viewId = id;
    if (params.headlessWebView?.isRunning() ?? false) {
      viewId = params.headlessWebView?.id;
    }
    viewId = params.keepAlive?.id ?? viewId ?? id;
    _androidHeadlessInAppWebView?.internalDispose();
    _controller = AndroidInAppWebViewController(
      PlatformInAppWebViewControllerCreationParams(
        id: viewId,
        webviewParams: params,
      ),
    );
    // The creation parameters already carried this, but a keepAlive WebView outlives the widget
    // that created it and can be reattached to one with a different set of callbacks.
    _controller?.syncEnabledHighFrequencyEvents();
    // keyboardAvoidance defaults to true, so an absent setting still means enabled. Below API 30
    // the native side depends on this reporting for the keyboard height; above it the value is
    // ignored, so no OS version check is needed here.
    //
    // Read through the map rather than the getter: this package depends on the published
    // platform interface (see pubspec.yaml), which does not carry this fork's settings, so the
    // typed access would not analyze even though it resolves fine for apps that override all
    // three packages together.
    final keyboardAvoidance =
        params.initialSettings?.toMap()['keyboardAvoidance'] as bool?;
    if (keyboardAvoidance ?? true) {
      _controller?.startFrameworkKeyboardInsetReporting();
    }
    _androidParams.pullToRefreshController?.init(viewId);
    _androidParams.findInteractionController?.init(viewId);
    debugLog(
      className: runtimeType.toString(),
      id: viewId?.toString(),
      debugLoggingSettings: PlatformInAppWebViewController.debugLoggingSettings,
      method: "onWebViewCreated",
      args: [],
    );
    if (params.onWebViewCreated != null) {
      params.onWebViewCreated!(
        params.controllerFromPlatform?.call(_controller!) ?? _controller!,
      );
    }
  }

  void _inferInitialSettings(InAppWebViewSettings settings) {
    if (params.shouldOverrideUrlLoading != null &&
        settings.useShouldOverrideUrlLoading == null) {
      settings.useShouldOverrideUrlLoading = true;
    }
    if (params.onLoadResource != null && settings.useOnLoadResource == null) {
      settings.useOnLoadResource = true;
    }
    if ((params.onDownloadStartRequest != null ||
            params.onDownloadStarting != null) &&
        settings.useOnDownloadStart == null) {
      settings.useOnDownloadStart = true;
    }
    if ((params.shouldInterceptAjaxRequest != null ||
        params.onAjaxProgress != null ||
        params.onAjaxReadyStateChange != null)) {
      if (settings.useShouldInterceptAjaxRequest == null) {
        settings.useShouldInterceptAjaxRequest = true;
      }
      if (params.onAjaxReadyStateChange != null &&
          settings.useOnAjaxReadyStateChange == null) {
        settings.useOnAjaxReadyStateChange = true;
      }
      if (params.onAjaxProgress != null && settings.useOnAjaxProgress == null) {
        settings.useOnAjaxProgress = true;
      }
    }
    if (params.shouldInterceptFetchRequest != null &&
        settings.useShouldInterceptFetchRequest == null) {
      settings.useShouldInterceptFetchRequest = true;
    }
    if (params.shouldInterceptRequest != null &&
        settings.useShouldInterceptRequest == null) {
      settings.useShouldInterceptRequest = true;
    }
    if (params.onRenderProcessGone != null &&
        settings.useOnRenderProcessGone == null) {
      settings.useOnRenderProcessGone = true;
    }
    if (params.onNavigationResponse != null &&
        settings.useOnNavigationResponse == null) {
      settings.useOnNavigationResponse = true;
    }
    if (params.onShowFileChooser != null &&
        settings.useOnShowFileChooser == null) {
      settings.useOnShowFileChooser = true;
    }
  }

  @override
  void dispose() {
    dynamic viewId = _controller?.getViewId();
    debugLog(
      className: runtimeType.toString(),
      id: viewId?.toString(),
      debugLoggingSettings: PlatformInAppWebViewController.debugLoggingSettings,
      method: "dispose",
      args: [],
    );
    final isKeepAlive = params.keepAlive != null;
    _controller?.dispose(isKeepAlive: isKeepAlive);
    _controller = null;
    params.pullToRefreshController?.dispose(isKeepAlive: isKeepAlive);
    params.findInteractionController?.dispose(isKeepAlive: isKeepAlive);
  }

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    // unused
    throw UnimplementedError();
  }
}
