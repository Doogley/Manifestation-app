const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

module.exports = async function handler(req, res) {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS_HEADERS);
    res.end();
    return;
  }

  if (req.method !== 'POST') {
    res.writeHead(405, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Method not allowed' }));
    return;
  }

  const { entries = [], intentions = [], userName = '', intention_category = '' } = req.body || {};

  const entrySummary = entries.length > 0
    ? entries.map(e => {
        const parts = [`Date: ${e.entry_date}`];
        if (e.mood_sub) parts.push(`Mood: ${e.mood_sub}`);
        if (e.reflection) parts.push(`Reflection: ${e.reflection}`);
        const gratitude = [e.gratitude_1, e.gratitude_2, e.gratitude_3].filter(Boolean);
        if (gratitude.length) parts.push(`Gratitude: ${gratitude.join(', ')}`);
        return parts.join('\n');
      }).join('\n\n')
    : 'No journal entries recorded this month yet.';

  const intentionLines = intentions.length > 0
    ? intentions.map(t => `- ${t}`).join('\n')
    : 'No intentions set this month.';

  const name = userName ? userName.split(' ')[0] : 'you';

  const prompt = `You are a warm, insightful journaling companion for an app called Already Mine.

${name} has been working on manifesting ${intention_category || 'their goals'} this month. Based on their journal entries below, write a personal monthly reflection narrative of 3-4 sentences. Speak directly to them using "you" language. Notice emotional patterns, moments of growth, recurring themes of gratitude, and any shifts in mood or mindset. Be specific to their entries — not generic. Keep it warm, affirming, and grounded.

Journal entries from the past 30 days:
${entrySummary}

Their active intentions:
${intentionLines}

Write only the narrative — no introduction, no label, no quotes.`;

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 500,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    if (!response.ok) {
      throw new Error(`Anthropic API error: ${response.status}`);
    }

    const data = await response.json();
    const narrative = data.content?.[0]?.text ?? '';

    res.writeHead(200, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ narrative }));
  } catch (err) {
    res.writeHead(200, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      narrative: 'This month you showed up — and that is the whole practice. Your reflection will be available once we\'re able to reach our summary service. Keep going.',
    }));
  }
}
