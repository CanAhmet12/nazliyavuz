"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";
import { apiClient } from "@/lib/api/client";

type AuthUser = {
  id: number;
  name: string;
  email: string;
  role: string;
  avatarUrl?: string | null;
};

type AuthResponse = {
  success: boolean;
  message?: string;
  user: AuthUser;
  token: {
    access_token: string;
    token_type: string;
    expires_in: number;
  };
  refresh_token?: string;
};

type RefreshResponse = {
  success: boolean;
  token: {
    access_token: string;
    token_type: string;
    expires_in: number;
  };
};

type AuthState = {
  user: AuthUser | null;
  accessToken: string | null;
  refreshToken: string | null;
  expiresAt: number | null;
  isAuthLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  refreshSession: () => Promise<void>;
  clearSession: () => void;
  setSession: (payload: {
    user: AuthUser;
    accessToken: string;
    expiresIn: number;
    refreshToken?: string | null;
  }) => void;
};

export const authStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      accessToken: null,
      refreshToken: null,
      expiresAt: null,
      isAuthLoading: false,
      async login(email, password) {
        set({ isAuthLoading: true });
        try {
          const { data } = await apiClient.post<AuthResponse>("/auth/login", {
            email,
            password,
          });

          if (!data.user || data.user.role !== "admin") {
            throw new Error("Yalnızca admin hesapları paneli kullanabilir.");
          }

          const refreshToken =
            data.refresh_token ??
            (data as unknown as { refresh_token?: string }).refresh_token ??
            null;

          get().setSession({
            user: data.user,
            accessToken: data.token.access_token,
            expiresIn: data.token.expires_in,
            refreshToken,
          });
        } finally {
          set({ isAuthLoading: false });
        }
      },
      async refreshSession() {
        const refreshToken = get().refreshToken;
        if (!refreshToken) {
          throw new Error("Oturum yenileme tokenı bulunamadı.");
        }

        const { data } = await apiClient.post<RefreshResponse>(
          "/auth/refresh",
          {
            refresh_token: refreshToken,
          },
        );

        set({
          accessToken: data.token.access_token,
          expiresAt: Date.now() + data.token.expires_in * 1000,
        });
      },
      setSession({ user, accessToken, expiresIn, refreshToken }) {
        set({
          user,
          accessToken,
          refreshToken: refreshToken ?? null,
          expiresAt: Date.now() + expiresIn * 1000,
        });
      },
      clearSession() {
        set({
          user: null,
          accessToken: null,
          refreshToken: null,
          expiresAt: null,
        });
      },
    }),
    {
      name: "nazliyavuz-admin-auth",
      partialize: (state) => ({
        user: state.user,
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        expiresAt: state.expiresAt,
      }),
    },
  ),
);

