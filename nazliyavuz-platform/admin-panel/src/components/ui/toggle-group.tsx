import * as React from "react";
import * as ToggleGroupPrimitive from "@radix-ui/react-toggle-group";

import { cn } from "@/lib/utils";

const ToggleGroup = React.forwardRef<
  React.ElementRef<typeof ToggleGroupPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof ToggleGroupPrimitive.Root>
>(({ className, ...props }, ref) => (
  <ToggleGroupPrimitive.Root
    ref={ref}
    className={cn(
      "inline-flex overflow-hidden rounded-lg border border-slate-800/70 bg-slate-950/40 p-1 text-slate-200 shadow-sm",
      className,
    )}
    {...props}
  />
));
ToggleGroup.displayName = ToggleGroupPrimitive.Root.displayName;

const ToggleGroupItem = React.forwardRef<
  React.ElementRef<typeof ToggleGroupPrimitive.Item>,
  React.ComponentPropsWithoutRef<typeof ToggleGroupPrimitive.Item>
>(({ className, ...props }, ref) => (
  <ToggleGroupPrimitive.Item
    ref={ref}
    className={cn(
      "inline-flex min-w-[2.25rem] flex-1 items-center justify-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition-all",
      "text-slate-400 hover:bg-slate-900/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400",
      "data-[state=on]:bg-sky-500/10 data-[state=on]:text-sky-200 data-[state=on]:shadow-inner",
      "data-[state=on]:ring-1 data-[state=on]:ring-sky-500/40",
      className,
    )}
    {...props}
  />
));
ToggleGroupItem.displayName = ToggleGroupPrimitive.Item.displayName;

export { ToggleGroup, ToggleGroupItem };

