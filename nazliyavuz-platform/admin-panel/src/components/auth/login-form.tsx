"use client";

import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { isAxiosError } from "axios";
import toast from "react-hot-toast";
import { Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { loginSchema, type LoginSchema } from "@/lib/validations/auth";
import { authStore } from "@/store/auth-store";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function LoginForm() {
  const router = useRouter();
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginSchema>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: "",
      password: "",
      remember: false,
    },
  });

  const login = authStore((state) => state.login);
  const user = authStore((state) => state.user);
  const isAuthLoading = authStore((state) => state.isAuthLoading);

  useEffect(() => {
    if (user) {
      router.replace("/dashboard");
    }
  }, [router, user]);

  const onSubmit = async (values: LoginSchema) => {
    try {
      await login(values.email, values.password);
      toast.success("Hoş geldiniz!");
      router.replace("/dashboard");
    } catch (error) {
      let message = "Giriş yapılırken bir hata oluştu.";
      if (isAxiosError(error)) {
        message =
          error.response?.data?.message ||
          error.response?.data?.error?.message ||
          error.message;
      } else if (error instanceof Error) {
        message = error.message;
      }
      toast.error(message);
    }
  };

  const loading = isSubmitting || isAuthLoading;

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
      <div className="space-y-2">
        <Label htmlFor="email">E-posta adresi</Label>
        <Input
          id="email"
          type="email"
          placeholder="admin@nazliyavuz.com"
          autoComplete="email"
          disabled={loading}
          {...register("email")}
        />
        {errors.email && (
          <p className="text-sm text-rose-400">{errors.email.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label htmlFor="password">Şifre</Label>
          <button
            type="button"
            className="text-xs font-medium text-slate-400 hover:text-slate-200"
          >
            Şifremi unuttum
          </button>
        </div>
        <Input
          id="password"
          type="password"
          placeholder="••••••••"
          autoComplete="current-password"
          disabled={loading}
          {...register("password")}
        />
        {errors.password && (
          <p className="text-sm text-rose-400">{errors.password.message}</p>
        )}
      </div>

      <Button type="submit" className="w-full" disabled={loading}>
        {loading ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" />
            Giriş yapılıyor...
          </>
        ) : (
          "Panele giriş yap"
        )}
      </Button>

      <p className="text-xs text-slate-500">
        Bu panel yalnızca yetkili NazlıYavuz yöneticilerinin kullanımına
        açıktır. Giriş yaparak tüm aksiyonların kayıt altına alınacağını kabul
        edersiniz.
      </p>
    </form>
  );
}

