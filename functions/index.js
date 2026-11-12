const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall} = require("firebase-functions/v2/https");
const {defineString} = require("firebase-functions/params");
const {GoogleAuth} = require("google-auth-library");

const {createRecommendationHandler} = require("./gateway");

const youtubeProxyURL = defineString("YOUTUBE_PROXY_URL");
const gatewayServiceAccount = defineString(
    "YOUTUBE_GATEWAY_SERVICE_ACCOUNT",
);

setGlobalOptions({maxInstances: 10});

const recommendationHandler = createRecommendationHandler({
  auth: new GoogleAuth(),
  backendUrl: () => youtubeProxyURL.value(),
});

exports.getYouTubeRecommendations = onCall(
    {
      region: "australia-southeast1",
      enforceAppCheck: true,
      serviceAccount: gatewayServiceAccount,
      timeoutSeconds: 30,
    },
    recommendationHandler,
);
