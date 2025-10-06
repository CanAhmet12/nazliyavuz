<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Category;

class CategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Önce mevcut kategorileri temizle
        Category::truncate();
        
        $categories = [
            // Ana Kategoriler
            [
                'name' => 'Okul Dersleri',
                'slug' => 'okul-dersleri',
                'description' => 'İlkokul, ortaokul ve lise dersleri',
                'icon' => 'school',
                'sort_order' => 1,
                'children' => [
                    ['name' => 'Matematik', 'slug' => 'matematik', 'description' => 'Matematik dersleri'],
                    ['name' => 'Türkçe', 'slug' => 'turkce', 'description' => 'Türkçe dersleri'],
                    ['name' => 'Hayat Bilgisi', 'slug' => 'hayat-bilgisi', 'description' => 'Hayat bilgisi dersleri'],
                    ['name' => 'Fen Bilimleri', 'slug' => 'fen-bilimleri', 'description' => 'Fen bilimleri dersleri'],
                    ['name' => 'Sosyal Bilgiler', 'slug' => 'sosyal-bilgiler', 'description' => 'Sosyal bilgiler dersleri'],
                    ['name' => 'Din Kültürü', 'slug' => 'din-kulturu', 'description' => 'Din kültürü dersleri'],
                    ['name' => 'Görsel Sanatlar', 'slug' => 'gorsel-sanatlar', 'description' => 'Görsel sanatlar dersleri'],
                    ['name' => 'Edebiyat', 'slug' => 'edebiyat', 'description' => 'Edebiyat dersleri'],
                    ['name' => 'Tarih', 'slug' => 'tarih', 'description' => 'Tarih dersleri'],
                    ['name' => 'Coğrafya', 'slug' => 'cografya', 'description' => 'Coğrafya dersleri'],
                    ['name' => 'Fizik', 'slug' => 'fizik', 'description' => 'Fizik dersleri'],
                    ['name' => 'Kimya', 'slug' => 'kimya', 'description' => 'Kimya dersleri'],
                    ['name' => 'Biyoloji', 'slug' => 'biyoloji', 'description' => 'Biyoloji dersleri'],
                    ['name' => 'Mantık', 'slug' => 'mantik', 'description' => 'Mantık dersleri'],
                    ['name' => 'Felsefe', 'slug' => 'felsefe', 'description' => 'Felsefe dersleri'],
                    ['name' => 'Okul Öncesi', 'slug' => 'okul-oncesi', 'description' => 'Okul öncesi eğitim'],
                    ['name' => 'Özel Eğitim', 'slug' => 'ozel-egitim', 'description' => 'Özel eğitim'],
                ]
            ],
            [
                'name' => 'Fakülte Dersleri',
                'slug' => 'fakulte-dersleri',
                'description' => 'Üniversite fakülte dersleri',
                'icon' => 'account_balance',
                'sort_order' => 2,
                'children' => [
                    ['name' => 'Tıp Fak.', 'slug' => 'tip-fak', 'description' => 'Tıp fakültesi dersleri'],
                    ['name' => 'Hukuk Fak.', 'slug' => 'hukuk-fak', 'description' => 'Hukuk fakültesi dersleri'],
                    ['name' => 'Mühendislik Fak.', 'slug' => 'muhendislik-fak', 'description' => 'Mühendislik fakültesi dersleri'],
                    ['name' => 'Mimarlık Fak.', 'slug' => 'mimarlik-fak', 'description' => 'Mimarlık fakültesi dersleri'],
                    ['name' => 'Eğitim Fak.', 'slug' => 'egitim-fak', 'description' => 'Eğitim fakültesi dersleri'],
                    ['name' => 'Sağlık Fak.', 'slug' => 'saglik-fak', 'description' => 'Sağlık fakültesi dersleri'],
                    ['name' => 'Edebiyat Fak.', 'slug' => 'edebiyat-fak', 'description' => 'Edebiyat fakültesi dersleri'],
                    ['name' => 'Fen Fakültesi', 'slug' => 'fen-fakultesi', 'description' => 'Fen fakültesi dersleri'],
                    ['name' => 'Eczacılık Fak.', 'slug' => 'eczacilik-fak', 'description' => 'Eczacılık fakültesi dersleri'],
                    ['name' => 'Diş Hekimliği Fak.', 'slug' => 'dis-hekimligi-fak', 'description' => 'Diş hekimliği fakültesi dersleri'],
                    ['name' => 'İşletme Fak.', 'slug' => 'isletme-fak', 'description' => 'İşletme fakültesi dersleri'],
                    ['name' => 'İletişim Fak.', 'slug' => 'iletisim-fak', 'description' => 'İletişim fakültesi dersleri'],
                    ['name' => 'İlahiyat Fak.', 'slug' => 'ilahiyat-fak', 'description' => 'İlahiyat fakültesi dersleri'],
                    ['name' => 'Hemşirelik Fak.', 'slug' => 'hemsirelik-fak', 'description' => 'Hemşirelik fakültesi dersleri'],
                    ['name' => 'Güzel Sanatlar Fak.', 'slug' => 'guzel-sanatlar-fak', 'description' => 'Güzel sanatlar fakültesi dersleri'],
                    ['name' => 'Turizm Fak.', 'slug' => 'turizm-fak', 'description' => 'Turizm fakültesi dersleri'],
                    ['name' => 'Konservatuar', 'slug' => 'konservatuar', 'description' => 'Konservatuar dersleri'],
                ]
            ],
            [
                'name' => 'Yazılım',
                'slug' => 'yazilim',
                'description' => 'Yazılım geliştirme ve programlama',
                'icon' => 'code',
                'sort_order' => 3,
                'children' => [
                    ['name' => 'Mobil Yazılım', 'slug' => 'mobil-yazilim', 'description' => 'Mobil uygulama geliştirme'],
                    ['name' => 'Web Yazılım', 'slug' => 'web-yazilim', 'description' => 'Web uygulaması geliştirme'],
                    ['name' => 'Robotik Kodlama', 'slug' => 'robotik-kodlama', 'description' => 'Robotik ve kodlama'],
                    ['name' => 'Oyun Geliştirme', 'slug' => 'oyun-gelistirme', 'description' => 'Oyun geliştirme'],
                    ['name' => 'Veri Tabanı', 'slug' => 'veri-tabani', 'description' => 'Veri tabanı yönetimi'],
                    ['name' => 'Yapay Zeka', 'slug' => 'yapay-zeka', 'description' => 'Yapay zeka ve makine öğrenmesi'],
                    ['name' => 'Python', 'slug' => 'python', 'description' => 'Python programlama'],
                    ['name' => 'C#', 'slug' => 'csharp', 'description' => 'C# programlama'],
                    ['name' => 'JavaScript', 'slug' => 'javascript', 'description' => 'JavaScript programlama'],
                    ['name' => 'Java', 'slug' => 'java', 'description' => 'Java programlama'],
                    ['name' => 'Ofis Programları', 'slug' => 'ofis-programlari', 'description' => 'Microsoft Office programları'],
                    ['name' => 'SEO/ASO', 'slug' => 'seo-aso', 'description' => 'SEO ve ASO optimizasyonu'],
                    ['name' => 'PHP', 'slug' => 'php', 'description' => 'PHP programlama'],
                    ['name' => 'Android Geliştirme', 'slug' => 'android-gelistirme', 'description' => 'Android uygulama geliştirme'],
                    ['name' => 'iOS Geliştirme', 'slug' => 'ios-gelistirme', 'description' => 'iOS uygulama geliştirme'],
                    ['name' => 'Flutter', 'slug' => 'flutter', 'description' => 'Flutter geliştirme'],
                    ['name' => 'C++', 'slug' => 'cpp', 'description' => 'C++ programlama'],
                    ['name' => 'React Native', 'slug' => 'react-native', 'description' => 'React Native geliştirme'],
                    ['name' => 'Siber Güvenlik', 'slug' => 'siber-guvenlik', 'description' => 'Siber güvenlik'],
                ]
            ],
            [
                'name' => 'Sağlık ve Meditasyon',
                'slug' => 'saglik-ve-meditasyon',
                'description' => 'Sağlık, meditasyon ve kişisel bakım',
                'icon' => 'health_and_safety',
                'sort_order' => 4,
                'children' => [
                    ['name' => 'Kişisel Koçluk', 'slug' => 'kisisel-kocluk', 'description' => 'Kişisel koçluk'],
                    ['name' => 'Yaşam Koçluğu', 'slug' => 'yasam-koclugu', 'description' => 'Yaşam koçluğu'],
                    ['name' => 'Diyabetik Beslenme', 'slug' => 'diyabetik-beslenme', 'description' => 'Diyabetik beslenme'],
                    ['name' => 'Meditasyon', 'slug' => 'meditasyon', 'description' => 'Meditasyon'],
                    ['name' => 'Estetik Kozmetik', 'slug' => 'estetik-kozmetik', 'description' => 'Estetik ve kozmetik'],
                    ['name' => 'Makyaj', 'slug' => 'makyaj', 'description' => 'Makyaj teknikleri'],
                    ['name' => 'Tırnak Sanatı', 'slug' => 'tirnak-sanati', 'description' => 'Tırnak sanatı'],
                    ['name' => 'Alternatif Tıp', 'slug' => 'alternatif-tip', 'description' => 'Alternatif tıp'],
                    ['name' => 'İlk Yardım', 'slug' => 'ilk-yardim', 'description' => 'İlk yardım'],
                    ['name' => 'Yoga', 'slug' => 'yoga', 'description' => 'Yoga'],
                    ['name' => 'Stil ve Moda', 'slug' => 'stil-ve-moda', 'description' => 'Stil ve moda'],
                    ['name' => 'Aromaterapi', 'slug' => 'aromaterapi', 'description' => 'Aromaterapi'],
                    ['name' => 'Fizyoterapist', 'slug' => 'fizyoterapist', 'description' => 'Fizyoterapi'],
                    ['name' => 'Psikolog', 'slug' => 'psikolog', 'description' => 'Psikoloji'],
                ]
            ],
            [
                'name' => 'Spor',
                'slug' => 'spor',
                'description' => 'Spor ve fiziksel aktiviteler',
                'icon' => 'sports',
                'sort_order' => 5,
                'children' => [
                    ['name' => 'Yüzme', 'slug' => 'yuzme', 'description' => 'Yüzme'],
                    ['name' => 'Futbol', 'slug' => 'futbol', 'description' => 'Futbol'],
                    ['name' => 'Basketbol', 'slug' => 'basketbol', 'description' => 'Basketbol'],
                    ['name' => 'Voleybol', 'slug' => 'voleybol', 'description' => 'Voleybol'],
                    ['name' => 'Tenis', 'slug' => 'tenis', 'description' => 'Tenis'],
                    ['name' => 'Masa Tenisi', 'slug' => 'masa-tenisi', 'description' => 'Masa tenisi'],
                    ['name' => 'Golf', 'slug' => 'golf', 'description' => 'Golf'],
                    ['name' => 'Okçuluk', 'slug' => 'okculuk', 'description' => 'Okçuluk'],
                    ['name' => 'Badminton', 'slug' => 'badminton', 'description' => 'Badminton'],
                    ['name' => 'Vücut Geliştirme', 'slug' => 'vucut-gelistirme', 'description' => 'Vücut geliştirme'],
                    ['name' => 'Kick Boks', 'slug' => 'kick-boks', 'description' => 'Kick boks'],
                    ['name' => 'Karate', 'slug' => 'karate', 'description' => 'Karate'],
                    ['name' => 'Judo', 'slug' => 'judo', 'description' => 'Judo'],
                    ['name' => 'Aikido', 'slug' => 'aikido', 'description' => 'Aikido'],
                    ['name' => 'Güreş', 'slug' => 'gures', 'description' => 'Güreş'],
                    ['name' => 'Boks', 'slug' => 'boks', 'description' => 'Boks'],
                    ['name' => 'Hentbol', 'slug' => 'hentbol', 'description' => 'Hentbol'],
                    ['name' => 'Kayak', 'slug' => 'kayak', 'description' => 'Kayak'],
                    ['name' => 'Snowboard', 'slug' => 'snowboard', 'description' => 'Snowboard'],
                    ['name' => 'Buz Pateni', 'slug' => 'buz-pateni', 'description' => 'Buz pateni'],
                    ['name' => 'Kaykay', 'slug' => 'kaykay', 'description' => 'Kaykay'],
                    ['name' => 'Binicilik', 'slug' => 'binicilik', 'description' => 'Binicilik'],
                    ['name' => 'Dalış', 'slug' => 'dalis', 'description' => 'Dalış'],
                    ['name' => 'Jimnastik', 'slug' => 'jimnastik', 'description' => 'Jimnastik'],
                ]
            ],
            [
                'name' => 'Dans',
                'slug' => 'dans',
                'description' => 'Dans türleri ve koreografi',
                'icon' => 'music_note',
                'sort_order' => 6,
                'children' => [
                    ['name' => 'Bale', 'slug' => 'bale', 'description' => 'Bale'],
                    ['name' => 'Tango', 'slug' => 'tango', 'description' => 'Tango'],
                    ['name' => 'Salsa', 'slug' => 'salsa', 'description' => 'Salsa'],
                    ['name' => 'Samba', 'slug' => 'samba', 'description' => 'Samba'],
                    ['name' => 'Valse', 'slug' => 'valse', 'description' => 'Valse'],
                    ['name' => 'Oryantal', 'slug' => 'oryantal', 'description' => 'Oryantal dans'],
                    ['name' => 'Zeybek', 'slug' => 'zeybek', 'description' => 'Zeybek'],
                    ['name' => 'Hint Dansı', 'slug' => 'hint-dansi', 'description' => 'Hint dansı'],
                    ['name' => 'Break Dans', 'slug' => 'break-dans', 'description' => 'Break dans'],
                    ['name' => 'Koreografi', 'slug' => 'koreografi', 'description' => 'Koreografi'],
                    ['name' => 'Hiphop', 'slug' => 'hiphop', 'description' => 'Hiphop'],
                    ['name' => 'Düğün Dansları', 'slug' => 'dugun-danslari', 'description' => 'Düğün dansları'],
                ]
            ],
            [
                'name' => 'Sınava Hazırlık',
                'slug' => 'sinava-hazirlik',
                'description' => 'Sınav hazırlık kursları',
                'icon' => 'quiz',
                'sort_order' => 7,
                'children' => [
                    ['name' => 'KPSS', 'slug' => 'kpss', 'description' => 'KPSS hazırlık'],
                    ['name' => 'YKS', 'slug' => 'yks', 'description' => 'YKS hazırlık'],
                    ['name' => 'TEOG', 'slug' => 'teog', 'description' => 'TEOG hazırlık'],
                    ['name' => 'LGS', 'slug' => 'lgs', 'description' => 'LGS hazırlık'],
                    ['name' => 'YDS', 'slug' => 'yds', 'description' => 'YDS hazırlık'],
                    ['name' => 'İSG', 'slug' => 'isg', 'description' => 'İSG hazırlık'],
                    ['name' => 'TUS', 'slug' => 'tus', 'description' => 'TUS hazırlık'],
                    ['name' => 'DGS', 'slug' => 'dgs', 'description' => 'DGS hazırlık'],
                    ['name' => 'EUS', 'slug' => 'eus', 'description' => 'EUS hazırlık'],
                    ['name' => 'TYT', 'slug' => 'tyt', 'description' => 'TYT hazırlık'],
                    ['name' => 'AYT', 'slug' => 'ayt', 'description' => 'AYT hazırlık'],
                    ['name' => 'YDT', 'slug' => 'ydt', 'description' => 'YDT hazırlık'],
                    ['name' => 'YÖKDİL', 'slug' => 'yokdil', 'description' => 'YÖKDİL hazırlık'],
                ]
            ],
            [
                'name' => 'Müzik',
                'slug' => 'muzik',
                'description' => 'Müzik enstrümanları ve eğitimi',
                'icon' => 'music_note',
                'sort_order' => 8,
                'children' => [
                    ['name' => 'Gitar', 'slug' => 'gitar', 'description' => 'Gitar'],
                    ['name' => 'Bağlama', 'slug' => 'baglama', 'description' => 'Bağlama'],
                    ['name' => 'Piyano', 'slug' => 'piyano', 'description' => 'Piyano'],
                    ['name' => 'Kemençe', 'slug' => 'kemence', 'description' => 'Kemençe'],
                    ['name' => 'Org', 'slug' => 'org', 'description' => 'Org'],
                    ['name' => 'Klavye', 'slug' => 'klavye', 'description' => 'Klavye'],
                    ['name' => 'Armonika', 'slug' => 'armonika', 'description' => 'Armonika'],
                    ['name' => 'Klarnet', 'slug' => 'klarnet', 'description' => 'Klarnet'],
                    ['name' => 'Ney', 'slug' => 'ney', 'description' => 'Ney'],
                    ['name' => 'Saksafon', 'slug' => 'saksafon', 'description' => 'Saksafon'],
                    ['name' => 'Bateri', 'slug' => 'bateri', 'description' => 'Bateri'],
                    ['name' => 'Flüt', 'slug' => 'flut', 'description' => 'Flüt'],
                    ['name' => 'Darbuka', 'slug' => 'darbuka', 'description' => 'Darbuka'],
                    ['name' => 'Cello', 'slug' => 'cello', 'description' => 'Cello'],
                    ['name' => 'Keman', 'slug' => 'keman', 'description' => 'Keman'],
                    ['name' => 'Ud', 'slug' => 'ud', 'description' => 'Ud'],
                    ['name' => 'Akordeon', 'slug' => 'akordeon', 'description' => 'Akordeon'],
                    ['name' => 'Mandolin', 'slug' => 'mandolin', 'description' => 'Mandolin'],
                    ['name' => 'Çocuk Korosu', 'slug' => 'cocuk-korosu', 'description' => 'Çocuk korosu'],
                    ['name' => 'Koro', 'slug' => 'koro', 'description' => 'Koro'],
                    ['name' => 'Kulak Eğitimi', 'slug' => 'kulak-egitimi', 'description' => 'Kulak eğitimi'],
                ]
            ],
            [
                'name' => 'Kişisel Gelişim',
                'slug' => 'kisisel-gelisim',
                'description' => 'Kişisel ve mesleki gelişim',
                'icon' => 'psychology',
                'sort_order' => 9,
                'children' => [
                    ['name' => 'Eğitim Koçluğu', 'slug' => 'egitim-koclugu', 'description' => 'Eğitim koçluğu'],
                    ['name' => 'Yaşam Koçluğu', 'slug' => 'yasam-koclugu', 'description' => 'Yaşam koçluğu'],
                    ['name' => 'Kariyer Koçluğu', 'slug' => 'kariyer-koclugu', 'description' => 'Kariyer koçluğu'],
                    ['name' => 'Marka Yönetimi', 'slug' => 'marka-yonetimi', 'description' => 'Marka yönetimi'],
                    ['name' => 'Diksiyon', 'slug' => 'diksiyon', 'description' => 'Diksiyon'],
                    ['name' => 'Etkili Konuşma', 'slug' => 'etkili-konusma', 'description' => 'Etkili konuşma'],
                    ['name' => 'Hızlı Okuma', 'slug' => 'hizli-okuma', 'description' => 'Hızlı okuma'],
                    ['name' => 'Ebeveyn Koçluğu', 'slug' => 'ebeveyn-koclugu', 'description' => 'Ebeveyn koçluğu'],
                    ['name' => 'İlişki Koçluğu', 'slug' => 'iliski-koclugu', 'description' => 'İlişki koçluğu'],
                    ['name' => 'Duygusal Zeka', 'slug' => 'duygusal-zeka', 'description' => 'Duygusal zeka'],
                ]
            ],
            [
                'name' => 'Sanat ve Hobiler',
                'slug' => 'sanat-ve-hobiler',
                'description' => 'Sanat ve hobi aktiviteleri',
                'icon' => 'palette',
                'sort_order' => 10,
                'children' => [
                    ['name' => 'Resim', 'slug' => 'resim', 'description' => 'Resim'],
                    ['name' => 'Tiyatro', 'slug' => 'tiyatro', 'description' => 'Tiyatro'],
                    ['name' => 'Oyunculuk', 'slug' => 'oyunculuk', 'description' => 'Oyunculuk'],
                    ['name' => 'Karikatür', 'slug' => 'karikatur', 'description' => 'Karikatür'],
                    ['name' => 'Heykelcilik', 'slug' => 'heykelcilik', 'description' => 'Heykelcilik'],
                    ['name' => 'Aşçılık', 'slug' => 'ascilik', 'description' => 'Aşçılık'],
                    ['name' => 'Fotoğrafçılık', 'slug' => 'fotografcilik', 'description' => 'Fotoğrafçılık'],
                    ['name' => 'Terzi', 'slug' => 'terzi', 'description' => 'Terzilik'],
                    ['name' => 'Moda Tasarımı', 'slug' => 'moda-tasarimi', 'description' => 'Moda tasarımı'],
                    ['name' => 'Drama', 'slug' => 'drama', 'description' => 'Drama'],
                    ['name' => 'Satranç', 'slug' => 'satranc', 'description' => 'Satranç'],
                    ['name' => 'Ebru Sanatı', 'slug' => 'ebru-sanati', 'description' => 'Ebru sanatı'],
                    ['name' => 'Takı Tasarımı', 'slug' => 'taki-tasarimi', 'description' => 'Takı tasarımı'],
                ]
            ],
            [
                'name' => 'Direksiyon',
                'slug' => 'direksiyon',
                'description' => 'Sürücü kursları ve direksiyon eğitimi',
                'icon' => 'drive_eta',
                'sort_order' => 11,
                'children' => [
                    ['name' => 'Direksiyon/Otomobil', 'slug' => 'direksiyon-otomobil', 'description' => 'Otomobil direksiyon'],
                    ['name' => 'Direksiyon/Otobüs', 'slug' => 'direksiyon-otobus', 'description' => 'Otobüs direksiyon'],
                    ['name' => 'Direksiyon/Kamyon', 'slug' => 'direksiyon-kamyon', 'description' => 'Kamyon direksiyon'],
                    ['name' => 'Direksiyon/Motosiklet', 'slug' => 'direksiyon-motosiklet', 'description' => 'Motosiklet direksiyon'],
                ]
            ],
            [
                'name' => 'Tasarım',
                'slug' => 'tasarim',
                'description' => 'Tasarım ve görsel sanatlar',
                'icon' => 'design_services',
                'sort_order' => 12,
                'children' => [
                    ['name' => 'Grafik Tasarım', 'slug' => 'grafik-tasarim', 'description' => 'Grafik tasarım'],
                    ['name' => 'Mimari Tasarım', 'slug' => 'mimari-tasarim', 'description' => 'Mimari tasarım'],
                    ['name' => 'Mühendislik Tasarımı', 'slug' => 'muhendislik-tasarimi', 'description' => 'Mühendislik tasarımı'],
                    ['name' => 'Mobil Tasarım', 'slug' => 'mobil-tasarim', 'description' => 'Mobil tasarım'],
                    ['name' => 'Web Tasarımı', 'slug' => 'web-tasarimi', 'description' => 'Web tasarımı'],
                    ['name' => '3D ve Animasyon', 'slug' => '3d-ve-animasyon', 'description' => '3D ve animasyon'],
                    ['name' => 'Logo Tasarımı', 'slug' => 'logo-tasarimi', 'description' => 'Logo tasarımı'],
                    ['name' => 'Sosyal Medya', 'slug' => 'sosyal-medya', 'description' => 'Sosyal medya tasarımı'],
                    ['name' => 'Video Edit', 'slug' => 'video-edit', 'description' => 'Video edit'],
                    ['name' => 'Photoshop', 'slug' => 'photoshop', 'description' => 'Photoshop'],
                    ['name' => 'UI/UX Tasarım', 'slug' => 'ui-ux-tasarim', 'description' => 'UI/UX tasarım'],
                    ['name' => 'AutoCAD', 'slug' => 'autocad', 'description' => 'AutoCAD'],
                    ['name' => 'Catia', 'slug' => 'catia', 'description' => 'Catia'],
                    ['name' => 'SketchUp', 'slug' => 'sketchup', 'description' => 'SketchUp'],
                    ['name' => 'SolidWorks', 'slug' => 'solidworks', 'description' => 'SolidWorks'],
                    ['name' => 'Revit', 'slug' => 'revit', 'description' => 'Revit'],
                    ['name' => 'Fusion 360', 'slug' => 'fusion-360', 'description' => 'Fusion 360'],
                    ['name' => 'Maya', 'slug' => 'maya', 'description' => 'Maya'],
                    ['name' => 'Illustrator', 'slug' => 'illustrator', 'description' => 'Illustrator'],
                    ['name' => 'SAP2000', 'slug' => 'sap2000', 'description' => 'SAP2000'],
                    ['name' => 'IDECAD', 'slug' => 'idecad', 'description' => 'IDECAD'],
                ]
            ],
            [
                'name' => 'Dijital Pazarlama',
                'slug' => 'dijital-pazarlama',
                'description' => 'Dijital pazarlama ve reklamcılık',
                'icon' => 'campaign',
                'sort_order' => 13,
                'children' => [
                    ['name' => 'SEO', 'slug' => 'seo', 'description' => 'SEO optimizasyonu'],
                    ['name' => 'ASO', 'slug' => 'aso', 'description' => 'ASO optimizasyonu'],
                    ['name' => 'Sosyal Medya Reklamları', 'slug' => 'sosyal-medya-reklamlari', 'description' => 'Sosyal medya reklamları'],
                    ['name' => 'Sanal Asistanlık', 'slug' => 'sanal-asistanlik', 'description' => 'Sanal asistanlık'],
                    ['name' => 'Google Ads', 'slug' => 'google-ads', 'description' => 'Google Ads'],
                    ['name' => 'Kampanya Yönetimi', 'slug' => 'kampanya-yonetimi', 'description' => 'Kampanya yönetimi'],
                ]
            ],
        ];

        foreach ($categories as $categoryData) {
            $children = $categoryData['children'] ?? [];
            unset($categoryData['children']);

            $category = Category::firstOrCreate(
                ['slug' => $categoryData['slug']],
                $categoryData
            );

            foreach ($children as $childData) {
                Category::firstOrCreate(
                    ['slug' => $childData['slug']],
                    [
                        'parent_id' => $category->id,
                        'name' => $childData['name'],
                        'slug' => $childData['slug'],
                        'description' => $childData['description'],
                        'is_active' => true,
                        'sort_order' => 0,
                    ]
                );
            }
        }
    }
}