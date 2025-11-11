import { z } from "zod";

export const loginSchema = z.object({
  email: z
    .string({
      required_error: "E-posta adresi zorunludur",
    })
    .email("Geçerli bir e-posta adresi girin"),
  password: z
    .string({
      required_error: "Şifre zorunludur",
    })
    .min(8, "Şifre en az 8 karakter olmalıdır"),
  remember: z.boolean().optional(),
});

export type LoginSchema = z.infer<typeof loginSchema>;

