"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { AlertTriangle } from "lucide-react";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log error to console for debugging
    console.error("Application error:", error);
  }, [error]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-950 px-4">
      <div className="w-full max-w-md space-y-6 rounded-xl border border-slate-800/80 bg-slate-950/60 p-6 text-center">
        <div className="flex justify-center">
          <div className="rounded-full bg-rose-500/10 p-3">
            <AlertTriangle className="h-6 w-6 text-rose-500" />
        </div>
        </div>
        <div className="space-y-2">
          <h1 className="text-xl font-semibold text-slate-100">
            Bir hata oluştu
          </h1>
          <p className="text-sm text-slate-400">
            Uygulama yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.
          </p>
          {error.message && (
            <p className="mt-2 rounded-lg border border-slate-800/60 bg-slate-900/60 p-3 text-xs text-slate-400">
              {error.message}
            </p>
          )}
          {process.env.NODE_ENV === "development" && error.stack && (
            <details className="mt-4 text-left">
              <summary className="cursor-pointer text-xs text-slate-500 hover:text-slate-400">
                Hata detayları (geliştirme modu)
              </summary>
              <pre className="mt-2 max-h-40 overflow-auto rounded-lg border border-slate-800/60 bg-slate-900/60 p-3 text-xs text-slate-400">
                {error.stack}
              </pre>
            </details>
          )}
        </div>
        <div className="flex gap-3">
          <Button
            variant="outline"
            onClick={() => (window.location.href = "/login")}
            className="flex-1"
          >
            Giriş Sayfasına Dön
          </Button>
          <Button onClick={reset} className="flex-1">
            Tekrar Dene
          </Button>
        </div>
      </div>
    </div>
  );
}

