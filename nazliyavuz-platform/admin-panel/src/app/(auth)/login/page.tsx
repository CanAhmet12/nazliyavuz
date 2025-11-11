import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { LoginForm } from "@/components/auth/login-form";
import Image from "next/image";

export default function LoginPage() {
  return (
    <Card className="relative overflow-hidden">
      <div className="absolute inset-x-0 -top-40 flex justify-center">
        <div className="h-72 w-72 rounded-full bg-sky-500/20 blur-3xl" />
      </div>

      <div className="absolute inset-0 rounded-2xl border border-white/5" />

      <div className="relative z-10 space-y-8">
        <CardHeader className="space-y-4 text-center">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-sky-500/10">
            <Image
              src="/logo.png"
              alt="NazlıYavuz"
              width={40}
              height={40}
              className="rounded-lg"
              priority
            />
          </div>
          <div className="space-y-2">
            <CardTitle>NazlıYavuz Yönetim Paneli</CardTitle>
            <CardDescription>
              Giriş yaparak platformun öğretmen, öğrenci ve rezervasyon süreçlerini
              tek merkezden yönetin.
            </CardDescription>
          </div>
        </CardHeader>

        <LoginForm />
      </div>
    </Card>
  );
}

