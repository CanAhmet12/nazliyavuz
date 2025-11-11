type PaymentMethodsProps = {
  data: Array<{ method: string; percentage: number }>;
};

export function PaymentMethods({ data }: PaymentMethodsProps) {
  return (
    <div className="space-y-3 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <h3 className="text-sm font-semibold text-slate-100">
        Ödeme Yöntemi Dağılımı
      </h3>
      <div className="space-y-3">
        {data.map((item) => (
          <div key={item.method}>
            <div className="flex items-center justify-between text-xs text-slate-300">
              <span>{item.method}</span>
              <span>{item.percentage}%</span>
            </div>
            <div className="mt-1 h-2 w-full rounded-full bg-slate-900/80">
              <div
                className="h-full rounded-full bg-gradient-to-r from-sky-500 to-emerald-400"
                style={{ width: `${item.percentage}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

