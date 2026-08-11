package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.view.View;
import android.webkit.JavascriptInterface;

import androidx.annotation.NonNull;

/**
 * Shifts the WebView up so the focused editable element clears the soft keyboard.
 *
 * <p>This only runs once {@link InputAwareWebView} has consumed the IME insets, which stops
 * Chromium from performing its own {@code ScrollFocusedEditableIntoView}. Without that, both would
 * move the content and the shifts would add up.
 *
 * <p>The WebView is translated as a whole rather than scrolled internally, so page content is never
 * relaid out. The strip revealed below the view's shifted bottom edge sits behind the keyboard, and
 * the shift is clamped to the keyboard height so it can never become visible.
 */
public class KeyboardAvoidanceController {
  /** Gap left between the bottom of the focused element and the top of the keyboard, in dp. */
  private static final int MARGIN_DP = 8;

  /** Sentinel for "no editable element is focused". */
  private static final float NO_FOCUS = -1f;

  @NonNull
  private final View webView;

  /** Height of the consumed IME inset in physical pixels; 0 while the keyboard is closed. */
  private int keyboardHeightPx = 0;

  /** Bottom edge of the focused element in physical pixels, or {@link #NO_FOCUS}. */
  private float focusedBottomPx = NO_FOCUS;

  public KeyboardAvoidanceController(@NonNull View webView) {
    this.webView = webView;
  }

  /**
   * @param heightPx height of the IME inset in physical pixels, 0 when the keyboard is closed
   */
  public void setKeyboardHeightPx(int heightPx) {
    if (keyboardHeightPx == heightPx) {
      return;
    }
    keyboardHeightPx = heightPx;
    applyShift();
  }

  /**
   * Called from the injected script whenever the focused element changes or the page scrolls.
   *
   * @param bottomCssPx      bottom edge of the focused element in CSS pixels
   * @param devicePixelRatio the page's {@code window.devicePixelRatio}, folding in density and zoom
   */
  @JavascriptInterface
  public void onFocusedRect(final float bottomCssPx, final float devicePixelRatio) {
    // @JavascriptInterface methods arrive on a background thread; every field below is only
    // touched from the UI thread so the shift cannot race the insets callback.
    webView.post(new Runnable() {
      @Override
      public void run() {
        focusedBottomPx = bottomCssPx * devicePixelRatio;
        applyShift();
      }
    });
  }

  /** Called from the injected script when focus leaves every editable element. */
  @JavascriptInterface
  public void onFocusCleared() {
    webView.post(new Runnable() {
      @Override
      public void run() {
        focusedBottomPx = NO_FOCUS;
        applyShift();
      }
    });
  }

  /** Drops any applied shift. Used when the setting is turned off or the view goes away. */
  public void reset() {
    keyboardHeightPx = 0;
    focusedBottomPx = NO_FOCUS;
    webView.setTranslationY(0f);
  }

  private void applyShift() {
    webView.setTranslationY(-computeShiftPx());
  }

  private float computeShiftPx() {
    if (keyboardHeightPx <= 0 || focusedBottomPx == NO_FOCUS) {
      return 0f;
    }

    final float marginPx = MARGIN_DP * webView.getResources().getDisplayMetrics().density;
    // The element's position is measured against the untranslated view, so the visible area is
    // simply the view height minus the keyboard.
    final float visibleBottomPx = webView.getHeight() - keyboardHeightPx;
    final float overlapPx = focusedBottomPx + marginPx - visibleBottomPx;
    if (overlapPx <= 0f) {
      return 0f;
    }

    // Shifting further than the keyboard height would expose the revealed strip above the
    // keyboard's top edge, so the gap would become visible.
    return Math.min(overlapPx, keyboardHeightPx);
  }
}
