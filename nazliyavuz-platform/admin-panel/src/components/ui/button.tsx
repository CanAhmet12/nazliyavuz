"use client";

import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500/70 disabled:pointer-events-none disabled:opacity-60 active:scale-[0.98]",
  {
    variants: {
      variant: {
        default:
          "bg-sky-500 text-white shadow-sky-500/30 hover:bg-sky-400 active:bg-sky-500/90 shadow-sm",
        secondary:
          "bg-slate-800 text-slate-100 hover:bg-slate-700 active:bg-slate-800/90",
        outline:
          "border border-slate-700 bg-slate-900 text-slate-100 hover:bg-slate-800",
        ghost: "text-slate-300 hover:bg-slate-800/70",
        destructive:
          "bg-rose-500 text-white hover:bg-rose-500/90 focus-visible:ring-rose-400/70",
      },
      size: {
        default: "min-h-[44px] h-10 px-4 py-2 md:min-h-0",
        sm: "min-h-[36px] h-9 rounded-md px-3 text-xs md:min-h-0",
        lg: "min-h-[48px] h-11 rounded-xl px-6 text-base md:min-h-0",
        icon: "min-h-[44px] h-10 w-10 md:min-h-0",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  },
);
Button.displayName = "Button";

