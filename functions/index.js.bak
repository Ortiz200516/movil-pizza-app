const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp }     = require("firebase-admin/app");
const { getFirestore }      = require("firebase-admin/firestore");
const { getMessaging }      = require("firebase-admin/messaging");

initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function: enviarNotificacionPush
// Se dispara cuando se crea un documento en /notificaciones
// ─────────────────────────────────────────────────────────────────────────────
exports.enviarNotificacionPush = onDocumentCreated(
  "notificaciones/{docId}",
  async (event) => {
    const data = event.data.data();
    const ref  = event.data.ref;

    const titulo   = data.titulo   || "";
    const cuerpo   = data.cuerpo   || "";
    const tipo     = data.tipo     || "info";
    const pedidoId = data.pedidoId || null;
    const uid      = data.uid      || null;
    const rol      = data.rol      || null;

    if (!titulo) return;

    const db  = getFirestore();
    const fcm = getMessaging();
    const tokens = [];

    // ── Recopilar tokens ────────────────────────────────────────────────────
    if (uid) {
      // Notificación para un usuario específico
      const userDoc = await db.collection("users").doc(uid).get();
      const token   = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);

    } else if (rol) {
      // Notificación para todos los usuarios de un rol
      const snap = await db.collection("users")
        .where("rol", "==", rol)
        .where("disponible", "==", true) // solo los activos
        .get();
      snap.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token) tokens.push(token);
      });
    }

    if (tokens.length === 0) {
      await ref.update({ enviada: true, error: "sin_tokens" });
      return;
    }

    // ── Payload FCM ──────────────────────────────────────────────────────────
    const notification = { title: titulo, body: cuerpo };
    const androidConfig = {
      notification: {
        channelId: "la_italiana_channel",
        color: "#FF6B00",
        sound: "default",
        priority: "high",
      },
      priority: "high",
    };
    const dataPayload = {
      tipo,
      ...(pedidoId && { pedidoId }),
      titulo,
      cuerpo,
    };

    // ── Enviar (multicast si hay varios tokens) ──────────────────────────────
    let enviados = 0;
    let errores  = 0;

    if (tokens.length === 1) {
      try {
        await fcm.send({
          token: tokens[0],
          notification,
          android: androidConfig,
          data: dataPayload,
        });
        enviados = 1;
      } catch (e) {
        errores = 1;
        console.error("Error enviando push:", e);
      }
    } else {
      // multicast
      const result = await fcm.sendEachForMulticast({
        tokens,
        notification,
        android: androidConfig,
        data: dataPayload,
      });
      enviados = result.successCount;
      errores  = result.failureCount;

      // Limpiar tokens inválidos
      result.responses.forEach(async (resp, i) => {
        if (!resp.success && resp.error?.code === "messaging/registration-token-not-registered") {
          // Token expirado — borrarlo de Firestore
          const snap2 = await db.collection("users")
            .where("fcmToken", "==", tokens[i]).get();
          snap2.forEach((doc) => doc.ref.update({ fcmToken: null }));
        }
      });
    }

    // ── Marcar como enviada ──────────────────────────────────────────────────
    await ref.update({
      enviada: true,
      enviadoEn: new Date().toISOString(),
      tokensEnviados: enviados,
      tokensError: errores,
    });

    console.log(`Push enviado: ${titulo} → ${enviados} dispositivos`);
  }
);