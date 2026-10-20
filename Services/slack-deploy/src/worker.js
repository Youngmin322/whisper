const encoder = new TextEncoder();
const list = (value) => (value ?? "").split(",").map((item) => item.trim()).filter(Boolean);
const reply = (text, status = 200) => Response.json({ response_type: "ephemeral", text }, { status });

async function authentic(request, body, secret) {
  const timestamp = request.headers.get("x-slack-request-timestamp") ?? "";
  const signature = request.headers.get("x-slack-signature") ?? "";
  if (!/^\d+$/.test(timestamp) || Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) return false;
  if (!/^v0=[a-f0-9]{64}$/.test(signature)) return false;
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
  const bytes = Uint8Array.from(signature.slice(3).match(/../g), (hex) => Number.parseInt(hex, 16));
  return crypto.subtle.verify("HMAC", key, bytes, encoder.encode(`v0:${timestamp}:${body}`));
}

export function parseCommand(command, text, env) {
  const args = text.trim().split(/\s+/).filter(Boolean);
  if (text.trim() === "help") return { help: true };
  if (command === "/testflight") {
    const branch = args[0] ?? env.DEFAULT_BRANCH;
    if (args.length > 1 || !list(env.ALLOWED_BRANCHES).includes(branch)) {
      throw new Error(`사용법: /testflight [${list(env.ALLOWED_BRANCHES).join("|")}]`);
    }
    return { operation: "testflight", branch, version: "", build_number: "" };
  }
  if (command === "/review") {
    if (args.length !== 2 || !/^\d{1,4}(\.\d{1,3}){1,2}$/.test(args[0]) || !/^\d{1,4}(\.\d{1,2}){0,2}$/.test(args[1])) {
      throw new Error("사용법: /review 버전 빌드번호 (예: /review 2.0.1 42)");
    }
    return { operation: "review", branch: env.DEFAULT_BRANCH, version: args[0], build_number: args[1] };
  }
  throw new Error("등록되지 않은 명령어예요.");
}

function validConfiguration(env) {
  return ["SLACK_SIGNING_SECRET", "GITHUB_TOKEN", "SLACK_TEAM_ID", "SLACK_ALLOWED_USER_IDS", "SLACK_ALLOWED_CHANNEL_IDS", "DEFAULT_BRANCH", "ALLOWED_BRANCHES", "GITHUB_WORKFLOW_REF"]
    .every((key) => env[key]?.trim() && !env[key].includes("REPLACE_WITH"))
    && /^[\w.-]+\/[\w.-]+$/.test(env.GITHUB_REPOSITORY ?? "")
    && /^[\w.-]+\.ya?ml$/.test(env.GITHUB_WORKFLOW ?? "")
    && list(env.ALLOWED_BRANCHES).includes(env.DEFAULT_BRANCH);
}

function responseURL(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.hostname === "hooks.slack.com" && !url.port
      && !url.username && !url.password && url.pathname.startsWith("/commands/") ? url.href : null;
  } catch { return null; }
}

async function postResponse(url, text, fetcher) {
  const result = await fetcher(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ response_type: "ephemeral", text }),
    signal: AbortSignal.timeout(8000),
    redirect: "error",
  });
  if (!result.ok) throw new Error(`Slack response failed (${result.status})`);
}

async function dispatch(inputs, callback, env, fetcher) {
  const actionsURL = `https://github.com/${env.GITHUB_REPOSITORY}/actions/workflows/${env.GITHUB_WORKFLOW}`;
  let text;
  try {
    const result = await fetcher(`https://api.github.com/repos/${env.GITHUB_REPOSITORY}/actions/workflows/${env.GITHUB_WORKFLOW}/dispatches`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        Accept: "application/vnd.github+json",
        "Content-Type": "application/json",
        "X-GitHub-Api-Version": "2026-03-10",
        "User-Agent": "whisper-slack-deploy",
      },
      body: JSON.stringify({ ref: env.GITHUB_WORKFLOW_REF, inputs }),
      signal: AbortSignal.timeout(10000),
      redirect: "error",
    });
    text = result.ok
      ? `GitHub Actions에 ${inputs.operation === "testflight" ? `${inputs.branch} TestFlight 배포` : `${inputs.version} (${inputs.build_number}) 심사 제출`}를 요청했어요.\n진행 상황: ${actionsURL}`
      : `GitHub Actions 실행 요청이 실패했어요 (HTTP ${result.status}). 워크플로와 토큰 권한을 확인해주세요.`;
  } catch {
    // A timeout can occur after GitHub accepted the request. Avoid an automatic duplicate upload.
    text = `GitHub Actions의 접수 여부를 확인하지 못했어요. 다시 실행하기 전에 진행 중인 작업을 확인해주세요.\n${actionsURL}`;
  }
  try { await postResponse(callback, text, fetcher); }
  catch { console.error("Could not deliver Slack command response; check GitHub Actions."); }
}

export async function handleRequest(request, env, ctx, fetcher = fetch) {
  const path = new URL(request.url).pathname;
  if (path === "/health" && request.method === "GET") return Response.json({ ok: true });
  if (path !== "/slack/commands") return new Response("Not found", { status: 404 });
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405, headers: { Allow: "POST" } });
  if (!validConfiguration(env)) return reply("배포 연결 설정이 아직 완료되지 않았어요.", 503);
  if (!request.headers.get("content-type")?.startsWith("application/x-www-form-urlencoded")) return reply("지원하지 않는 요청 형식이에요.", 415);
  const body = await request.text();
  if (encoder.encode(body).length > 16384) return reply("요청이 너무 커요.", 413);
  if (!await authentic(request, body, env.SLACK_SIGNING_SECRET)) return reply("Slack 요청을 인증하지 못했어요.", 401);
  const form = new URLSearchParams(body);
  if ([...new Set(form.keys())].some((key) => form.getAll(key).length !== 1)) return reply("중복된 요청 필드가 있어요.", 400);
  if (form.get("team_id") !== env.SLACK_TEAM_ID || !list(env.SLACK_ALLOWED_USER_IDS).includes(form.get("user_id"))
    || !list(env.SLACK_ALLOWED_CHANNEL_IDS).includes(form.get("channel_id"))) return reply("이 워크스페이스·사용자·채널에는 배포 권한이 없어요.");
  const command = form.get("command");
  if (!["/testflight", "/review"].includes(command)) return reply("등록되지 않은 명령어예요.");
  if (request.headers.has("x-slack-retry-num")) return reply("Slack 재전송 요청은 중복 실행하지 않았어요. GitHub Actions에서 접수 여부를 확인해주세요.");
  let inputs;
  try { inputs = parseCommand(command, form.get("text") ?? "", env); }
  catch (error) { return reply(error.message); }
  if (inputs.help) return reply(`/testflight [브랜치]: 내부 테스트 빌드 업로드 (${env.ALLOWED_BRANCHES})\n/review 버전 빌드번호: 기존 빌드 심사 제출`);
  const callback = responseURL(form.get("response_url"));
  if (!callback) return reply("Slack 응답 주소가 올바르지 않아요.", 400);
  inputs.requester = form.get("user_id");
  // No network call is awaited before acknowledgment: Slack requires a reply within 3 seconds.
  ctx.waitUntil(dispatch(inputs, callback, env, fetcher));
  return reply("요청을 접수했어요. GitHub Actions 연결 결과를 곧 알려드릴게요.");
}

export default { fetch: handleRequest };
