import { ArrowUpRight, BarChart3, BellRing, Users2 } from "lucide-react";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";

const summaryCards = [
  {
    title: "Aktif Kullanıcılar",
    value: "1.248",
    change: "+12%",
    icon: Users2,
    description: "Son 30 güne göre artış",
    trendColor: "text-emerald-400",
  },
  {
    title: "Tamamlanan Dersler",
    value: "346",
    change: "+8%",
    icon: BarChart3,
    description: "Haftalık bazda tamamlanan ders",
    trendColor: "text-emerald-400",
  },
  {
    title: "Bekleyen Bildirim",
    value: "5",
    change: "Anlık",
    icon: BellRing,
    description: "Gönderim kuyruğundaki bildirimler",
    trendColor: "text-sky-400",
  },
];

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {summaryCards.map((card) => (
          <Card key={card.title} className="relative overflow-hidden p-6">
            <div className="absolute inset-y-0 right-0 w-1/3 rounded-l-full bg-sky-500/5" />
            <div className="relative z-10 flex items-start justify-between">
              <div>
                <CardTitle className="text-sm text-slate-400">
                  {card.title}
                </CardTitle>
                <p className="mt-3 text-3xl font-semibold text-slate-100">
                  {card.value}
                </p>
                <CardDescription className="mt-2 text-xs text-slate-500">
                  {card.description}
                </CardDescription>
              </div>
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-sky-500/10 text-sky-300">
                <card.icon className="h-5 w-5" />
              </div>
            </div>
            <div className="relative z-10 mt-4 flex items-center gap-2 text-xs">
              <span className={card.trendColor}>{card.change}</span>
              <span className="text-slate-500">vs önceki dönem</span>
            </div>
          </Card>
        ))}
      </div>

      <Card className="flex flex-col gap-6 p-6">
        <div className="flex items-center justify-between">
          <div>
            <CardTitle>Gerçek zamanlı aktiviteler</CardTitle>
            <CardDescription>
              Öğretmen ve öğrencilerin sistem üzerindeki önemli aksiyonları
            </CardDescription>
          </div>
          <button className="flex items-center gap-1 text-xs font-medium text-sky-300 hover:text-sky-200">
            Tüm kayıtları görüntüle
            <ArrowUpRight className="h-3 w-3" />
          </button>
        </div>
        <div className="divide-y divide-slate-800 border border-slate-800/60 rounded-xl bg-slate-950/60">
          {activityFeed.map((item) => (
            <div
              key={item.id}
              className="flex items-center justify-between px-5 py-4 text-sm text-slate-300"
            >
              <div className="flex flex-col">
                <span className="font-medium text-slate-100">
                  {item.title}
                </span>
                <span className="text-xs text-slate-500">{item.subtitle}</span>
              </div>
              <span className="text-xs text-slate-500">{item.time}</span>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

const activityFeed = [
  {
    id: 1,
    title: "Yeni öğretmen başvurusu onaylandı",
    subtitle: "Elif Kaya • İngilizce Öğretmeni",
    time: "2 dk önce",
  },
  {
    id: 2,
    title: "Rezervasyon tamamlandı",
    subtitle: "Öğrenci: Ahmet Ç. • Öğretmen: Ayşe T.",
    time: "8 dk önce",
  },
  {
    id: 3,
    title: "Toplu bildirim gönderildi",
    subtitle: "Kampanya: Eylül Erken Kayıt",
    time: "15 dk önce",
  },
  {
    id: 4,
    title: "Canlı ders başlatıldı",
    subtitle: "Öğretmen: John D. • Öğrenci: Melisa K.",
    time: "23 dk önce",
  },
];

