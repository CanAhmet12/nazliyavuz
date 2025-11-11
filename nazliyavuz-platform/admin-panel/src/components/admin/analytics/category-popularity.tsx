type CategoryPopularityProps = {
  data: Array<{ name: string; count: number }>;
};

export function CategoryPopularity({ data }: CategoryPopularityProps) {
  return (
    <div className="space-y-4 rounded-2xl border border-slate-800/80 bg-slate-950/60 p-6">
      <div>
        <h3 className="text-sm font-semibold text-slate-100">
          Popüler Kategoriler
        </h3>
        <p className="text-xs text-slate-500">
          En çok yapılan derslerin kategori bazlı dağılımı
        </p>
      </div>
      <div className="space-y-2 text-sm text-slate-200">
        {data.map((item) => (
          <div
            key={item.name}
            className="flex items-center justify-between rounded-xl border border-slate-800/60 bg-slate-950/70 px-4 py-3"
          >
            <span>{item.name}</span>
            <span className="text-xs text-slate-400">
              {item.count.toLocaleString("tr-TR")} ders
            </span>
          </div>
        ))}
        {!data.length && (
          <p className="text-xs text-slate-500">
            Hiç kategori verisi bulunamadı.
          </p>
        )}
      </div>
    </div>
  );
}

