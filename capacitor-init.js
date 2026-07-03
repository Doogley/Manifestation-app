// ── CAPACITOR NATIVE-SHELL SETUP ──
// Loaded on both web (alreadymine.app) and native (iOS/Android via Capacitor).
// This app has no bundler, so plugins are reached through the
// window.Capacitor.Plugins proxy that the native runtime injects at page
// load — not through npm imports. On the plain web, window.Capacitor does
// not exist and everything here no-ops.

(function () {
  'use strict';

  var cap = window.Capacitor;
  var isNative = !!(cap && cap.isNativePlatform && cap.isNativePlatform());
  var platform = isNative ? cap.getPlatform() : 'web'; // 'ios' | 'android' | 'web'

  function plugin(name) {
    if (!isNative || !cap.Plugins || !cap.Plugins[name]) return null;
    return cap.Plugins[name];
  }

  // Global handle the rest of the app uses for platform detection.
  window.AMNative = {
    isNative: isNative,
    platform: platform,
    isIOS: platform === 'ios',
    isAndroid: platform === 'android',
    plugin: plugin,

    // Light haptic tap; safe to call anywhere.
    haptic: function (style) {
      var h = plugin('Haptics');
      if (!h) return;
      h.impact({ style: style || 'LIGHT' }).catch(function () {});
    }
  };

  if (!isNative) return; // web browser — nothing else to do

  document.addEventListener('DOMContentLoaded', function () {
    // Status bar: light text over the app's dark theme (#1a1610).
    var statusBar = plugin('StatusBar');
    if (statusBar) {
      statusBar.setStyle({ style: 'DARK' }).catch(function () {});
      if (platform === 'android') {
        statusBar.setBackgroundColor({ color: '#1a1610' }).catch(function () {});
        statusBar.setOverlaysWebView({ overlay: false }).catch(function () {});
      }
    }

    // Keyboard: resize the body so inputs stay visible, and don't scroll
    // the page under the accessory bar on iOS.
    var keyboard = plugin('Keyboard');
    if (keyboard) {
      keyboard.setResizeMode({ mode: 'body' }).catch(function () {});
      if (platform === 'ios') {
        keyboard.setScroll({ isDisabled: false }).catch(function () {});
      }
    }

    // Splash screen: config in capacitor.config.json auto-hides it after
    // 2s, but hide explicitly once the DOM is ready so a fast load isn't
    // stuck behind the splash.
    var splash = plugin('SplashScreen');
    if (splash) {
      splash.hide().catch(function () {});
    }

    // App lifecycle: Android hardware back button should navigate within
    // the app instead of instantly exiting.
    var app = plugin('App');
    if (app && platform === 'android') {
      app.addListener('backButton', function (ev) {
        if (ev && ev.canGoBack) {
          window.history.back();
        } else if (app.minimizeApp) {
          app.minimizeApp();
        }
      });
    }

    // RevenueCat — defined in revenuecat-handler.js.
    if (window.AMPurchases && window.AMPurchases.initializePurchases) {
      window.AMPurchases.initializePurchases().catch(function (e) {
        console.error('[AMNative] RevenueCat init failed:', e);
      });
    }

    // Let the app know the native layer is ready (index.html listens for
    // this to show native-only UI like Restore Purchases).
    document.dispatchEvent(new CustomEvent('am-native-ready', {
      detail: { platform: platform }
    }));
  });
})();
