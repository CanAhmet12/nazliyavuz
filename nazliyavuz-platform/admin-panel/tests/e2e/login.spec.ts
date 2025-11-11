import { test, expect } from "@playwright/test";

const apiBaseURL =
  process.env.PLAYWRIGHT_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1";

const adminUser = {
  id: 1,
  name: "Test Admin",
  email: "admin@nazliyavuz.com",
  role: "admin",
  avatarUrl: null,
};

function buildApiUrl(endpoint: string) {
  const base = apiBaseURL.endsWith("/")
    ? apiBaseURL
    : `${apiBaseURL.replace(/\/+$/, "")}/`;
  return new URL(endpoint.replace(/^\/+/, ""), base).toString();
}

test.describe("Admin authentication", () => {
  test("allows a valid admin to sign in and reach the dashboard", async ({
    page,
  }) => {
    await page.route(buildApiUrl("/auth/login"), async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          success: true,
          user: adminUser,
          token: {
            access_token: "test-access-token",
            token_type: "Bearer",
            expires_in: 3600,
          },
          refresh_token: "test-refresh-token",
        }),
      });
    });

    await page.goto("/login");

    await expect(
      page.getByRole("heading", { name: "NazlıYavuz Yönetim Paneli" }),
    ).toBeVisible();

    await page.getByLabel("E-posta adresi").fill(adminUser.email);
    await page.getByLabel("Şifre").fill("password123");

    await page.getByRole("button", { name: "Panele giriş yap" }).click();

    await page.waitForURL("**/dashboard");

    await expect(page).toHaveURL(/\/dashboard$/);
    await expect(
      page.getByRole("heading", { name: "Yönetim Paneli" }),
    ).toBeVisible();
    await expect(page.getByText("Gerçek zamanlı aktiviteler")).toBeVisible();
  });

  test("shows an error toast for invalid credentials", async ({ page }) => {
    await page.route(buildApiUrl("/auth/login"), async (route) => {
      await route.fulfill({
        status: 401,
        contentType: "application/json",
        body: JSON.stringify({
          success: false,
          message: "Kimlik bilgileri hatalı.",
        }),
      });
    });

    await page.goto("/login");

    await page.getByLabel("E-posta adresi").fill("wrong@nazliyavuz.com");
    await page.getByLabel("Şifre").fill("wrongpass");

    const responsePromise = page.waitForResponse((response) => {
      return (
        response.url() === buildApiUrl("/auth/login") &&
        response.request().method() === "POST"
      );
    });
    await page.getByRole("button", { name: "Panele giriş yap" }).click();
    const loginResponse = await responsePromise;
    expect(loginResponse.status()).toBe(401);

    await expect(page).toHaveURL(/\/login$/);
    await expect(
      page.getByText("Kimlik bilgileri hatalı", { exact: false }),
    ).toBeVisible();
  });
});


