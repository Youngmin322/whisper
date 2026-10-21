import test from "node:test";
import assert from "node:assert/strict";
import { notifySlack } from "./notify-slack.mjs";

const env = { SLACK_WEBHOOK_URL: "https://hooks.slack.com/services/test/only", GITHUB_REPOSITORY: "Youngmin322/whisper", GITHUB_RUN_ID: "123", DEPLOY_STATUS: "success", DEPLOY_OPERATION: "testflight", DEPLOY_REQUESTER: "U123", DEPLOY_DETAIL: "2.0.1 (42)" };

test("notification includes status, version, requester, and run link", async () => {
  let sent;
  await notifySlack(env, async (_url, options) => { sent = options; return new Response("ok"); });
  assert.match(sent.body, /TestFlight 업로드 완료/); assert.match(sent.body, /2.0.1 \(42\)/);
  assert.match(sent.body, /<@U123>/); assert.match(sent.body, /actions\/runs\/123/);
  assert.equal(sent.redirect, "error");
});
test("review notification does not claim release or approval", async () => {
  await notifySlack({ ...env, DEPLOY_OPERATION: "review" }, async (_url, options) => {
    assert.match(options.body, /심사 제출 완료/); assert.doesNotMatch(options.body, /승인|출시/); return new Response("ok");
  });
});
test("foreign webhook is rejected before networking", async () => {
  await assert.rejects(notifySlack({ ...env, SLACK_WEBHOOK_URL: "https://attacker.example/services/test" }, () => assert.fail("must not send")), /Slack incoming webhook/);
});
test("failed notification returns a useful error", async () => {
  await assert.rejects(notifySlack(env, async () => new Response("no", { status: 403 })), /HTTP 403/);
});
