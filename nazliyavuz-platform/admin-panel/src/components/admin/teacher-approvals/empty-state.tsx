import { Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";

type EmptyStateProps = {
  onRefresh: () => void;
  isLoading?: boolean;
};

export function EmptyState({ onRefresh, isLoading }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-slate-800/70 bg-slate-950/60 px-6 py-16 text-center">
      <div className="flex h-14 w-14 items-center justify-center rounded-full bg-sky-500/10 text-sky-300">
        <Sparkles className="h-6 w-6" />
      </div>
      <h3 className="mt-4 text-lg font-semibold text-slate-100">
        Onay bekleyen öğretmen yok
      </h3>
      <p className="mt-2 max-w-md text-sm text-slate-400">
        Tüm öğretmen başvuruları değerlendirilmiş görünüyor. Yeni başvurular
        geldiğinde buradan takip edebilirsiniz.
      </p>
      <Button
        className="mt-6"
        variant="outline"
        onClick={onRefresh}
        disabled={isLoading}
      >
        Listeyi yenile
      </Button>
    </div>
  );
}

