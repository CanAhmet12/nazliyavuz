/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";

import axios from "axios";
import { API_BASE_URL } from "@/lib/config";
import { authStore } from "@/store/auth-store";

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 15000,
  withCredentials: false,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

apiClient.interceptors.request.use(
  (config) => {
    const token = authStore.getState().accessToken;
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    config.headers.Accept = "application/json";
    config.headers["Content-Type"] = "application/json";
    return config;
  },
  (error) => Promise.reject(error),
);

apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config as any;
    if (
      error.response?.status === 401 &&
      !originalRequest._retry &&
      authStore.getState().refreshToken
    ) {
      originalRequest._retry = true;
      try {
        await authStore.getState().refreshSession();
        const token = authStore.getState().accessToken;
        if (token) {
          originalRequest.headers.Authorization = `Bearer ${token}`;
        }
        return apiClient(originalRequest);
      } catch {
        authStore.getState().clearSession();
      }
    }

    return Promise.reject(error);
  },
);

