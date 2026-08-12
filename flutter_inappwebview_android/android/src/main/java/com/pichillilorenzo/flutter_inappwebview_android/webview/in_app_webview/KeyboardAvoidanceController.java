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

  /** Scratch buffer for {@link View#getLocationInWindow}; reused to keep this off the hot path. */
  private final int[] locationInWindow = new int[2];

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

    // Compared in window coordinates rather than inside the view, because the host may already
    // have shrunk the WebView for the keyboard (Scaffold.resizeToAvoidBottomInset left at its
    // default true). Measuring as `viewHeight - keyboardHeight` would then subtract the keyboard
    // twice and overshoot -- reintroducing the doubled shift this option exists to remove. In
    // window coordinates the shrink is already reflected in the view's own position and height,
    // so both host configurations fall out of the same arithmetic.
    webView.getLocationInWindow(locationInWindow);
    // getLocationInWindow reports where the view is drawn, translation included. Backing it out
    // gives a fixed reference, which keeps this idempotent -- recomputing without any change to
    // the inputs must not walk the view further up each time.
    final float untranslatedTopInWindow = locationInWindow[1] - webView.getTranslationY();
    final float keyboardTopInWindow = webView.getRootView().getHeight() - keyboardHeightPx;

    final float overlapPx =
            untranslatedTopInWindow + focusedBottomPx + marginPx - keyboardTopInWindow;
    if (overlapPx <= 0f) {
      return 0f;
    }

    // Shifting further than the keyboard height would expose the strip revealed below the view's
    // bottom edge above the keyboard's top edge, making the gap visible.
    return Math.min(overlapPx, keyboardHeightPx);
  }
}
