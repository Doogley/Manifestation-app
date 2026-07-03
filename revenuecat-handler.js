// ── REVENUECAT PURCHASE HANDLING ──
// Uses the raw Capacitor.Plugins.Purchases proxy (no bundler in this
// project). Every function resolves to a safe no-op result on the web so
// alreadymine.app keeps working unchanged.
//
// BEFORE SHIPPING, replace the placeholders below with real values from
// the RevenueCat dashboard (see MAC_SESSION_GUIDE.md):

var RC_API_KEY_IOS = 'REVENUECAT_IOS_API_KEY_PLACEHOLDER';        // appl_xxxx
var RC_API_KEY_ANDROID = 'REVENUECAT_ANDROID_API_KEY_PLACEHOLDER'; // goog_xxxx
var RC_ENTITLEMENT_ID = 'member'; // the entitlement that unlocks paid features

// App Store Connect / Play Console product identifiers.
var RC_PRODUCTS = {
  monthly: 'am_member_monthly',
  annual: 'am_member_annual'
};

(function () {
  'use strict';

  var configured = false;

  function purchasesPlugin() {
    var cap = window.Capacitor;
    if (!cap || !cap.isNativePlatform || !cap.isNativePlatform()) return null;
    return (cap.Plugins && cap.Plugins.Purchases) || null;
  }

  function hasEntitlement(customerInfo) {
    return !!(customerInfo &&
      customerInfo.entitlements &&
      customerInfo.entitlements.active &&
      customerInfo.entitlements.active[RC_ENTITLEMENT_ID]);
  }

  // Configure RevenueCat. Called automatically by capacitor-init.js on
  // native; resolves false on web. Pass a Supabase user id as appUserID
  // so purchases follow the account across devices.
  async function initializePurchases(appUserID) {
    var purchases = purchasesPlugin();
    if (!purchases) return false;
    if (configured) {
      if (appUserID) {
        await purchases.logIn({ appUserID: String(appUserID) }).catch(function () {});
      }
      return true;
    }
    var apiKey = window.AMNative && window.AMNative.isAndroid
      ? RC_API_KEY_ANDROID
      : RC_API_KEY_IOS;
    var options = { apiKey: apiKey };
    if (appUserID) options.appUserID = String(appUserID);
    await purchases.configure(options);
    configured = true;
    return true;
  }

  // Returns true when the user has the active paid entitlement.
  // Always false on web (web membership state comes from Supabase).
  async function checkSubscriptionStatus() {
    var purchases = purchasesPlugin();
    if (!purchases || !configured) return false;
    try {
      var result = await purchases.getCustomerInfo();
      return hasEntitlement(result && result.customerInfo);
    } catch (e) {
      console.error('[AMPurchases] getCustomerInfo failed:', e);
      return false;
    }
  }

  // Runs the native purchase sheet for the given product id
  // (RC_PRODUCTS.monthly or RC_PRODUCTS.annual).
  // Resolves { success, cancelled, error, isPaid }.
  async function purchaseSubscription(productId) {
    var purchases = purchasesPlugin();
    if (!purchases) {
      return { success: false, cancelled: false, isPaid: false, error: 'Purchases are only available in the iOS or Android app.' };
    }
    try {
      if (!configured) await initializePurchases();

      // Find the matching package in the current offering so RevenueCat
      // attributes the purchase correctly.
      var offerings = await purchases.getOfferings();
      var pkg = null;
      var current = offerings && offerings.current;
      if (current && current.availablePackages) {
        pkg = current.availablePackages.find(function (p) {
          return p.product && p.product.identifier === productId;
        }) || null;
      }

      var result;
      if (pkg) {
        result = await purchases.purchasePackage({ aPackage: pkg });
      } else {
        // Fall back to a direct product purchase if the offering doesn't
        // include this product.
        var products = await purchases.getProducts({ productIdentifiers: [productId] });
        var product = products && products.products && products.products[0];
        if (!product) {
          return { success: false, cancelled: false, isPaid: false, error: 'Product not found: ' + productId };
        }
        result = await purchases.purchaseStoreProduct({ product: product });
      }

      var isPaid = hasEntitlement(result && result.customerInfo);
      return { success: isPaid, cancelled: false, isPaid: isPaid, error: isPaid ? null : 'Purchase completed but entitlement not active.' };
    } catch (e) {
      // RevenueCat marks user-cancelled purchases; don't treat those as errors.
      var cancelled = !!(e && (e.userCancelled || /cancel/i.test(e.message || '') || String(e.code) === '1'));
      if (!cancelled) console.error('[AMPurchases] purchase failed:', e);
      return { success: false, cancelled: cancelled, isPaid: false, error: cancelled ? null : ((e && e.message) || 'Purchase failed.') };
    }
  }

  // "Restore Purchases" button (required by Apple for subscriptions).
  // Resolves { success, isPaid, error }.
  async function restorePurchases() {
    var purchases = purchasesPlugin();
    if (!purchases) {
      return { success: false, isPaid: false, error: 'Restore is only available in the iOS or Android app.' };
    }
    try {
      if (!configured) await initializePurchases();
      var result = await purchases.restorePurchases();
      var isPaid = hasEntitlement(result && result.customerInfo);
      return { success: true, isPaid: isPaid, error: null };
    } catch (e) {
      console.error('[AMPurchases] restore failed:', e);
      return { success: false, isPaid: false, error: (e && e.message) || 'Restore failed.' };
    }
  }

  window.AMPurchases = {
    initializePurchases: initializePurchases,
    checkSubscriptionStatus: checkSubscriptionStatus,
    purchaseSubscription: purchaseSubscription,
    restorePurchases: restorePurchases,
    PRODUCTS: RC_PRODUCTS,
    ENTITLEMENT_ID: RC_ENTITLEMENT_ID
  };
})();
