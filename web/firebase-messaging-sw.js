// Web push: shows Squad HQ notifications while the web app is closed or in
// the background. Firebase Messaging registers this file by name.
//
// The config below is the Firebase *web app* config — public values every
// browser receives anyway, not secrets. A service worker can't read the
// app's --dart-define values, so they're repeated here; keep them in sync
// with the FIREBASE_* keys in .env.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyA7zfULQvDcaFsNEQhIVtT9byVTcN2cHcE',
  authDomain: 'my-project-1542101276805.firebaseapp.com',
  projectId: 'my-project-1542101276805',
  storageBucket: 'my-project-1542101276805.firebasestorage.app',
  messagingSenderId: '968619530713',
  appId: '1:968619530713:web:ac56f2546bffda1d81a1c8',
});

// Pushes carry a `notification` payload, which the Firebase SDK shows on
// its own; the click opens `webpush.fcm_options.link` (the right tab).
firebase.messaging();
