"use client";

import { Toaster } from "react-hot-toast";

export function ToastProvider() {
  return (
    <Toaster
      position="top-right"
      toastOptions={{
        duration: 4000,
        style: {
          background: "#0f172a",
          color: "#e2e8f0",
          border: "1px solid rgba(148, 163, 184, 0.24)",
        },
      }}
    />
  );
}

