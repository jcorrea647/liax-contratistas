// api/chat.js — proxy a Gemini para LIAX Contratistas.
// Recibe { model, system, messages, max_tokens, generationConfig } y devuelve
// { content: [{ type:'text', text }] } — el mismo formato que el front espera
// (callGemini en el app.html). La API key vive SOLO en el servidor (env var),
// nunca en el cliente.

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: { message: 'Método no permitido' } });
  }

  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: { message: 'Falta GEMINI_API_KEY en el servidor' } });
  }

  try {
    const { model, system, messages, generationConfig } = req.body || {};
    const geminiModel = model || 'gemini-2.5-flash';

    // Convertir formato {role,content} → formato Gemini {role,parts}
    const contents = (messages || []).map(m => ({
      role:  m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: typeof m.content === 'string' ? m.content : JSON.stringify(m.content) }]
    }));

    const body = {
      contents,
      generationConfig: generationConfig || { maxOutputTokens: 4000, temperature: 0.2 },
    };
    if (system) body.systemInstruction = { parts: [{ text: system }] };

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${GEMINI_API_KEY}`;
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!r.ok) {
      const err = await r.json().catch(() => ({}));
      return res.status(r.status).json({ error: err.error || { message: 'Error Gemini' } });
    }

    const data = await r.json();
    const text = (data?.candidates?.[0]?.content?.parts || [])
      .map(p => p.text || '').join('');

    // Formato que espera el front
    return res.status(200).json({ content: [{ type: 'text', text }], _provider: 'gemini' });
  } catch (e) {
    return res.status(500).json({ error: { message: e.message || 'Error interno' } });
  }
}
