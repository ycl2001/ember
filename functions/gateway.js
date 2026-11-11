const {HttpsError} = require("firebase-functions/v2/https");

const endpoint = "/v1/youtube/recommendations";
const inputLimits = {goal: 256, task: 256, q: 600};
const allowedParameters = new Set([...Object.keys(inputLimits), "maxResults"]);
// This intentionally mirrors the Cloud Run proxy's input contract.
// eslint-disable-next-line no-control-regex
const invalidCharacters = /[\x00-\x08\x0e-\x1f\x7f\ufffd]/u;
const videoID = /^[A-Za-z0-9_-]{11}$/;

/** @return {!HttpsError} A generic invalid-input error. */
function invalidArgument() {
  return new HttpsError("invalid-argument", "Invalid recommendation request.");
}

/**
 * @param {*} value A value to inspect.
 * @return {boolean} Whether the value is a non-array object.
 */
function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * @param {string} value A validated learner input.
 * @return {string} The input with backend-compatible whitespace cleanup.
 */
function cleanInput(value) {
  return value.trim().replace(/\s+/gu, " ");
}

/**
 * @param {*} data Callable request data.
 * @return {!Object} Validated parameters for the Cloud Run request.
 */
function validateData(data) {
  if (!isRecord(data)) {
    throw invalidArgument();
  }

  const names = Object.keys(data);
  if (names.some((name) => !allowedParameters.has(name))) {
    throw invalidArgument();
  }

  const result = {};
  for (const [name, limit] of Object.entries(inputLimits)) {
    const value = data[name];
    if (value === undefined) {
      continue;
    }
    if (typeof value !== "string" || value.length > limit ||
        invalidCharacters.test(value)) {
      throw invalidArgument();
    }
    result[name] = cleanInput(value);
  }

  if (!Object.values(result).some(Boolean)) {
    throw invalidArgument();
  }

  const maxResults = data.maxResults === undefined ? 5 : data.maxResults;
  if (!Number.isInteger(maxResults) || maxResults < 1 || maxResults > 5) {
    throw invalidArgument();
  }
  result.maxResults = maxResults;
  return result;
}

/**
 * @param {string} value Configured Cloud Run service URL.
 * @return {!URL} A validated service origin.
 */
function validatedBaseURL(value) {
  let url;
  try {
    url = new URL(value);
  } catch (error) {
    throw new HttpsError("internal", "Recommendation service is unavailable.");
  }
  if (url.protocol !== "https:" || url.username || url.password ||
      url.search || url.hash || (url.pathname !== "/" && url.pathname !== "")) {
    throw new HttpsError("internal", "Recommendation service is unavailable.");
  }
  return url;
}

/**
 * @param {!URL} baseURL Validated Cloud Run origin.
 * @param {!Object} parameters Validated query parameters.
 * @return {!URL} The complete recommendation endpoint URL.
 */
function recommendationURL(baseURL, parameters) {
  const url = new URL(endpoint, baseURL);
  for (const name of Object.keys(inputLimits)) {
    if (parameters[name] !== undefined) {
      url.searchParams.set(name, parameters[name]);
    }
  }
  url.searchParams.set("maxResults", String(parameters.maxResults));
  return url;
}

/**
 * @param {*} value A thumbnail candidate.
 * @return {boolean} Whether it matches the proxy response contract.
 */
function isValidThumbnail(value) {
  if (!isRecord(value) || typeof value.url !== "string") {
    return false;
  }
  try {
    return new URL(value.url).protocol === "https:";
  } catch (error) {
    return false;
  }
}

/**
 * @param {*} item A video item candidate.
 * @return {boolean} Whether Ember can decode the item.
 */
function isValidItem(item) {
  if (!isRecord(item) || typeof item.id !== "string" ||
      !videoID.test(item.id) || !isRecord(item.snippet) ||
      !isRecord(item.contentDetails)) {
    return false;
  }
  const snippet = item.snippet;
  if (typeof snippet.title !== "string" ||
      typeof snippet.description !== "string" ||
      typeof snippet.channelTitle !== "string" ||
      !isRecord(snippet.thumbnails) ||
      typeof item.contentDetails.duration !== "string") {
    return false;
  }
  return Object.values(snippet.thumbnails).every(isValidThumbnail);
}

/**
 * @param {*} data Parsed upstream response data.
 * @return {!Object} The unmodified, validated response.
 */
function validateResponse(data) {
  if (!isRecord(data) || !Array.isArray(data.items) ||
      data.items.length > 5 || !data.items.every(isValidItem)) {
    throw new HttpsError(
        "internal",
        "Recommendation service returned invalid data.",
    );
  }
  return data;
}

/**
 * @param {*} error An upstream request failure.
 * @return {boolean} Whether the failure indicates a timeout.
 */
function isTimeout(error) {
  return ["ETIMEDOUT", "ECONNABORTED"].includes(error && error.code) ||
    (error && error.name) === "AbortError";
}

/**
 * @param {*} error An upstream request failure.
 * @return {!HttpsError} The safe callable error exposed to the client.
 */
function mapUpstreamError(error) {
  if (error instanceof SyntaxError) {
    return new HttpsError(
        "internal",
        "Recommendation service returned invalid data.",
    );
  }
  const status = error && error.response && error.response.status;
  if (status === 400) {
    return invalidArgument();
  }
  if (status === 429) {
    return new HttpsError(
        "resource-exhausted",
        "Recommendation quota exhausted.",
    );
  }
  if (status === 502 || status === 503) {
    return new HttpsError(
        "unavailable",
        "Recommendation service is unavailable.",
    );
  }
  if (status === 504 || isTimeout(error)) {
    return new HttpsError(
        "deadline-exceeded",
        "Recommendation request timed out.",
    );
  }
  if (status === 401 || status === 403) {
    return new HttpsError(
        "internal",
        "Recommendation service authorization failed.",
    );
  }
  if (status !== undefined) {
    return new HttpsError("internal", "Recommendation service failed.");
  }
  return new HttpsError(
      "unavailable",
      "Recommendation service is unavailable.",
  );
}

/**
 * @param {!Object} dependencies Injectable production dependencies.
 * @return {function(!Object): !Promise<!Object>} Callable request handler.
 */
function createRecommendationHandler({auth, backendUrl, timeoutMs = 10000}) {
  return async (request) => {
    const parameters = validateData(request && request.data);
    const baseURL = validatedBaseURL(backendUrl());

    let client;
    try {
      client = await auth.getIdTokenClient(baseURL.origin);
    } catch (error) {
      throw new HttpsError(
          "internal",
          "Recommendation service authentication failed.",
      );
    }

    try {
      const response = await client.request({
        url: recommendationURL(baseURL, parameters).toString(),
        method: "GET",
        headers: {accept: "application/json"},
        responseType: "json",
        timeout: timeoutMs,
      });
      return validateResponse(response.data);
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw mapUpstreamError(error);
    }
  };
}

module.exports = {
  createRecommendationHandler,
  validateData,
};
