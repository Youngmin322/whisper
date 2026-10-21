import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { readFile } from "node:fs/promises";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";

const source = await readFile(new URL("../src/worker.js", import.meta.url), "utf8");
const bindings = {
  SLACK_SIGNING_SECRET: "runtime-test-secret", GITHUB_TOKEN: "runtime-test-token",
  SLACK_TEAM_ID: "T123", SLACK_ALLOWED_USER_IDS: "U123", SLACK_ALLOWED_CHANNEL_IDS: "C123",
  GITHUB_REPOSITORY: "test/repo", GITHUB_WORKFLOW: "deploy.yml", GITHUB_WORKFLOW_REF: "dev",
  DEFAULT_BRANCH: "dev", ALLOWED_BRANCHES: "dev",
};

for (const githubStatus of [204, 302]) {
  test(`Worker runtime dispatch and callback with GitHub HTTP ${githubStatus}`, async () => {
    const calls = [];
    let callbackReceived;
    const callback = new Promise((resolve) => { callbackReceived = resolve; });
    const runtime = new Miniflare(convertV4MiniflareOptions({
      modules: true, script: source, compatibilityDate: "2026-10-20", cf: false,
      bindings,
      // Every outgoing request is intercepted locally. No credentials leave this test.
      outboundService: async (request) => {
        const host = new URL(request.url).hostname;
        calls.push({ host, body: await request.json() });
        if (host === "api.github.com") {
          return new Response(null, { status: githubStatus,
            headers: githubStatus === 302 ? { Location: "https://unexpected.example/redirect" } : {} });
        }
        assert.equal(host, "hooks.slack.com");
        callbackReceived();
        return new Response("ok");
      },
    }));
    try {
      const body = new URLSearchParams({ team_id: "T123", user_id: "U123", channel_id: "C123",
        command: "/testflight", text: "dev", response_url: "https://hooks.slack.com/commands/test/callback" }).toString();
      const timestamp = String(Math.floor(Date.now() / 1000));
      const signature = "v0=" + createHmac("sha256", bindings.SLACK_SIGNING_SECRET)
        .update(`v0:${timestamp}:${body}`).digest("hex");
      const response = await runtime.dispatchFetch("https://worker.test/slack/commands", {
        method: "POST", body, headers: { "content-type": "application/x-www-form-urlencoded",
          "x-slack-request-timestamp": timestamp, "x-slack-signature": signature },
      });
      assert.equal(response.status, 200);
      assert.match((await response.json()).text, /접수/);
      await Promise.race([callback, new Promise((_, reject) => {
        const timer = setTimeout(() => reject(new Error("Worker did not send its callback")), 3000);
        timer.unref();
      })]);
      assert.deepEqual(calls.map(({ host }) => host), ["api.github.com", "hooks.slack.com"]);
      assert.equal(calls[0].body.inputs.operation, "testflight");
      assert.match(calls[1].body.text, githubStatus === 204 ? /dev TestFlight 배포/ : /실패.*HTTP 302/);
    } finally {
      await runtime.dispose();
    }
  });
}
