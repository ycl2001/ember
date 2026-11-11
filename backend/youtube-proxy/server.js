import { createServer } from 'node:http';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const endpoint = '/v1/youtube/recommendations';
const videoID = /^[A-Za-z0-9_-]{11}$/;
const minute = 60_000;

class RequestError extends Error {
  constructor(status, code, retryAfter) {
    super(code);
    this.status = status;
    this.retryAfter = retryAfter;
  }
}

function queryOptions(params) {
  const limits = { goal: 256, task: 256, q: 600, maxResults: 1 };
  for (const [name, value] of params) {
    if (!Object.hasOwn(limits, name) || params.getAll(name).length !== 1 ||
        value.length > limits[name] || /[\x00-\x08\x0e-\x1f\x7f\ufffd]/u.test(value)) {
      throw new RequestError(400, 'invalid_query');
    }
  }
  const clean = name => (params.get(name) ?? '').trim().replace(/\s+/gu, ' ');
  const goal = clean('goal');
  const task = clean('task');
  const subject = goal && task.toLowerCase().includes(goal.toLowerCase())
    ? task : [task, goal].filter(Boolean).join(' ');
  const query = clean('q') || (subject && `${subject} tutorial`);
  const count = params.get('maxResults') ?? '5';
  if (!query || !/^[1-5]$/.test(count)) {
    throw new RequestError(400, 'invalid_query');
  }
  return { query, count: Number(count) };
}

function windowLimiter(limit) {
  let start = 0;
  let used = 0;
  return now => {
    if (now >= start + minute) {
      start = now;
      used = 0;
    }
    if (used >= limit) {
      throw new RequestError(429, 'rate_limited', Math.ceil((start + minute - now) / 1000));
    }
    used++;
  };
}

function swiftItem(video) {
  const { id, snippet, contentDetails, status } = video ?? {};
  if (typeof id !== 'string' || !videoID.test(id) || status?.embeddable !== true ||
      typeof snippet?.title !== 'string' || typeof snippet.description !== 'string' ||
      typeof snippet.channelTitle !== 'string' || typeof contentDetails?.duration !== 'string') {
    return undefined;
  }
  const thumbnails = {};
  for (const size of ['default', 'medium', 'high']) {
    const url = snippet.thumbnails?.[size]?.url;
    if (typeof url === 'string' && URL.canParse(url) && new URL(url).protocol === 'https:') {
      thumbnails[size] = { url };
    }
  }
  return {
    id,
    snippet: { title: snippet.title, description: snippet.description, channelTitle: snippet.channelTitle, thumbnails },
    contentDetails: { duration: contentDetails.duration }
  };
}

export function createProxy({
  apiKey, fetchImpl = globalThis.fetch, now = Date.now,
  timeoutMs = 4_000, cacheTtlMs = 15 * minute, requestLimit = 120, searchLimit = 10
} = {}) {
  const cache = new Map();
  const pending = new Map();
  const allowRequest = windowLimiter(requestLimit);
  const allowSearch = windowLimiter(searchLimit);
  let upstreamCooldownUntil = 0;

  async function youtube(resource, params) {
    const url = new URL(`https://www.googleapis.com/youtube/v3/${resource}`);
    url.search = new URLSearchParams(params);
    const signal = AbortSignal.timeout(timeoutMs);
    try {
      const response = await fetchImpl(url, {
        headers: { 'x-goog-api-key': apiKey, accept: 'application/json' },
        redirect: 'error',
        signal
      });
      if (!response.ok) {
        const error = await response.json().catch(error => {
          if (signal.aborted && response.status !== 429) throw error;
          return null;
        });
        const reasons = error?.error?.errors;
        const quota = Array.isArray(reasons) && reasons.some(entry =>
          ['quotaExceeded', 'dailyLimitExceeded', 'rateLimitExceeded', 'userRateLimitExceeded']
            .includes(entry?.reason));
        if (response.status === 429 || quota) {
          upstreamCooldownUntil = now() + minute;
          throw new RequestError(429, 'youtube_quota_exceeded', 60);
        }
        throw new RequestError(502, 'youtube_unavailable');
      }
      const data = await response.json();
      if (!Array.isArray(data?.items)) throw new RequestError(502, 'youtube_invalid_response');
      return data.items;
    } catch (error) {
      if (error instanceof RequestError) throw error;
      if (signal.aborted) throw new RequestError(504, 'youtube_timeout');
      throw new RequestError(502, 'youtube_unavailable');
    }
  }

  async function load(query, count) {
    const search = await youtube('search', {
      part: 'snippet', type: 'video', videoEmbeddable: 'true', safeSearch: 'moderate',
      q: query, maxResults: String(count), fields: 'items(id/videoId)'
    });
    const ids = [...new Set(search.map(item => item?.id?.videoId)
      .filter(id => typeof id === 'string' && videoID.test(id)))].slice(0, count);
    if (!ids.length) return { items: [] };
    const videos = await youtube('videos', {
      part: 'snippet,contentDetails,status', id: ids.join(','),
      fields: 'items(id,snippet(title,description,channelTitle,thumbnails),contentDetails/duration,status/embeddable)'
    });
    const byID = new Map(videos.map(swiftItem).filter(Boolean).map(item => [item.id, item]));
    return { items: ids.map(id => byID.get(id)).filter(Boolean) };
  }

  async function recommendations({ query, count }) {
    const key = JSON.stringify([query, count]);
    const currentTime = now();
    const hit = cache.get(key);
    if (hit?.expires > currentTime) return hit.data;
    cache.delete(key);
    if (pending.has(key)) return pending.get(key);
    if (upstreamCooldownUntil > currentTime) {
      throw new RequestError(429, 'youtube_quota_exceeded',
        Math.ceil((upstreamCooldownUntil - currentTime) / 1000));
    }
    allowSearch(currentTime);
    const result = load(query, count).then(data => {
      if (cache.size >= 256) cache.delete(cache.keys().next().value);
      cache.set(key, { data, expires: now() + cacheTtlMs });
      return data;
    }).finally(() => pending.delete(key));
    pending.set(key, result);
    return result;
  }

  return createServer(async (request, response) => {
    function send(status, body, headers = {}) {
      response.writeHead(status, {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
        ...headers
      });
      response.end(JSON.stringify(body));
    }

    try {
      if (request.url.length > 8192) throw new RequestError(414, 'uri_too_long');
      const url = new URL(request.url, 'http://localhost');
      if (!['/healthz', endpoint].includes(url.pathname)) throw new RequestError(404, 'not_found');
      if (request.method !== 'GET') return send(405, { error: 'method_not_allowed' }, { allow: 'GET' });
      if (!apiKey) throw new RequestError(503, 'service_unconfigured');
      if (url.pathname === '/healthz') return send(200, { status: 'ok' });
      allowRequest(now());
      // Swift URLComponents leaves literal plus signs intact in query values.
      const params = new URLSearchParams(url.search.replaceAll('+', '%2B'));
      return send(200, await recommendations(queryOptions(params)));
    } catch (error) {
      if (!(error instanceof RequestError)) return send(500, { error: 'internal_error' });
      return send(error.status, { error: error.message },
        error.retryAfter ? { 'retry-after': String(error.retryAfter) } : {});
    }
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const apiKey = process.env.YOUTUBE_API_KEY?.trim();
  if (!apiKey) {
    console.error('YOUTUBE_API_KEY is required');
    process.exitCode = 1;
  } else {
    createProxy({ apiKey }).listen(Number(process.env.PORT ?? 8080), '0.0.0.0');
  }
}
