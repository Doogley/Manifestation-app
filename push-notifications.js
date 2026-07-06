// ── DAILY REMINDER NOTIFICATIONS ──
// Uses the raw Capacitor.Plugins.LocalNotifications proxy (no bundler in
// this project). Every function is a safe no-op on the web so
// alreadymine.app keeps working unchanged.
//
// Requires @capacitor/local-notifications (already in package.json); run
// `npx cap sync` on the Mac after pulling so the native plugin is added.
//
// The reminder is a single repeating local notification. iOS/Android keep
// the same body text until it is rescheduled, so a fresh random message is
// picked each time setupNotifications() runs (every app launch after login).

(function () {
  'use strict';

  var REMINDER_ID = 1001;
  // Per-device preference ('1' on, '0' off; unset defaults to on — the
  // permission check is what actually gates scheduling).
  var STORAGE_KEY = 'am_daily_reminder';

  var REMINDER_MESSAGES = [
    'Your affirmation is waiting for you.',
    'A moment of intention can change your whole day.',
    'Step inside — your practice is ready.',
    "Today's affirmation was chosen just for you.",
    'Two minutes. One affirmation. Already yours.',
    'Your streak is alive. Keep it going.',
    'The practice is waiting. You are ready.',
    'Something new is waiting inside.',
    'Show up for yourself today.',
    "Your daily reminder that it's already yours."
  ];

  // answers.timing → local hour of the daily reminder.
  var TIMING_HOURS = {
    morning: 8,
    midday: 12,
    evening: 18,
    anytime: 9,
    random: 9 // "Surprise me" — treat like anytime
  };

  function notificationsPlugin() {
    var cap = window.Capacitor;
    if (!cap || !cap.isNativePlatform || !cap.isNativePlatform()) return null;
    return (cap.Plugins && cap.Plugins.LocalNotifications) || null;
  }

  function randomMessage() {
    return REMINDER_MESSAGES[Math.floor(Math.random() * REMINDER_MESSAGES.length)];
  }

  function timingToHour(timing) {
    return TIMING_HOURS[timing] != null ? TIMING_HOURS[timing] : TIMING_HOURS.anytime;
  }

  // The user's on/off choice for this device. Independent of the OS
  // permission — both must allow before anything is scheduled.
  function isEnabled() {
    try { return localStorage.getItem(STORAGE_KEY) !== '0'; } catch (e) { return true; }
  }

  function rememberEnabled(on) {
    try { localStorage.setItem(STORAGE_KEY, on ? '1' : '0'); } catch (e) {}
  }

  // True when the OS permission is already granted. Never prompts.
  async function hasPermission() {
    var ln = notificationsPlugin();
    if (!ln) return false;
    try {
      var status = await ln.checkPermissions();
      return status.display === 'granted';
    } catch (e) {
      console.error('[AMNotifications] checkPermissions failed:', e);
      return false;
    }
  }

  // Prompts the user if permission hasn't been decided yet. Returns
  // whether permission is granted. Always false on web.
  async function requestNotificationPermission() {
    var ln = notificationsPlugin();
    if (!ln) return false;
    try {
      var status = await ln.checkPermissions();
      if (status.display !== 'granted') {
        status = await ln.requestPermissions();
      }
      return status.display === 'granted';
    } catch (e) {
      console.error('[AMNotifications] requestPermissions failed:', e);
      return false;
    }
  }

  // Clears every scheduled notification (there is only ever the one
  // daily reminder, but clear all so nothing stale survives).
  async function cancelAllNotifications() {
    var ln = notificationsPlugin();
    if (!ln) return;
    try {
      var pending = await ln.getPending();
      if (pending && pending.notifications && pending.notifications.length) {
        await ln.cancel({ notifications: pending.notifications.map(function (n) { return { id: n.id }; }) });
      }
    } catch (e) {
      console.error('[AMNotifications] cancel failed:', e);
    }
  }

  // Schedules the repeating daily reminder at hour:minute local time,
  // replacing any existing one.
  async function scheduleDailyReminder(hour, minute) {
    var ln = notificationsPlugin();
    if (!ln) return;
    await cancelAllNotifications();
    try {
      await ln.schedule({
        notifications: [{
          id: REMINDER_ID,
          title: 'Already Mine',
          body: randomMessage(),
          schedule: {
            on: { hour: hour, minute: minute || 0 }, // repeats daily
            allowWhileIdle: true
          }
        }]
      });
    } catch (e) {
      console.error('[AMNotifications] schedule failed:', e);
    }
  }

  // Cancels the current reminder and reschedules at the new time.
  async function updateNotificationTime(hour, minute) {
    var ln = notificationsPlugin();
    if (!ln) return;
    await cancelAllNotifications();
    await scheduleDailyReminder(hour, minute);
  }

  // Called after login (and whenever the timing preference changes).
  // Only schedules when the OS permission was already granted AND the
  // user hasn't turned the toggle off — never prompts, so a user who
  // hasn't been asked yet is left alone until they opt in from Profile.
  async function setupNotifications(timing) {
    var ln = notificationsPlugin();
    if (!ln) return;
    if (!isEnabled()) return;
    if (!(await hasPermission())) return;
    await scheduleDailyReminder(timingToHour(timing), 0);
  }

  // Backs the Profile toggle. Turning on prompts for permission if
  // needed; returns false (and remembers "off") when the user denies it
  // so the toggle can be reverted.
  async function setDailyReminderEnabled(on, timing) {
    if (!on) {
      rememberEnabled(false);
      await cancelAllNotifications();
      return true;
    }
    var granted = await requestNotificationPermission();
    if (!granted) {
      rememberEnabled(false);
      return false;
    }
    rememberEnabled(true);
    await scheduleDailyReminder(timingToHour(timing), 0);
    return true;
  }

  window.AMNotifications = {
    scheduleDailyReminder: scheduleDailyReminder,
    cancelAllNotifications: cancelAllNotifications,
    updateNotificationTime: updateNotificationTime,
    requestNotificationPermission: requestNotificationPermission,
    setupNotifications: setupNotifications,
    setDailyReminderEnabled: setDailyReminderEnabled,
    hasPermission: hasPermission,
    isEnabled: isEnabled,
    timingToHour: timingToHour
  };
})();
