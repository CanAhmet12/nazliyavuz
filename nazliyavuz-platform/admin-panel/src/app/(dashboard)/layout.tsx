"use client";

import type { PropsWithChildren } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Image from "next/image";
import { authStore } from "@/store/auth-store";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetTrigger,
} from "@/components/ui/sheet";
import {
  LogOut,
  User2,
  LayoutDashboard,
  Users,
  UserCheck,
  CalendarClock,
  Bell,
  PiggyBank,
  LineChart,
  Database,
  Menu,
} from "lucide-react";
import { cn } from "@/lib/utils";

type NavIconName =
  | "layout-dashboard"
  | "users"
  | "user-check"
  | "calendar-clock"
  | "bell"
  | "piggy-bank"
  | "line-chart"
  | "database";

const navigation: Array<{ name: string; href: string; icon: NavIconName }> = [
  { name: "Dashboard", href: "/dashboard", icon: "layout-dashboard" },
  { name: "Kullanıcılar", href: "/users", icon: "users" },
  { name: "Öğretmen Onayı", href: "/teacher-approvals", icon: "user-check" },
  { name: "Rezervasyonlar", href: "/reservations", icon: "calendar-clock" },
  { name: "Bildirimler", href: "/notifications", icon: "bell" },
  { name: "Finans", href: "/finance", icon: "piggy-bank" },
  { name: "Analitik", href: "/analytics", icon: "line-chart" },
  { name: "Yedekleme", href: "/backups", icon: "database" },
];

export default function DashboardLayout({ children }: PropsWithChildren) {
  const router = useRouter();
  const pathname = usePathname();
  const user = authStore((state) => state.user);
  const clearSession = authStore((state) => state.clearSession);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    if (!user) {
      router.replace("/login");
    }
  }, [router, user]);

  if (!user) {
    return null;
  }

  const SidebarContent = () => (
    <>
      <div className="flex items-center gap-3 px-2">
        <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-sky-500/10">
          <Image
            src="/logo.png"
            alt="NazlıYavuz"
            width={28}
            height={28}
            className="rounded-lg"
          />
        </div>
        <div>
          <p className="text-sm font-semibold text-slate-100">
            NazlıYavuz Admin
          </p>
          <p className="text-xs text-slate-500">Operasyon kontrol merkezi</p>
        </div>
      </div>

      <nav className="mt-8 flex flex-1 flex-col gap-1">
        {navigation.map((item) => (
          <button
            key={item.href}
            type="button"
            onClick={() => {
              router.push(item.href);
              setMobileMenuOpen(false);
            }}
            className={cn(
              "flex items-center gap-3 rounded-lg px-3 py-2 text-sm text-slate-400 transition-all hover:bg-slate-800/60 hover:text-slate-100",
              pathname === item.href && "bg-sky-500/15 text-sky-300",
            )}
          >
            <NavIcon name={item.icon} active={pathname === item.href} />
            {item.name}
          </button>
        ))}
      </nav>

      <div className="mt-auto space-y-3 rounded-xl border border-slate-800/60 bg-slate-950/60 p-4">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-sky-500/10 text-sky-200">
            <User2 className="h-4 w-4" />
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-slate-100">
              {user.name}
            </p>
            <p className="truncate text-xs text-slate-400">{user.email}</p>
          </div>
        </div>
        <Button
          variant="ghost"
          className="w-full justify-start gap-2 text-sm text-slate-400 hover:text-rose-300"
          onClick={() => {
            clearSession();
            router.replace("/login");
          }}
        >
          <LogOut className="h-4 w-4" />
          Çıkış Yap
        </Button>
      </div>
    </>
  );

  return (
    <div className="flex min-h-screen bg-slate-950">
      {/* Desktop Sidebar */}
      <aside className="hidden w-64 flex-col border-r border-slate-800/80 bg-slate-950/70 px-4 py-6 md:flex">
        <SidebarContent />
      </aside>

      <main className="flex flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-slate-800/80 bg-slate-950/60 px-4 py-3 md:px-6 md:py-4">
          <div className="flex items-center gap-3">
            <Sheet open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
              <SheetTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="md:hidden text-slate-300 hover:bg-slate-800/60"
                >
                  <Menu className="h-5 w-5" />
                </Button>
              </SheetTrigger>
              <SheetContent side="left" className="w-64 p-0">
                <div className="flex h-full flex-col px-4 py-6">
                  <SidebarContent />
                </div>
              </SheetContent>
            </Sheet>
            <div>
              <h1 className="text-base font-semibold text-slate-100 md:text-lg">
                Yönetim Paneli
              </h1>
              <p className="hidden text-sm text-slate-400 md:block">
                Platform metriklerini ve operasyonel süreçleri buradan yönetin.
              </p>
            </div>
          </div>
          <Button
            variant="outline"
            size="sm"
            className="hidden border-slate-800 bg-slate-950 text-slate-300 hover:bg-slate-900/80 md:flex"
            onClick={() => router.push("/notifications")}
          >
            Yeni bildirim oluştur
          </Button>
        </header>
        <section className="flex-1 overflow-y-auto bg-slate-950 px-4 py-4 md:px-6 md:py-6">
          {children}
        </section>
      </main>
    </div>
  );
}

function NavIcon({
  name,
  active,
}: {
  name: NavIconName;
  active: boolean;
}) {
  const className = cn(
    "h-4 w-4",
    active ? "text-sky-300" : "text-slate-500",
  );

  switch (name) {
    case "layout-dashboard":
      return <LayoutDashboard className={className} />;
    case "users":
      return <Users className={className} />;
    case "user-check":
      return <UserCheck className={className} />;
    case "calendar-clock":
      return <CalendarClock className={className} />;
    case "bell":
      return <Bell className={className} />;
    case "piggy-bank":
      return <PiggyBank className={className} />;
    case "line-chart":
      return <LineChart className={className} />;
    case "database":
      return <Database className={className} />;
    default:
      return null;
  }
}

