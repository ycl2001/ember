# Ember YouTube proxy

A dependency-free Node.js 24 service for Cloud Run. Run the local checks from this directory:

```sh
npm ci
node --check server.js
npm test
```

The tests start the HTTP server on loopback and mock all YouTube requests. They need no credentials.

## HTTP API

- `GET /health` checks that the process is serving with a configured key. It makes no upstream request.
- `GET /v1/youtube/recommendations` accepts `goal` and `task` (up to 256 UTF-16 code units each), `q` (up to 600), and `maxResults` (integer 1–5, default 5). A nonblank `q` takes precedence. Otherwise the server derives a tutorial query from the task and goal. Supply at least one nonblank search input. Encode spaces as `%20`; a literal `+` is preserved for compatibility with Swift URLComponents.
- Success returns `{"items":[...]}` with the fields required by `YouTubeVideoListResponse.swift`. The proxy keeps YouTube search order and skips unavailable or non-embeddable videos. An empty result returns `{"items":[]}`.
- Errors return `{"error":"code"}`. Invalid input returns 400, rate or quota limits return 429 with `Retry-After`, upstream failures return 502, and upstream timeouts return 504. Ember currently handles all 429 responses as quota exhaustion.

The server caches up to 256 successful responses for 15 minutes and shares concurrent lookups for the same query and result count. Each instance allows 120 recommendation requests and 10 uncached upstream searches per one-minute window. Each YouTube API call has a four-second timeout. A quota failure pauses new upstream lookups for 60 seconds on that instance. These limits reset when the instance restarts. They do not enforce a project-wide daily budget. Check the project's YouTube Data API quota in Cloud Console before live testing.

## Deploy an IAM-protected Cloud Run service

1. Select a billing-enabled Google Cloud project. Enable Cloud Run, Cloud Build, Artifact Registry, Secret Manager and YouTube Data API v3. Set up the build and deploy identities using the [Cloud Run source deployment guide](https://docs.cloud.google.com/run/docs/deploying-source-code).
2. Create a dedicated API key restricted to YouTube Data API v3. In Secret Manager, create the secret `ember-youtube-api-key` and add the key as a secret version. Create a dedicated runtime service account and grant it `roles/secretmanager.secretAccessor` on that secret only. The deployer needs permission to act as the runtime account. See [Cloud Run secret configuration](https://docs.cloud.google.com/run/docs/configuring/services/secrets).
3. From `backend/youtube-proxy`, set `PROJECT_ID`, `REGION`, and `SECRET_VERSION` to your project, deployment region, and numeric secret version. The example expects a runtime service account named `ember-youtube-proxy`.

```sh
gcloud run deploy ember-youtube-proxy \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --source=. \
  --service-account="ember-youtube-proxy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --set-secrets="YOUTUBE_API_KEY=ember-youtube-api-key:${SECRET_VERSION}" \
  --no-allow-unauthenticated \
  --invoker-iam-check \
  --max-instances=1 \
  --timeout=15s
```

Cloud Run injects the secret as `YOUTUBE_API_KEY` and sets `PORT`. Keep invocation limited to approved identities. This configuration supports authenticated access over the Cloud Run HTTPS URL. For network-private ingress as well, use `--ingress=internal` and run the smoke test from an allowed network. When rotating the key, deploy a revision pinned to the new version before disabling the old one.

## Smoke-test the live backend

Grant the testing account `roles/run.invoker` on the service. Start the [authenticated Cloud Run proxy](https://docs.cloud.google.com/run/docs/authenticating/developers) locally, then make the requests in another terminal.

```sh
gcloud run services proxy ember-youtube-proxy --project="$PROJECT_ID" --region="$REGION" --port=8080
```

```sh
curl --fail-with-body http://localhost:8080/health
curl --fail-with-body --get http://localhost:8080/v1/youtube/recommendations \
  --data-urlencode 'goal=Swift' \
  --data-urlencode 'task=Optionals' \
  --data-urlencode 'q=Swift Optionals tutorial' \
  --data-urlencode 'maxResults=5'
```

The recommendation request uses live YouTube quota. Verify that it returns HTTP 200 with an `items` array. Verify that an unauthenticated request to the Cloud Run HTTPS URL is denied.

## Configure Ember

`YouTubeServiceFactory.swift` reads `YouTubeProxyBaseURL` from the built Ember app's Info.plist. Set it to the HTTPS origin of the endpoint Ember can access, for example `https://ember-api.example.com`. The app appends `/v1/youtube/recommendations`. Keep the API key out of Xcode and the app bundle.

For a local or CI build, supply an Ember app-target Info.plist input through the `INFOPLIST_FILE` build setting and include this entry in its top-level dictionary. Keep the generated Info.plist settings in place so Xcode can merge the target's generated values. Confirm the entry is present in the built `Ember.app/Info.plist`.

```xml
<key>YouTubeProxyBaseURL</key>
<string>https://ember-api.example.com</string>
```

The current app sends no authentication credential, so pointing it directly at IAM-protected Cloud Run results in a denied request. The local `gcloud` proxy serves HTTP, which the app factory rejects. For a private simulator test with the existing app, put a trusted, local-only HTTPS reverse proxy in front of the local `gcloud` proxy and use its HTTPS origin in the plist. For a device rollout, integrate app authentication with a trusted HTTPS gateway that validates the caller and invokes Cloud Run using its own authorized identity. Keep the Cloud Run service IAM-protected. Treat goal and task text as user data when configuring gateway and request logs.
