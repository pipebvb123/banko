// Vercel Serverless Function — chatbot con IA (Claude / Anthropic) para multy.cl
// Requiere la variable de entorno (Vercel > Settings > Environment Variables):
//   ANTHROPIC_API_KEY  → console.anthropic.com > API Keys
//
// Recibe el historial de la conversación desde el widget de chat del sitio
// y devuelve la respuesta del asistente.

const SYSTEM_PROMPT = `Eres el asistente virtual de Multy (multy.cl), una plataforma chilena que ayuda a empresas y pymes a encontrar financiamiento comparando automáticamente entre más de 20 instituciones financieras (bancos, factoring no bancario y fintechs).

Multy ofrece 4 tipos de financiamiento:
- Factoring: anticipa el cobro de tus facturas para mejorar el flujo de caja sin endeudarte.
- Leasing: financia vehículos, maquinaria o equipos con cuotas fijas y beneficios tributarios.
- Capital de trabajo: financiamiento para cubrir gastos operativos (insumos, sueldos, inventario).
- Créditos: préstamos directos para la empresa (Comercial, con Garantía, Fogape, Microempresa, Ventas Futuras, Adquisición).

Cómo funciona Multy: 1) el usuario ingresa los datos de su empresa (2 minutos), 2) Multy compara automáticamente entre más de 20 instituciones, 3) Multy contacta al usuario con las mejores opciones.

Documentos: normalmente se necesita información financiera básica y antecedentes legales de la empresa, que se pueden subir desde "Mi perfil" en la cuenta del usuario.

Seguridad: los datos del usuario solo se comparten con las instituciones que el usuario autoriza explícitamente, nunca se publican ni se venden a terceros.

Instrucciones:
- Responde siempre en español, de forma breve, clara y amable (máximo 3-4 oraciones).
- Si el usuario quiere cotizar o pide ayuda para encontrar financiamiento, invítalo a hacer clic en "Comparar ahora" o a completar el formulario en la parte superior del sitio.
- No inventes tasas, montos ni nombres de instituciones específicas — en el sitio las tasas dicen "Por confirmar" porque son datos ilustrativos hasta que cada institución las confirme.
- No des consejos legales o financieros personalizados más allá de explicar cómo funciona Multy.
- Si te preguntan algo fuera del tema de financiamiento empresarial o Multy, redirige amablemente la conversación de vuelta a cómo Multy puede ayudar.`;

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    res.status(500).json({ error: 'Falta la variable de entorno ANTHROPIC_API_KEY' });
    return;
  }

  let mensajes = [];
  try { mensajes = Array.isArray(req.body?.mensajes) ? req.body.mensajes : []; } catch (e) {}

  // Límites básicos para evitar abuso/costos descontrolados
  mensajes = mensajes.slice(-20).map(m => ({
    role: m.role === 'assistant' ? 'assistant' : 'user',
    content: String(m.content || '').slice(0, 1000),
  }));
  if (mensajes.length === 0) {
    res.status(400).json({ error: 'Falta el mensaje' });
    return;
  }

  try {
    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 300,
        system: SYSTEM_PROMPT,
        messages: mensajes,
      }),
    });

    const data = await anthropicRes.json();
    if (!anthropicRes.ok) {
      res.status(502).json({ error: data?.error?.message || 'Error al conectar con el asistente' });
      return;
    }

    const texto = (data.content || []).map(b => b.text || '').join('').trim();
    res.status(200).json({ respuesta: texto || 'No pude generar una respuesta, intenta de nuevo.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
