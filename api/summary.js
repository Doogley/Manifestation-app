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

  const prompt = `You are a warm, deeply perceptive journaling companion for an app called Already Mine — a daily manifestation and affirmation practice.

${name} has been working on manifesting ${intention_category || 'their goals'} this month. You have access to their actual journal entries below. Read them carefully and write a personal monthly reflection of 4-6 sentences that feels like it was written by someone who truly knows them.

Guidelines:
- Reference specific things they actually wrote — moods they named, things they were grateful for, reflections they shared
- Notice patterns across the month — did their mood shift? Did certain themes keep coming up?
- Speak to their growth, their consistency, or their honesty with themselves
- If they had hard days, acknowledge them with compassion — don't only highlight the positive
- Connect their journal entries back to what they are manifesting
- Write in second person ("you") — warm, intimate, like a letter from a wise friend
- Do not be generic. If you cannot find something specific to say from their entries, say so gently rather than filling space with empty affirmations

Journal entries from the past 30 days:
${entrySummary}

Their active intentions:
${intentionLines}

Write only the narrative — no introduction, no label, no quotes. 4-6 sentences.`;

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
        max_tokens: 1000,
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
