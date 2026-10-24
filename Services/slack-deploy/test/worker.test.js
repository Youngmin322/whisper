import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { handleRequest } from "../src/worker.js";

const env = {
  SLACK_SIGNING_SECRET: "test-secret", GITHUB_TOKEN: "test-token",
  SLACK_TEAM_ID: "T123", SLACK_ALLOWED_USER_IDS: "U123,U456", SLACK_ALLOWED_CHANNEL_IDS: "C123",
  GITHUB_REPOSITORY: "Youngmin322/whisper", GITHUB_WORKFLOW: "slack-deploy.yml", GITHUB_WORKFLOW_REF: "dev",
  DEFAULT_BRANCH: "dev", ALLOWED_BRANCHES: "dev,main",
};

function request(fields = {}, { age = 0, signature, headers = {} } = {}) {
  const timestamp = String(Math.floor(Date.now() / 1000) - age);
  const body = new URLSearchParams({
    team_id: "T123", user_id: "U123", channel_id: "C123", command: "/testflight", text: "",
    response_url: "https://hooks.slack.com/commands/test/callback", ...fields,
  }).toString();
  const digest = createHmac("sha256", env.SLACK_SIGNING_SECRET).update(`v0:${timestamp}:${body}`).digest("hex");
  return new Request("https://worker.example/slack/commands", {
    method: "POST", body, headers: {
      "content-type": "application/x-www-form-urlencoded", "x-slack-request-timestamp": timestamp,
      "x-slack-signature": signature ?? `v0=${digest}`, ...headers,
    },
  });
}

function harness({ githubStatus = 204, throwGitHub = false, configuration = env } = {}) {
  const calls = [], pending = [];
  const fetcher = async (url, options) => {
    calls.push({ url, ...options });
    if (url.startsWith("https://api.github.com")) {
      if (throwGitHub) throw new Error("private network detail");
      return new Response(null, { status: githubStatus });
    }
    return new Response("ok");
  };
  return {
    calls,
    run: (req) => handleRequest(req, configuration, { waitUntil: (promise) => pending.push(promise) }, fetcher),
    finish: () => Promise.all(pending),
  };
}

test("valid command dispatches the selected branch and reports acceptance", async () => {
  const h = harness();
  assert.equal((await h.run(request({ text: "main" }))).status, 200);
  await h.finish();
  assert.equal(h.calls.length, 2);
  assert.deepEqual(JSON.parse(h.calls[0].body), {
    ref: "dev", inputs: { operation: "testflight", branch: "main", version: "", build_number: "", requester: "U123" },
  });
  assert.equal(h.calls[0].redirect, "manual");
  assert.equal(h.calls[1].redirect, "manual");
  assert.equal(h.calls[1].headers.Authorization, undefined);
  assert.match(JSON.parse(h.calls[1].body).text, /main TestFlight/);
});

test("empty testflight arguments select dev", async () => {
  const h = harness(); await h.run(request()); await h.finish();
  assert.equal(JSON.parse(h.calls[0].body).inputs.branch, "dev");
});

test("review selects an exact existing version and build", async () => {
  const h = harness(); await h.run(request({ command: "/review", text: "2.0.1 42" })); await h.finish();
  assert.equal(JSON.parse(h.calls[0].body).inputs.version, "2.0.1");
  assert.equal(JSON.parse(h.calls[0].body).inputs.build_number, "42");
  assert.equal(JSON.parse(h.calls[0].body).inputs.operation, "review");
});

for (const [name, fields, options] of [
  ["wrong user", { user_id: "U999" }], ["wrong workspace", { team_id: "T999" }],
  ["wrong channel", { channel_id: "C999" }], ["unknown command", { command: "/release" }],
  ["unapproved branch", { text: "feature/untrusted" }], ["shell payload", { text: "dev; touch /tmp/pwned" }],
  ["extra argument", { text: "dev main" }], ["missing review build", { command: "/review", text: "2.0.1" }],
  ["latest review selection", { command: "/review", text: "2.0.1 latest" }],
  ["expired signature", {}, { age: 301 }], ["future signature", {}, { age: -301 }],
  ["wrong signature", {}, { signature: `v0=${"0".repeat(64)}` }],
  ["non-Slack callback", { response_url: "https://attacker.example/commands/foo" }],
  ["HTTP callback", { response_url: "http://hooks.slack.com/commands/foo" }],
  ["callback credentials", { response_url: "https://user:pass@hooks.slack.com/commands/foo" }],
  ["callback wrong path", { response_url: "https://hooks.slack.com/services/foo" }],
]) {
  test(`${name} never starts a deployment`, async () => {
    const h = harness(); await h.run(request(fields, options)); await h.finish(); assert.equal(h.calls.length, 0);
  });
}

test("help does not trigger a deployment", async () => {
  const h = harness(); const response = await h.run(request({ text: "help" })); await h.finish();
  assert.match((await response.json()).text, /\/review/); assert.equal(h.calls.length, 0);
});

test("help remains available before GitHub is connected", async () => {
  const h = harness({ configuration: { ...env, GITHUB_TOKEN: "" } });
  const response = await h.run(request({ text: "help" })); await h.finish();
  assert.equal(response.status, 200);
  assert.match((await response.json()).text, /\/testflight/);
  assert.equal(h.calls.length, 0);
});

test("missing GitHub credentials explain setup without dispatching", async () => {
  const h = harness({ configuration: { ...env, GITHUB_TOKEN: "" } });
  const response = await h.run(request()); await h.finish();
  assert.equal(response.status, 200);
  assert.match((await response.json()).text, /GitHub Actions 실행 권한/);
  assert.equal(h.calls.length, 0);
});

test("Slack retries do not trigger another deployment", async () => {
  const h = harness(); await h.run(request({}, { headers: { "x-slack-retry-num": "1" } }));
  await h.finish(); assert.equal(h.calls.length, 0);
});

test("missing secrets fail closed", async () => {
  const h = harness({ configuration: { ...env, SLACK_SIGNING_SECRET: "" } });
  assert.equal((await h.run(request())).status, 503); assert.equal(h.calls.length, 0);
});

test("Slack acknowledgment does not wait for GitHub", async () => {
  let complete;
  const blocked = new Promise((resolve) => { complete = resolve; });
  let pending;
  const response = await handleRequest(request(), env, { waitUntil: (p) => { pending = p; } }, async () => blocked);
  assert.equal(response.status, 200);
  assert.match((await response.json()).text, /접수/);
  complete(new Response(null, { status: 204 })); await pending;
});

test("GitHub rejects are reported without retrying or leaking secrets", async () => {
  const h = harness({ githubStatus: 403 }); await h.run(request()); await h.finish();
  assert.equal(h.calls.length, 2); assert.match(h.calls[1].body, /HTTP 403/);
  assert.ok(!h.calls[1].body.includes(env.GITHUB_TOKEN));
});

test("ambiguous network failure asks to check Actions before retrying", async () => {
  const h = harness({ throwGitHub: true }); await h.run(request()); await h.finish();
  assert.equal(h.calls.length, 2); assert.match(h.calls[1].body, /접수 여부/);
  assert.ok(!h.calls[1].body.includes("private network detail"));
});
