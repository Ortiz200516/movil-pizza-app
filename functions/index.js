const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();
const db  = admin.firestore();
const fcm = admin.messaging();

// ── Helper: enviar push a un usuario ─────────────────────────────────────────
async function pushUsuario(uid, titulo, cuerpo, data = {}) {
  const snap = await db.collection('users').doc(uid).get();
  const token = snap.data()?.fcmToken;
  if (!token) return;
  return fcm.send({
    token,
    notification: { title: titulo, body: cuerpo },
    android: {
      notification: {
        color: '#FF6B35',
        icon: 'ic_launcher',
        channelId: 'la_italiana_channel',
        priority: 'high',
      },
    },
    data: { pedidoId: data.pedidoId ?? '', tipo: data.tipo ?? 'pedido' },
  }).catch(() => null);
}

// ── Helper: enviar push a todos los usuarios con un rol ───────────────────────
async function pushRol(rol, titulo, cuerpo, data = {}) {
  const snap = await db.collection('users')
    .where('rol', '==', rol).get();
  const tokens = snap.docs
    .map(d => d.data().fcmToken).filter(Boolean);
  if (!tokens.length) return;
  const msgs = tokens.map(token => ({
    token,
    notification: { title: titulo, body: cuerpo },
    android: {
      notification: {
        color: '#FF6B35',
        icon: 'ic_launcher',
        channelId: 'la_italiana_channel',
        priority: 'high',
      },
    },
    data: { pedidoId: data.pedidoId ?? '', tipo: data.tipo ?? 'pedido' },
  }));
  return fcm.sendEach(msgs).catch(() => null);
}

// ══════════════════════════════════════════════════════════════════════════════
// TRIGGER: onWrite en pedidos — notifica según el cambio de estado
// ══════════════════════════════════════════════════════════════════════════════
exports.onPedidoCambia = functions
  .region('us-central1')
  .firestore.document('pedidos/{pedidoId}')
  .onWrite(async (change, ctx) => {
    const antes  = change.before.data();
    const ahora  = change.after.data();
    if (!ahora) return;                       // borrado — ignorar

    const pedidoId   = ctx.params.pedidoId;
    const estadoAntes = antes?.estado ?? '';
    const estadoAhora = ahora.estado  ?? '';
    const clienteId   = ahora.clienteId ?? ahora.userId ?? '';
    const nombre      = ahora.clienteNombre ?? 'Cliente';
    const items       = (ahora.items ?? []).length;
    const total       = (ahora.total ?? 0).toFixed(2);
    const mesa        = ahora.numeroMesa;
    const tipo        = ahora.tipoPedido ?? 'domicilio';
    const data        = { pedidoId };

    if (estadoAntes === estadoAhora) return;  // sin cambio de estado

    // ── Notificar AL CLIENTE según estado ─────────────────────────────────
    const msgCliente = {
      'Pendiente':  { t: '⏳ Pedido recibido',          b: `¡Hola ${nombre}! Tu pedido de ${items} item(s) fue recibido.` },
      'Preparando': { t: '👨‍🍳 Ya estamos cocinando',      b: 'Tu pedido está en preparación. ¡Pronto listo!' },
      'Listo':      { t: '✅ ¡Tu pedido está listo!',    b: tipo === 'mesa' ? `Mesa ${mesa} — el mesero ya viene.` : 'Listo para retirar o en camino.' },
      'En camino':  { t: '🛵 Tu pedido va en camino',    b: `Tu repartidor está en camino con tu pedido.` },
      'Entregado':  { t: '🎉 ¡Pedido entregado!',        b: `Tu pedido de $${total} fue entregado. ¡Buen provecho!` },
      'Cancelado':  { t: '❌ Pedido cancelado',           b: `Tu pedido fue cancelado. Contáctanos si necesitas ayuda.` },
    }[estadoAhora];

    if (msgCliente && clienteId) {
      await pushUsuario(clienteId, msgCliente.t, msgCliente.b, data);
    }

    // ── Notificar AL COCINERO cuando llega pedido nuevo ───────────────────
    if (estadoAhora === 'Pendiente') {
      const tipoLabel = tipo === 'mesa' ? `Mesa ${mesa}` : 'Domicilio';
      await pushRol('cocinero',
        `🍕 Nueva orden — ${tipoLabel}`,
        `${items} producto(s) · $${total}`,
        data);
    }

    // ── Notificar AL REPARTIDOR cuando pedido está Listo ─────────────────
    if (estadoAhora === 'Listo' && tipo === 'domicilio') {
      await pushRol('repartidor',
        '📦 Pedido listo para entregar',
        `${items} item(s) · $${total} — disponible para tomar`,
        data);
    }

    // ── Notificar AL ADMIN si hay cancelación ─────────────────────────────
    if (estadoAhora === 'Cancelado') {
      await pushRol('admin',
        '⚠️ Pedido cancelado',
        `${nombre} canceló su pedido de $${total}`,
        data);
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
// TRIGGER: onWrite en reservas — notifica cambios
// ══════════════════════════════════════════════════════════════════════════════
exports.onReservaCambia = functions
  .region('us-central1')
  .firestore.document('reservas/{reservaId}')
  .onWrite(async (change, ctx) => {
    const antes  = change.before.data();
    const ahora  = change.after.data();
    if (!ahora) return;

    const estadoAntes = antes?.estado ?? '';
    const estadoAhora = ahora.estado  ?? '';
    const clienteId   = ahora.clienteId ?? '';
    const mesa        = ahora.numeroMesa ?? '?';
    const fecha       = ahora.fecha ?? '';
    const hora        = ahora.hora  ?? '';

    if (estadoAntes === estadoAhora) return;

    const msgCliente = {
      'confirmada': { t: '✅ Reserva confirmada', b: `Mesa ${mesa} para el ${fecha} a las ${hora}. ¡Te esperamos!` },
      'rechazada':  { t: '❌ Reserva no disponible', b: `Lo sentimos, tu reserva del ${fecha} no pudo confirmarse.` },
    }[estadoAhora];

    if (msgCliente && clienteId) {
      await pushUsuario(clienteId, msgCliente.t, msgCliente.b, {});
    }

    // Notificar al admin cuando llega reserva nueva
    if (estadoAhora === 'pendiente') {
      await pushRol('admin',
        '📅 Nueva reserva',
        `Mesa ${mesa} — ${fecha} ${hora}`,
        {});
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
// TRIGGER: nuevo usuario registrado — bienvenida
// ══════════════════════════════════════════════════════════════════════════════
exports.onUsuarioNuevo = functions
  .region('us-central1')
  .auth.user().onCreate(async (user) => {
    // Esperar que guardarToken guarde el token (pequeño delay)
    await new Promise(r => setTimeout(r, 5000));
    const snap = await db.collection('users').doc(user.uid).get();
    const token = snap.data()?.fcmToken;
    if (!token) return;
    return fcm.send({
      token,
      notification: {
        title: '🍕 ¡Bienvenido a La Italiana!',
        body: 'Explora nuestro menú y haz tu primer pedido. ¡Tenemos algo especial para ti!'
      },
      android: {
        notification: {
          color: '#FF6B35', icon: 'ic_launcher',
          channelId: 'la_italiana_channel',
        },
      },
    }).catch(() => null);
  });