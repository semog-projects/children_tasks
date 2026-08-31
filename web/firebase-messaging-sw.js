/* Service worker do Firebase Cloud Messaging (web).
 *
 * Config = projeto de DEV (o mesmo de lib/src/app/firebase/firebase_options_dev.dart).
 * Para um build de PROD web, troque por firebase_options_prod.dart ou gere
 * este arquivo no pipeline de build.
 */
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyCOkw8s69VLb45mXwb3MsjJ4NiTmuOUvLQ",
  appId: "1:657934624182:web:bc5fe9b2e5b492ed8d8d17",
  messagingSenderId: "657934624182",
  projectId: "children-tasks-dev",
  authDomain: "children-tasks-dev.firebaseapp.com",
  storageBucket: "children-tasks-dev.firebasestorage.app",
});

firebase.messaging();
