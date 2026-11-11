const test = require("node:test");
const assert = require("node:assert/strict");

const {createRecommendationHandler} = require("../gateway");

const backendUrl = "https://ember-youtube-proxy.example.run.app";
const video = {
  id: "abcdefghijk",
  snippet: {
    title: "Swift Optionals",
    description: "A focused tutorial.",
    channelTitle: "Ember Learning",
    thumbnails: {
      default: {url: "https://i.ytimg.com/vi/abcdefghijk/default.jpg"},
      medium: {url: "https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg"},
    },
  },
  contentDetails: {duration: "PT8M12S"},
};

/**
 * @param {!Object=} options Mock response and error options.
 * @return {function(!Object): !Promise<!Object>} A fully local gateway handler.
 */
function mockHandler({data = {items: [video]}, requestError, authError} = {}) {
  const request = async () => {
    if (requestError) {
      throw requestError;
    }
    return {data};
  };
  const auth = {
    getIdTokenClient: async (audience) => {
      assert.equal(audience, backendUrl);
      if (authError) {
        throw authError;
      }
      return {request};
    },
  };
  return createRecommendationHandler({auth, backendUrl: () => backendUrl});
}

/**
 * @param {!Promise<*>} promise Handler result to inspect.
 * @param {string} code Expected Firebase callable error code.
 * @return {!Promise<void>} Assertion completion.
 */
async function assertCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test("returns recommendations with sanitized query parameters", async () => {
  let requestedURL;
  const auth = {
    getIdTokenClient: async () => ({
      request: async (options) => {
        requestedURL = new URL(options.url);
        return {data: {items: [video]}};
      },
    }),
  };
  const handler = createRecommendationHandler({
    auth,
    backendUrl: () => backendUrl,
  });

  const result = await handler({
    data: {goal: "  Swift\n", task: "Optionals + errors", maxResults: 3},
  });

  assert.deepEqual(result, {items: [video]});
  assert.equal(requestedURL.pathname, "/v1/youtube/recommendations");
  assert.equal(requestedURL.searchParams.get("goal"), "Swift");
  assert.equal(requestedURL.searchParams.get("task"), "Optionals + errors");
  assert.equal(requestedURL.searchParams.get("maxResults"), "3");
});

test("returns an empty recommendation list", async () => {
  const result = await mockHandler({data: {items: []}})({data: {q: "Swift"}});
  assert.deepEqual(result, {items: []});
});

test("rejects malformed, unsupported, invalid, and empty input", async () => {
  const handler = mockHandler();
  const invalidRequests = [
    null,
    [],
    {q: "Swift", extra: true},
    {goal: 42},
    {q: "x".repeat(601)},
    {q: "bad\u0000value"},
    {goal: " \n\t "},
  ];
  for (const data of invalidRequests) {
    await assertCode(handler({data}), "invalid-argument");
  }
  const upstreamRejection = mockHandler({
    requestError: {response: {status: 400}},
  });
  await assertCode(
      upstreamRejection({data: {q: "Swift"}}),
      "invalid-argument",
  );
});

test("validates maximum result bounds and integer type", async () => {
  const handler = mockHandler();
  for (const maxResults of [0, 6, 2.5, "5"]) {
    await assertCode(
        handler({data: {q: "Swift", maxResults}}),
        "invalid-argument",
    );
  }
  await handler({data: {q: "Swift", maxResults: 5}});
});

test("maps authentication failure without exposing its details", async () => {
  const secret = "credential detail";
  const handler = mockHandler({authError: new Error(secret)});
  await assert.rejects(handler({data: {q: "Swift"}}), (error) => {
    assert.equal(error.code, "internal");
    assert.doesNotMatch(error.message, new RegExp(secret));
    return true;
  });
  const deniedHandler = mockHandler({requestError: {response: {status: 403}}});
  await assertCode(deniedHandler({data: {q: "Swift"}}), "internal");
});

test("maps HTTP 429 to resource exhausted", async () => {
  const handler = mockHandler({requestError: {response: {status: 429}}});
  await assertCode(handler({data: {q: "Swift"}}), "resource-exhausted");
});

test("maps Cloud Run timeouts to deadline exceeded", async () => {
  const failures = [
    {code: "ETIMEDOUT"},
    {response: {status: 504}},
  ];
  for (const requestError of failures) {
    const handler = mockHandler({requestError});
    await assertCode(handler({data: {q: "Swift"}}), "deadline-exceeded");
  }
});

test("maps unavailable backend responses", async () => {
  for (const status of [502, 503]) {
    const handler = mockHandler({requestError: {response: {status}}});
    await assertCode(handler({data: {q: "Swift"}}), "unavailable");
  }
});

test("rejects invalid upstream JSON payloads", async () => {
  for (const data of ["not json", {}, {items: "invalid"}, {items: [{}]}]) {
    const handler = mockHandler({data});
    await assertCode(handler({data: {q: "Swift"}}), "internal");
  }
  const syntaxErrorHandler = mockHandler({
    requestError: new SyntaxError("JSON"),
  });
  await assertCode(syntaxErrorHandler({data: {q: "Swift"}}), "internal");
});

test("preserves the complete existing video response contract", async () => {
  const upstream = {items: [video]};
  const result = await mockHandler({data: upstream})({
    data: {goal: "Swift", task: "Optionals"},
  });
  assert.deepEqual(result, upstream);
  assert.equal(result.items[0].id, video.id);
  assert.deepEqual(result.items[0].snippet, video.snippet);
  assert.deepEqual(result.items[0].contentDetails, video.contentDetails);
});
