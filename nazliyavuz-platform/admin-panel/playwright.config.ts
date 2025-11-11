import { defineConfig, devices } from "@playwright/test";

const webServerPort = Number.parseInt(
  process.env.PLAYWRIGHT_WEB_PORT ?? "3100",
  10,
);

const baseURL =
  process.env.PLAYWRIGHT_BASE_URL ?? `http://127.0.0.1:${webServerPort}`;

const apiBaseURL =
  process.env.PLAYWRIGHT_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  timeout: 60 * 1000,
  expect: {
    timeout: 10 * 1000,
  },
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    headless: process.env.CI ? true : undefined,
  },
  webServer: [
    {
      command: `npm run dev -- --port ${webServerPort}`,
      url: baseURL,
      reuseExistingServer: true,
      stdout: "pipe",
      stderr: "pipe",
      env: {
        ...process.env,
        NEXT_PUBLIC_API_BASE_URL: apiBaseURL,
      },
      timeout: 120 * 1000,
    },
  ],
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  reporter:
    process.env.CI === "true"
      ? [["github"], ["html", { open: "never" }]]
      : [["list"], ["html", { open: "never" }]],
});


