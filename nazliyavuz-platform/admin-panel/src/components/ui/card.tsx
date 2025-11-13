"use client";

import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";

export function Card({ children, className }: PropsWithChildren<{ className?: string }>) {
  return (
    <div
      className={cn(
        "rounded-xl border border-slate-800/80 bg-slate-950/60 p-4 shadow-[0_8px_40px_rgba(15,23,42,0.45)] backdrop-blur md:rounded-2xl md:p-8",
        className,
      )}
    >
      {children}
    </div>
  );
}

export function CardHeader({ children, className }: PropsWithChildren<{ className?: string }>) {
  return <div className={cn("mb-4 space-y-1.5 md:mb-6 md:space-y-2", className)}>{children}</div>;
}

export function CardTitle({ children, className }: PropsWithChildren<{ className?: string }>) {
  return (
    <h2 className={cn("text-xl font-semibold text-slate-100 md:text-2xl", className)}>
      {children}
    </h2>
  );
}

export function CardDescription({
  children,
  className,
}: PropsWithChildren<{ className?: string }>) {
  return (
    <p className={cn("text-xs text-slate-400 md:text-sm", className)}>{children}</p>
  );
}

