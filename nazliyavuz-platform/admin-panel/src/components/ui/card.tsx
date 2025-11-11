"use client";

import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";

export function Card({ children, className }: PropsWithChildren<{ className?: string }>) {
  return (
    <div
      className={cn(
        "rounded-2xl border border-slate-800/80 bg-slate-950/60 p-8 shadow-[0_8px_40px_rgba(15,23,42,0.45)] backdrop-blur",
        className,
      )}
    >
      {children}
    </div>
  );
}

export function CardHeader({ children, className }: PropsWithChildren<{ className?: string }>) {
  return <div className={cn("mb-6 space-y-2", className)}>{children}</div>;
}

export function CardTitle({ children, className }: PropsWithChildren<{ className?: string }>) {
  return (
    <h2 className={cn("text-2xl font-semibold text-slate-100", className)}>
      {children}
    </h2>
  );
}

export function CardDescription({
  children,
  className,
}: PropsWithChildren<{ className?: string }>) {
  return (
    <p className={cn("text-sm text-slate-400", className)}>{children}</p>
  );
}

