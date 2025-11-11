"use client";
/* eslint-disable react-hooks/set-state-in-effect */

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { Loader2, RefreshCw } from "lucide-react";
import { useNotificationIntegrationStatus, notificationIntegrationStatusQueryKey } from "@/hooks/use-notification-integrations";
import { type NotificationIntegrationUpdatePayload, updateNotificationIntegrations } from "@/lib/api/admin-notifications";
import { useMutationToast } from "@/hooks/use-mutation-toast";
import { useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

type EmailFormState = {
  driver: string;
  host: string;
  port: string;
  username: string;
  encryption: string;
  fromAddress: string;
  fromName: string;
};

type PushFormState = {
  serverKey: string;
  senderId: string;
  serverKeyTouched: boolean;
};

type SmsFormState = {
  provider: "twilio" | "mock";
  twilioAccountSid: string;
  twilioAuthToken: string;
  twilioAuthTokenTouched: boolean;
  twilioFrom: string;
};

const defaultEmailState: EmailFormState = {
  driver: "smtp",
  host: "",
  port: "587",
  username: "",
  encryption: "tls",
  fromAddress: "",
  fromName: "",
};

const defaultPushState: PushFormState = {
  serverKey: "",
  senderId: "",
  serverKeyTouched: false,
};

const defaultSmsState: SmsFormState = {
  provider: "mock",
  twilioAccountSid: "",
  twilioAuthToken: "",
  twilioAuthTokenTouched: false,
  twilioFrom: "",
};

export function NotificationIntegrationsCard() {
  const queryClient = useQueryClient();
  const { data: status, isLoading, refetch, isRefetching } = useNotificationIntegrationStatus();

  const [emailForm, setEmailForm] = useState<EmailFormState>(defaultEmailState);
  const [emailPassword, setEmailPassword] = useState("");
  const [emailPasswordTouched, setEmailPasswordTouched] = useState(false);

  const [pushForm, setPushForm] = useState<PushFormState>(defaultPushState);
  const [smsForm, setSmsForm] = useState<SmsFormState>(defaultSmsState);

  useEffect(() => {
    if (!status) {
      return;
    }

    setEmailForm({
      driver: status.email.details.driver ?? "smtp",
      host: status.email.details.host ?? "",
      port: status.email.details.port ?? "",
      username: status.email.details.username ?? "",
      encryption: status.email.details.encryption ?? "tls",
      fromAddress: status.email.details.from_address ?? "",
      fromName: status.email.details.from_name ?? "",
    });
    setEmailPassword("");
    setEmailPasswordTouched(false);

    setPushForm({
      serverKey: "",
      senderId: status.push.details.sender_id ?? "",
      serverKeyTouched: false,
    });

    setSmsForm({
      provider: (status.sms.provider as SmsFormState["provider"]) ?? "mock",
      twilioAccountSid: status.sms.details.twilio_account_sid ?? "",
      twilioAuthToken: "",
      twilioAuthTokenTouched: false,
      twilioFrom: status.sms.details.twilio_from ?? "",
    });
  }, [status]);

  const updateMutation = useMutationToast(updateNotificationIntegrations, {
    successMessage: "Entegrasyon ayarları güncellendi.",
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: notificationIntegrationStatusQueryKey });
      setEmailPassword("");
      setEmailPasswordTouched(false);
      setPushForm((prev) => ({ ...prev, serverKey: "", serverKeyTouched: false }));
      setSmsForm((prev) => ({ ...prev, twilioAuthToken: "", twilioAuthTokenTouched: false }));
    },
  });

  const emailMissingList = useMemo(() => status?.email.missing ?? [], [status]);
  const pushMissingList = useMemo(() => status?.push.missing ?? [], [status]);
  const smsMissingList = useMemo(() => status?.sms.missing ?? [], [status]);

  const handleEmailSubmit = () => {
    const payload: NotificationIntegrationUpdatePayload = {
      email: {
        driver: emailForm.driver,
        host: emailForm.host,
        port: emailForm.port,
        username: emailForm.username,
        encryption: emailForm.encryption,
        from_address: emailForm.fromAddress,
        from_name: emailForm.fromName,
      },
    };

    if (emailPasswordTouched) {
      payload.email = payload.email ?? {};
      payload.email.password = emailPassword;
    }

    updateMutation.mutate(payload);
  };

  const handlePushSubmit = () => {
    const payload: NotificationIntegrationUpdatePayload = {
      push: {
        sender_id: pushForm.senderId,
      },
    };

    if (pushForm.serverKeyTouched) {
      payload.push = payload.push ?? {};
      payload.push.server_key = pushForm.serverKey;
    }

    updateMutation.mutate(payload);
  };

  const handleSmsSubmit = () => {
    const payload: NotificationIntegrationUpdatePayload = {
      sms: {
        provider: smsForm.provider,
        twilio_account_sid: smsForm.twilioAccountSid,
        twilio_from: smsForm.twilioFrom,
      },
    };

    if (smsForm.twilioAuthTokenTouched) {
      payload.sms = payload.sms ?? {};
      payload.sms.twilio_auth_token = smsForm.twilioAuthToken;
    }

    updateMutation.mutate(payload);
  };

  const isSaving = updateMutation.isPending;

  return (
    <section className="space-y-5 rounded-2xl border border-slate-800/70 bg-slate-950/60 p-5">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold text-slate-100">Bildirim Servis Ayarları</h3>
          <p className="text-xs text-slate-400">
            SMTP, push ve SMS servislerini yapılandırarak test gönderimi yapabilirsiniz.
          </p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          className="text-xs text-slate-300 hover:text-slate-100"
          onClick={() => refetch()}
          disabled={isLoading || isRefetching || isSaving}
        >
          {isRefetching ? <Loader2 className="mr-2 h-3.5 w-3.5 animate-spin" /> : <RefreshCw className="mr-2 h-3.5 w-3.5" />}
          Yenile
        </Button>
      </header>

      {isLoading || !status ? (
        <div className="space-y-4">
          <Skeleton className="h-28 w-full" />
          <Skeleton className="h-8 w-full" />
        </div>
      ) : (
        <>
          <div className="grid gap-3 md:grid-cols-3">
            <IntegrationStatusPill
              title="SMTP"
              configured={status.email.configured}
              missing={emailMissingList}
              description="E-posta gönderimi"
            />
            <IntegrationStatusPill
              title="Push"
              configured={status.push.configured}
              missing={pushMissingList}
              description="FCM sunucu anahtarı"
            />
            <IntegrationStatusPill
              title="SMS"
              configured={status.sms.configured}
              missing={smsMissingList}
              description={status.sms.provider === "mock" ? "Mock mod" : `Sağlayıcı: ${status.sms.provider}`}
            />
          </div>

          <div className="grid gap-5 lg:grid-cols-3">
            <div className="space-y-4 rounded-2xl border border-slate-800/60 bg-slate-950/70 p-4">
              <div className="flex items-center justify-between">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">SMTP Ayarları</p>
                <Badge variant={status.email.configured ? "success" : "destructive"} className="text-[10px] uppercase">
                  {status.email.configured ? "Aktif" : "Pasif"}
                </Badge>
              </div>
              <div className="space-y-3 text-xs text-slate-300">
                <Field label="Mail driver">
                  <Input
                    value={emailForm.driver}
                    onChange={(event) => setEmailForm((prev) => ({ ...prev, driver: event.target.value }))}
                    placeholder="smtp"
                  />
                </Field>
                <Field label="Host">
                  <Input
                    value={emailForm.host}
                    onChange={(event) => setEmailForm((prev) => ({ ...prev, host: event.target.value }))}
                    placeholder="smtp.gmail.com"
                  />
                </Field>
                <div className="grid grid-cols-2 gap-3">
                  <Field label="Port">
                    <Input
                      value={emailForm.port}
                      onChange={(event) => setEmailForm((prev) => ({ ...prev, port: event.target.value }))}
                      placeholder="587"
                    />
                  </Field>
                  <Field label="Encryption">
                    <Input
                      value={emailForm.encryption}
                      onChange={(event) => setEmailForm((prev) => ({ ...prev, encryption: event.target.value }))}
                      placeholder="tls/ssl"
                    />
                  </Field>
                </div>
                <Field label="Kullanıcı adı">
                  <Input
                    value={emailForm.username}
                    onChange={(event) => setEmailForm((prev) => ({ ...prev, username: event.target.value }))}
                    placeholder="SMTP kullanıcı adı"
                  />
                </Field>
                <Field label="Şifre" hint={status.email.details.password_set ? "Mevcut şifreyi değiştirmek için yeni değer girin." : undefined}>
                  <Input
                    type="password"
                    value={emailPassword}
                    onChange={(event) => {
                      setEmailPassword(event.target.value);
                      setEmailPasswordTouched(true);
                    }}
                    placeholder={status.email.details.password_set ? "Yeni SMTP şifresi" : "SMTP şifresi"}
                  />
                </Field>
                <div className="grid grid-cols-2 gap-3">
                  <Field label="Gönderici e-postası">
                    <Input
                      value={emailForm.fromAddress}
                      onChange={(event) => setEmailForm((prev) => ({ ...prev, fromAddress: event.target.value }))}
                      placeholder="noreply@example.com"
                    />
                  </Field>
                  <Field label="Gönderici adı">
                    <Input
                      value={emailForm.fromName}
                      onChange={(event) => setEmailForm((prev) => ({ ...prev, fromName: event.target.value }))}
                      placeholder="Nazliyavuz Platform"
                    />
                  </Field>
                </div>
              </div>
              <Button onClick={handleEmailSubmit} disabled={isSaving} className="w-full">
                {isSaving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                Kaydet
              </Button>
            </div>

            <div className="space-y-4 rounded-2xl border border-slate-800/60 bg-slate-950/70 p-4">
              <div className="flex items-center justify-between">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">Push Bildirim</p>
                <Badge variant={status.push.configured ? "success" : "destructive"} className="text-[10px] uppercase">
                  {status.push.configured ? "Aktif" : "Pasif"}
                </Badge>
              </div>
              <div className="space-y-3 text-xs text-slate-300">
                <Field label="FCM server key" hint={status.push.details.server_key_set ? "Yeni değer girerseniz anahtar güncellenir." : undefined}>
                  <Input
                    value={pushForm.serverKey}
                    onChange={(event) =>
                      setPushForm((prev) => ({
                        ...prev,
                        serverKey: event.target.value,
                        serverKeyTouched: true,
                      }))
                    }
                    placeholder={status.push.details.server_key_set ? "Yeni FCM server key" : "FCM server key"}
                  />
                </Field>
                <Field label="Sender ID">
                  <Input
                    value={pushForm.senderId}
                    onChange={(event) => setPushForm((prev) => ({ ...prev, senderId: event.target.value }))}
                    placeholder="Gönderici ID"
                  />
                </Field>
              </div>
              <Button onClick={handlePushSubmit} disabled={isSaving} className="w-full">
                {isSaving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                Kaydet
              </Button>
            </div>

            <div className="space-y-4 rounded-2xl border border-slate-800/60 bg-slate-950/70 p-4">
              <div className="flex items-center justify-between">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">SMS Servisi</p>
                <Badge variant={status.sms.configured ? "success" : "destructive"} className="text-[10px] uppercase">
                  {status.sms.configured ? "Aktif" : "Pasif"}
                </Badge>
              </div>
              <div className="space-y-3 text-xs text-slate-300">
                <label className="space-y-1">
                  <span className="block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                    Sağlayıcı
                  </span>
                  <select
                    className="w-full rounded-lg border border-slate-800 bg-slate-950 px-3 py-2 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
                    value={smsForm.provider}
                    onChange={(event) =>
                      setSmsForm((prev) => ({
                        ...prev,
                        provider: event.target.value as SmsFormState["provider"],
                      }))
                    }
                  >
                    <option value="twilio">Twilio</option>
                    <option value="mock">Mock (aktif değil)</option>
                  </select>
                </label>
                {smsForm.provider === "twilio" ? (
                  <div className="space-y-3">
                    <Field label="Twilio Account SID">
                      <Input
                        value={smsForm.twilioAccountSid}
                        onChange={(event) =>
                          setSmsForm((prev) => ({ ...prev, twilioAccountSid: event.target.value }))
                        }
                        placeholder="ACxxxxxxxx"
                      />
                    </Field>
                    <Field
                      label="Auth token"
                      hint={
                        status.sms.details.twilio_auth_token_set
                          ? "Yeni auth token girerseniz mevcut token güncellenir."
                          : undefined
                      }
                    >
                      <Input
                        type="password"
                        value={smsForm.twilioAuthToken}
                        onChange={(event) =>
                          setSmsForm((prev) => ({
                            ...prev,
                            twilioAuthToken: event.target.value,
                            twilioAuthTokenTouched: true,
                          }))
                        }
                        placeholder="Twilio Auth Token"
                      />
                    </Field>
                    <Field label="Gönderici numarası" hint="Numarayı uluslararası formatta girin (örn. +905321234567).">
                      <Input
                        value={smsForm.twilioFrom}
                        onChange={(event) => setSmsForm((prev) => ({ ...prev, twilioFrom: event.target.value }))}
                        placeholder="+90..."
                      />
                    </Field>
                  </div>
                ) : (
                  <p className="text-[11px] text-slate-500">
                    Mock modunda SMS gönderimi yapılmaz. Twilio bilgilerini tanımlayarak gerçek gönderim yapabilirsiniz.
                  </p>
                )}
              </div>
              <Button onClick={handleSmsSubmit} disabled={isSaving} className="w-full">
                {isSaving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                Kaydet
              </Button>
            </div>
          </div>
        </>
      )}
    </section>
  );
}

type IntegrationStatusPillProps = {
  title: string;
  configured: boolean;
  missing: string[];
  description: string;
};

function IntegrationStatusPill({ title, configured, missing, description }: IntegrationStatusPillProps) {
  return (
    <div className="rounded-2xl border border-slate-800/60 bg-slate-950/70 p-3">
      <div className="flex items-center justify-between">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">{title}</p>
        <span
          className={cn(
            "rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase",
            configured ? "bg-emerald-500/10 text-emerald-300" : "bg-amber-500/10 text-amber-300",
          )}
        >
          {configured ? "Aktif" : "Eksik"}
        </span>
      </div>
      <p className="mt-2 text-[11px] text-slate-500">{description}</p>
      {missing.length ? (
        <p className="mt-2 text-[11px] text-amber-300">
          Eksik alanlar:{" "}
          {missing
            .map((item) => item.replace(/_/g, " "))
            .join(", ")
            .toLocaleUpperCase("tr-TR")}
        </p>
      ) : null}
    </div>
  );
}

type FieldProps = {
  label: string;
  children: ReactNode;
  hint?: string;
};

function Field({ label, children, hint }: FieldProps) {
  return (
    <label className="flex flex-col space-y-1 text-xs text-slate-300">
      <span className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">{label}</span>
      {children}
      {hint ? <span className="text-[11px] text-slate-500">{hint}</span> : null}
    </label>
  );
}

