import { useState } from "react";
import toast from "react-hot-toast";
import { Button } from "@/components/ui/button";
import { exportFinanceReport, type FinanceExportType } from "@/lib/api/finance";
import { FileDown, FileSpreadsheet, Loader2 } from "lucide-react";

function buildFilename(prefix: string) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  return `${prefix}-${timestamp}.csv`;
}

async function triggerDownload(blob: Blob, filename: string) {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
}

export function FinanceExportActions() {
  const [isExportingPayments, setIsExportingPayments] = useState(false);
  const [isExportingPayouts, setIsExportingPayouts] = useState(false);

  const handleExport = async (type: FinanceExportType) => {
    const setLoading = type === "payments" ? setIsExportingPayments : setIsExportingPayouts;
    setLoading(true);

    try {
      const blob = await exportFinanceReport(type);
      const filename =
        type === "payments" ? buildFilename("finance-payments") : buildFilename("finance-payouts");

      await triggerDownload(blob, filename);
      toast.success("CSV dosyası indirilmeye başlandı.");
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Dışa aktarma sırasında bir hata oluştu.";
      toast.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="flex flex-wrap items-center gap-3 rounded-2xl border border-slate-800/70 bg-slate-950/70 p-4">
      <div className="flex min-w-[220px] flex-1 flex-col gap-1">
        <p className="text-sm font-semibold text-slate-100">Finans raporları</p>
        <p className="text-xs text-slate-400">
          Gelir ve öğretmen payout verilerini CSV formatında dışa aktarın.
        </p>
      </div>
      <div className="flex flex-wrap gap-2">
        <Button
          variant="secondary"
          className="gap-2"
          disabled={isExportingPayments}
          onClick={() => handleExport("payments")}
        >
          {isExportingPayments ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <FileDown className="h-4 w-4" />
          )}
          Ödeme kaydı (CSV)
        </Button>
        <Button
          variant="outline"
          className="gap-2 border-slate-700 text-slate-200 hover:bg-slate-900/60"
          disabled={isExportingPayouts}
          onClick={() => handleExport("payouts")}
        >
          {isExportingPayouts ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <FileSpreadsheet className="h-4 w-4" />
          )}
          Öğretmen payout (CSV)
        </Button>
      </div>
    </section>
  );
}

