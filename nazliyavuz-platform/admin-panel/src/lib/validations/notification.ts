import { z } from "zod";

export const notificationSchema = z.object({
  title: z
    .string()
    .min(1, "Başlık zorunludur")
    .min(3, "Başlık en az 3 karakter olmalıdır"),
  message: z
    .string()
    .min(1, "Mesaj zorunludur")
    .min(10, "Mesaj en az 10 karakter olmalıdır")
    .max(1000, "Mesaj 1000 karakterden uzun olamaz"),
  type: z.enum(["info", "success", "warning", "error"]),
  priority: z.enum(["low", "normal", "high", "urgent"]).optional(),
  targetUsers: z
    .array(z.enum(["all", "students", "teachers", "admins"]))
    .min(1, "En az bir hedef kitle seçin"),
  scheduledAt: z
    .union([z.string().min(1), z.literal(""), z.undefined()])
    .optional()
    .transform((value) => {
      if (!value || value === "" || (typeof value === "string" && value.trim().length === 0)) {
        return undefined;
      }
      const date = new Date(value as string);
      if (Number.isNaN(date.valueOf())) {
        return undefined;
      }
      return (value as string).trim();
    })
    .pipe(z.union([z.string(), z.undefined()]).optional()),
});

export type NotificationFormSchema = z.infer<typeof notificationSchema>;

export const targetedNotificationSchema = z.object({
  userId: z
    .number()
    .min(1, "Lütfen bir kullanıcı seçin")
    .positive("Geçerli bir kullanıcı seçin"),
  title: z
    .string()
    .min(1, "Başlık zorunludur")
    .min(3, "Başlık en az 3 karakter olmalıdır"),
  message: z
    .string()
    .min(1, "Mesaj zorunludur")
    .min(10, "Mesaj en az 10 karakter olmalıdır")
    .max(1000, "Mesaj 1000 karakterden uzun olamaz"),
  type: z.enum(["info", "success", "warning", "error"]),
  priority: z.enum(["low", "normal", "high", "urgent"]).optional(),
});

export type TargetedNotificationFormSchema = z.infer<
  typeof targetedNotificationSchema
>;

export const scheduledNotificationSchema = z
  .object({
    title: z
      .string()
      .min(3, "Başlık en az 3 karakter olmalıdır")
      .max(255, "Başlık 255 karakterden uzun olamaz")
      .optional()
      .or(z.literal("").transform(() => undefined)),
    message: z
      .string()
      .min(10, "Mesaj en az 10 karakter olmalıdır")
      .max(2000, "Mesaj 2000 karakterden uzun olamaz")
      .optional()
      .or(z.literal("").transform(() => undefined)),
    type: z.enum(["info", "success", "warning", "error"]),
    priority: z.enum(["low", "normal", "high", "urgent"]).optional().default("normal"),
    targetType: z.enum(["all", "students", "teachers", "admins"]).default("all"),
    templateId: z
      .number()
      .positive("Şablon seçimi geçersiz")
      .optional()
      .nullable(),
    channels: z
      .object({
        push: z.boolean().default(true),
        email: z.boolean().default(false),
        in_app: z.boolean().default(true),
      })
      .default({
        push: true,
        email: false,
        in_app: true,
      }),
    scheduledAt: z
      .string()
      .optional()
      .transform((value) => {
        const trimmed = value?.trim() ?? "";
        return trimmed.length > 0 ? trimmed : undefined;
      })
      .refine(
        (value) => {
          if (!value) {
            return true;
          }
          return !Number.isNaN(new Date(value).valueOf());
        },
        { message: "Geçerli bir tarih seçin" },
      ),
    status: z.enum(["draft", "scheduled"]).default("draft"),
  })
  .superRefine((values, ctx) => {
    const hasTemplate = Boolean(values.templateId);
    if (!hasTemplate && (!values.title || values.title.trim().length === 0)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Başlık zorunludur",
        path: ["title"],
      });
    }
    if (!hasTemplate && (!values.message || values.message.trim().length === 0)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Mesaj zorunludur",
        path: ["message"],
      });
    }
  });

export type ScheduledNotificationFormSchema = z.infer<typeof scheduledNotificationSchema>;

export const notificationTemplateSchema = z.object({
  name: z
    .string()
    .min(1, "Şablon adı zorunludur")
    .min(3, "Şablon adı en az 3 karakter olmalıdır"),
  slug: z
    .string()
    .regex(/^[a-z0-9-]+$/i, "Slug sadece harf, sayı ve tire içermelidir")
    .max(150)
    .optional()
    .or(z.literal("").transform(() => undefined)),
  channel: z.enum(["email", "push", "sms", "in_app"]),
  subject: z
    .string()
    .max(255, "Konu 255 karakterden uzun olamaz")
    .optional()
    .or(z.literal("").transform(() => undefined)),
  body: z
    .string()
    .min(1, "Şablon içeriği zorunludur")
    .min(10, "Şablon içeriği en az 10 karakter olmalıdır"),
  variables: z.array(z.string()).optional(),
  action_url: z
    .string()
    .url("Geçerli bir URL girin")
    .optional()
    .or(z.literal("").transform(() => undefined)),
  action_text: z
    .string()
    .max(100, "Buton metni 100 karakterden uzun olamaz")
    .optional()
    .or(z.literal("").transform(() => undefined)),
  is_default: z.boolean(),
  status: z.enum(["draft", "published", "archived"]),
});

export type NotificationTemplateFormSchema = z.infer<typeof notificationTemplateSchema>;

