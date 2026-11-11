import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { setTimeout } from 'node:timers/promises';
import { createProxy } from './server.js';

const endpoint = '/v1/youtube/recommendations';
const ids = ['abcdefghijk', 'ABCDEFGHIJK', '0123456789_'];
const searchItems = ids.map(videoId => ({ id: { videoId } }));
const video = (id, embeddable = true) => ({
  id, status: { embeddable },
  snippet: {
    title: id, description: '0:00 Start', channelTitle: 'Learning channel',
    thumbnails: { high: { url: 'https://i.ytimg.com/example.jpg', width: 480 } }
  },
  contentDetails: { duration: 'PT4M2S' }
});

async function start(t, mock, options = {}) {
  const calls = [];
  const server = createProxy({
    apiKey: 'mock-key',
    ...options,
    fetchImpl: (url, init) => {
      assert.equal(url.origin, 'https://www.googleapis.com');
      assert.equal(init.headers['x-goog-api-key'], 'mock-key');
      assert.equal(url.searchParams.has('key'), false);
      calls.push(url);
      return mock(url, init);
    }
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  const request = (path, init) => fetch(`http://127.0.0.1:${server.address().port}${path}`, init);
  return { calls, request };
}

test('serves the Swift decoding contract and preserves search rank', async t => {
  const { calls, request } = await start(t, url => Response.json({
    items: url.pathname.endsWith('/search') ? searchItems : [
      video(ids[2]), video(ids[1], false), video(ids[0])
    ]
  }));
  const response = await request(endpoint + '?goal=C++&task=pointers&q=C++%20pointers&maxResults=3');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    items: [ids[0], ids[2]].map(id => ({
      id,
      snippet: {
        title: id, description: '0:00 Start', channelTitle: 'Learning channel',
        thumbnails: { high: { url: 'https://i.ytimg.com/example.jpg' } }
      },
      contentDetails: { duration: 'PT4M2S' }
    }))
  });
  assert.equal(calls.length, 2);
  assert.equal(calls[0].searchParams.get('q'), 'C++ pointers');
  assert.equal(calls[0].searchParams.get('maxResults'), '3');
  assert.equal(calls[0].searchParams.get('videoEmbeddable'), 'true');
  assert.equal(calls[1].searchParams.get('id'), ids.join(','));
});

test('validates all inputs and supports a goal/task fallback', async t => {
  const { calls, request } = await start(t, () => Response.json({ items: [] }));
  for (const query of ['', 'q=', 'q=x&q=y', 'q=x&maxResults=0', 'q=x&maxResults=6',
    'q=x&maxResults=1.0', 'q=x&other=1', 'q=%00', 'q=%FF', 'goal=' + 'x'.repeat(257),
    'q=x&task=' + 'x'.repeat(257), 'q=' + 'x'.repeat(601)]) {
    assert.equal((await request(endpoint + '?' + query)).status, 400, query);
  }
  assert.equal(calls.length, 0);
  assert.equal((await request(endpoint + '?goal=Swift&task=Optionals')).status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].searchParams.get('q'), 'Optionals Swift tutorial');
  assert.equal(calls[0].searchParams.get('maxResults'), '5');
});

test('shares in-flight requests and expires cached results', async t => {
  let clock = 100_000;
  const { calls, request } = await start(t, async () => {
    await setTimeout(30);
    return Response.json({ items: [] });
  }, { now: () => clock, cacheTtlMs: 1_000 });
  await Promise.all([request(endpoint + '?q=Swift'), request(endpoint + '?q=%20Swift%20')]);
  await request(endpoint + '?q=Swift');
  assert.equal(calls.length, 1);
  clock += 1_000;
  await request(endpoint + '?q=Swift');
  assert.equal(calls.length, 2);
});

test('returns 429 for both API quota failures and upstream throttling', async t => {
  for (const status of [403, 429]) {
    const { calls, request } = await start(t, url => url.pathname.endsWith('/search')
      ? Response.json({ items: searchItems })
      : Response.json({ error: { errors: [{ reason: status === 403 ? 'quotaExceeded' : 'unknown' }] } }, { status }));
    for (const query of ['Swift', 'SwiftUI']) {
      const response = await request(endpoint + '?q=' + query);
      assert.equal(response.status, 429);
      assert.ok(Number(response.headers.get('retry-after')) > 0);
      assert.deepEqual(await response.json(), { error: 'youtube_quota_exceeded' });
    }
    assert.equal(calls.length, 2);
  }
});

test('limits total requests and upstream searches independently', async t => {
  let clock = 100_000;
  const { calls, request } = await start(t, () => Response.json({ items: [] }),
    { now: () => clock, requestLimit: 3, searchLimit: 1 });
  assert.equal((await request(endpoint + '?q=a')).status, 200);
  assert.equal((await request(endpoint + '?q=b')).status, 429);
  assert.equal((await request(endpoint + '?q=a')).status, 200);
  const limited = await request(endpoint + '?q=a');
  assert.equal(limited.status, 429);
  assert.deepEqual(await limited.json(), { error: 'rate_limited' });
  assert.equal(calls.length, 1);
  clock += 60_000;
  assert.equal((await request(endpoint + '?q=b')).status, 200);
  assert.equal(calls.length, 2);
});

test('aborts slow upstream calls and times out with HTTP 504', async t => {
  const { request } = await start(t, async (_url, { signal }) => {
    await setTimeout(500, null, { signal });
    return Response.json({ items: [] });
  }, { timeoutMs: 20 });
  assert.equal((await request(endpoint + '?q=slow')).status, 504);
});

test('sanitizes upstream errors and retries on later requests', async t => {
  let attempts = 0;
  const { request } = await start(t, () => {
    attempts++;
    if (attempts === 1) return Response.json({ error: 'sensitive detail' }, { status: 403 });
    if (attempts === 2) return Response.json({ unexpected: true });
    return Response.json({ items: [] });
  });
  const denied = await request(endpoint + '?q=a');
  assert.equal(denied.status, 502);
  assert.deepEqual(await denied.json(), { error: 'youtube_unavailable' });
  assert.equal((await request(endpoint + '?q=a')).status, 502);
  assert.equal((await request(endpoint + '?q=a')).status, 200);
});

test('health does not call YouTube and routes reject unsupported methods', async t => {
  const { calls, request } = await start(t, () => assert.fail('Unexpected upstream call'));
  assert.deepEqual(await (await request('/healthz')).json(), { status: 'ok' });
  assert.equal((await request('/unknown')).status, 404);
  assert.equal((await request(endpoint, { method: 'POST' })).status, 405);
  assert.equal(calls.length, 0);
  const unconfigured = await start(t, () => assert.fail('Unexpected upstream call'), { apiKey: '' });
  assert.equal((await unconfigured.request('/healthz')).status, 503);
});
