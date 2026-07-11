// Vercel Serverless Function — despacha los correos encolados en email_notificaciones.
// Requiere las variables de entorno (Vercel > Settings > Environment Variables):
//   SUPABASE_SERVICE_ROLE_KEY  → Supabase > Project Settings > API > service_role key
//   RESEND_API_KEY             → Resend > API Keys
//
// Se llama automáticamente desde el sitio justo después de crear una solicitud
// (ver procesarSolicitudEnviada() en index.html), pasando el id de la fila recién
// insertada. También se puede llamar sin body para reintentar todo lo pendiente.

const SUPABASE_URL = 'https://hpsytgjlnhimsyaqrjvi.supabase.co';
const FROM_EMAIL = 'Multy <notificaciones@multy.cl>'; // debe ser un remitente del dominio verificado en Resend

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const resendKey  = process.env.RESEND_API_KEY;
  if (!serviceKey || !resendKey) {
    res.status(500).json({ error: 'Faltan variables de entorno SUPABASE_SERVICE_ROLE_KEY o RESEND_API_KEY' });
    return;
  }

  let notificacionId = null;
  try { notificacionId = (req.body && req.body.notificacionId) || null; } catch (e) {}

  const sbHeaders = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json',
  };

  try {
    // 1. Traer las notificaciones pendientes con correo de destino (una puntual o todas)
    const filtro = notificacionId
      ? `id=eq.${encodeURIComponent(notificacionId)}`
      : `estado=eq.pendiente_envio&destinatario=not.is.null`;
    const listRes = await fetch(`${SUPABASE_URL}/rest/v1/email_notificaciones?${filtro}&select=*`, {
      headers: sbHeaders,
    });
    const notificaciones = await listRes.json();
    if (!Array.isArray(notificaciones) || notificaciones.length === 0) {
      res.status(200).json({ enviados: 0, mensaje: 'Nada pendiente de enviar' });
      return;
    }

    const resultados = [];
    for (const n of notificaciones) {
      if (n.estado !== 'pendiente_envio' || !n.destinatario) {
        resultados.push({ id: n.id, saltado: true, motivo: 'sin destinatario o ya procesado' });
        continue;
      }

      const sendRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: FROM_EMAIL,
          to: [n.destinatario],
          subject: n.asunto,
          html: n.cuerpo_html,
        }),
      });

      const nuevoEstado = sendRes.ok ? 'enviado' : 'error';
      await fetch(`${SUPABASE_URL}/rest/v1/email_notificaciones?id=eq.${n.id}`, {
        method: 'PATCH',
        headers: sbHeaders,
        body: JSON.stringify({ estado: nuevoEstado }),
      });
      resultados.push({ id: n.id, institucion: n.institucion, estado: nuevoEstado });
    }

    res.status(200).json({ enviados: resultados.filter(r => r.estado === 'enviado').length, resultados });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
