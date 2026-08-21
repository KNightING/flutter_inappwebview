import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

part 'android_composition_mode.g.dart';

///Class that represents how the Android WebView is composited with the Flutter UI,
///used by `InAppWebViewSettings.androidCompositionMode`.
@ExchangeableEnum()
class AndroidCompositionMode_ {
  // ignore: unused_field
  final int _value;
  const AndroidCompositionMode_._internal(this._value);

  ///Texture Layer Hybrid Composition: the WebView draws into a texture that Flutter composites.
  ///Flutter only pays for its own composition, and the raster and platform threads stay separate.
  ///This is the default.
  @EnumSupportedPlatforms(platforms: [EnumAndroidPlatform()])
  static const TEXTURE_LAYER_HYBRID_COMPOSITION =
      const AndroidCompositionMode_._internal(0);

  ///Hybrid Composition: the WebView is placed in the real Android view hierarchy and Flutter
  ///draws its own content into `FlutterImageView`s above it. Full native fidelity, but Flutter
  ///pays to composite everything drawn over the WebView and the raster and platform threads
  ///are merged.
  @EnumSupportedPlatforms(platforms: [EnumAndroidPlatform()])
  static const HYBRID_COMPOSITION = const AndroidCompositionMode_._internal(1);

  ///Hybrid Composition++: the WebView and Flutter each draw into their own native Surface and
  ///SurfaceFlinger composites them. Full native fidelity without the thread merge.
  ///
  ///**Requires Android API 34+, a Vulkan-capable device, and the embedding application to opt in**
  ///by declaring `io.flutter.embedding.android.EnableHcpp` in its `AndroidManifest.xml`.
  ///A plugin cannot enable it on the application's behalf. When any of those is missing, the
  ///WebView falls back to [TEXTURE_LAYER_HYBRID_COMPOSITION].
  @EnumSupportedPlatforms(platforms: [EnumAndroidPlatform(available: '34')])
  static const HYBRID_COMPOSITION_PLUS_PLUS =
      const AndroidCompositionMode_._internal(2);
}
