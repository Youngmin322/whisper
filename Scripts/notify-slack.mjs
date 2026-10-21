import { pathToFileURL } from "node:url";

export async function notifySlack(env, fetcher = fetch) {
  if (!env.SLACK_WEBHOOK_URL) throw new Error("SLACK_WEBHOOK_URL is missing");
  const url = new URL(env.SLACK_WEBHOOK_URL);
  if (url.protocol !== "https:" || url.hostname !== "hooks.slack.com" || !url.pathname.startsWith("/services/") || url.username || url.password || url.port) {
    throw new Error("SLACK_WEBHOOK_URL must be a Slack incoming webhook");
  }
  const operation = env.DEPLOY_OPERATION === "review" ? "App Store 심사 제출" : "TestFlight 업로드";
  const status = { started: "시작", success: "완료", failure: "실패", cancelled: "취소" }[env.DEPLOY_STATUS] ?? "상태 확인 필요";
  const requester = /^[UW][A-Z0-9]+$/.test(env.DEPLOY_REQUESTER ?? "") ? `<@${env.DEPLOY_REQUESTER}>` : "GitHub Actions";
  const repository = env.GITHUB_REPOSITORY;
  if (!/^[\w.-]+\/[\w.-]+$/.test(repository ?? "") || !/^\d+$/.test(env.GITHUB_RUN_ID ?? "")) throw new Error("Invalid GitHub run context");
  const detail = (env.DEPLOY_DETAIL ?? "").replace(/[<>&]/g, "").slice(0, 200);
  const response = await fetcher(url.href, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: `Whisper ${operation} ${status}\n요청: ${requester}${detail ? `\n${detail}` : ""}\nhttps://github.com/${repository}/actions/runs/${env.GITHUB_RUN_ID}` }),
    signal: AbortSignal.timeout(10000),
    redirect: "error",
  });
  if (!response.ok) throw new Error(`Slack notification failed (HTTP ${response.status})`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try { await notifySlack(process.env); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
