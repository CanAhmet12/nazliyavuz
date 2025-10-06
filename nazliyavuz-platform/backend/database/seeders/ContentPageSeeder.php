<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\ContentPage;

class ContentPageSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $pages = [
            [
                'slug' => 'hakkimizda',
                'title' => 'Hakkımızda',
                'content' => '<h2>Nazliyavuz Platform Hakkında</h2>
                <p>Nazliyavuz Platform, öğrenciler ve öğretmenleri buluşturan modern bir eğitim platformudur. Amacımız, kaliteli eğitimi herkese ulaştırmak ve öğrenme sürecini kolaylaştırmaktır.</p>
                
                <h3>Misyonumuz</h3>
                <p>Eğitimde fırsat eşitliği sağlamak ve herkesin kendi hızında öğrenebileceği bir ortam yaratmak.</p>
                
                <h3>Vizyonumuz</h3>
                <p>Türkiye\'nin en güvenilir ve kapsamlı eğitim platformu olmak.</p>
                
                <h3>Değerlerimiz</h3>
                <ul>
                    <li>Kalite</li>
                    <li>Güvenilirlik</li>
                    <li>Şeffaflık</li>
                    <li>İnovasyon</li>
                </ul>',
                'meta_title' => 'Hakkımızda - Nazliyavuz Platform',
                'meta_description' => 'Nazliyavuz Platform hakkında detaylı bilgiler. Misyonumuz, vizyonumuz ve değerlerimiz.',
                'is_active' => true,
                'sort_order' => 1,
            ],
            [
                'slug' => 'sss',
                'title' => 'Sık Sorulan Sorular',
                'content' => '<h2>Sık Sorulan Sorular</h2>
                
                <h3>Platform Nasıl Çalışır?</h3>
                <p>Öğrenciler platform üzerinden öğretmenleri arayabilir, rezervasyon yapabilir ve ders alabilir. Öğretmenler ise profillerini oluşturup öğrencilerle buluşabilir.</p>
                
                <h3>Ödeme Nasıl Yapılır?</h3>
                <p>Şu anda ödeme sistemi geliştirme aşamasındadır. Yakında güvenli ödeme seçenekleri eklenecektir.</p>
                
                <h3>Dersler Nasıl İptal Edilir?</h3>
                <p>Rezervasyonlarınızı "Rezervasyonlarım" bölümünden iptal edebilirsiniz. İptal politikaları öğretmen tarafından belirlenir.</p>
                
                <h3>Öğretmen Nasıl Olunur?</h3>
                <p>Kayıt olurken "Öğretmen" rolünü seçin ve profil bilgilerinizi tamamlayın. Profil onayından sonra öğretmen olarak hizmet verebilirsiniz.</p>
                
                <h3>Teknik Destek</h3>
                <p>Herhangi bir sorunuz için destek@nazliyavuz.com adresinden bize ulaşabilirsiniz.</p>',
                'meta_title' => 'SSS - Nazliyavuz Platform',
                'meta_description' => 'Nazliyavuz Platform hakkında sık sorulan sorular ve cevapları.',
                'is_active' => true,
                'sort_order' => 2,
            ],
            [
                'slug' => 'gizlilik-politikasi',
                'title' => 'Gizlilik Politikası',
                'content' => '<h2>Gizlilik Politikası</h2>
                
                <h3>Kişisel Verilerin Korunması</h3>
                <p>Nazliyavuz Platform olarak, kullanıcılarımızın kişisel verilerinin korunması bizim için önemlidir. Bu politika, kişisel verilerinizin nasıl toplandığını, kullanıldığını ve korunduğunu açıklar.</p>
                
                <h3>Toplanan Veriler</h3>
                <ul>
                    <li>Ad, soyad ve iletişim bilgileri</li>
                    <li>E-posta adresi ve telefon numarası</li>
                    <li>Profil fotoğrafı</li>
                    <li>Eğitim geçmişi ve sertifikalar</li>
                    <li>Platform kullanım verileri</li>
                </ul>
                
                <h3>Verilerin Kullanımı</h3>
                <p>Kişisel verileriniz sadece platform hizmetlerini sunmak, hesabınızı yönetmek ve size daha iyi hizmet vermek için kullanılır.</p>
                
                <h3>Veri Güvenliği</h3>
                <p>Tüm verileriniz SSL şifreleme ile korunur ve güvenli sunucularda saklanır.</p>
                
                <h3>İletişim</h3>
                <p>Gizlilik politikası ile ilgili sorularınız için gizlilik@nazliyavuz.com adresinden bize ulaşabilirsiniz.</p>',
                'meta_title' => 'Gizlilik Politikası - Nazliyavuz Platform',
                'meta_description' => 'Nazliyavuz Platform gizlilik politikası ve kişisel verilerin korunması.',
                'is_active' => true,
                'sort_order' => 3,
            ],
            [
                'slug' => 'kullanim-kosullari',
                'title' => 'Kullanım Koşulları',
                'content' => '<h2>Kullanım Koşulları</h2>
                
                <h3>Genel Koşullar</h3>
                <p>Bu platformu kullanarak aşağıdaki koşulları kabul etmiş olursunuz:</p>
                
                <h3>Kullanıcı Sorumlulukları</h3>
                <ul>
                    <li>Doğru ve güncel bilgiler sağlamak</li>
                    <li>Platform kurallarına uymak</li>
                    <li>Diğer kullanıcılara saygılı davranmak</li>
                    <li>Telif haklarına saygı göstermek</li>
                </ul>
                
                <h3>Yasaklanan Faaliyetler</h3>
                <ul>
                    <li>Sahte bilgi vermek</li>
                    <li>Spam veya zararlı içerik paylaşmak</li>
                    <li>Başkalarının hesaplarını kullanmak</li>
                    <li>Platform güvenliğini tehdit etmek</li>
                </ul>
                
                <h3>Hizmet Değişiklikleri</h3>
                <p>Platform özelliklerini önceden haber vermeksizin değiştirme hakkını saklı tutar.</p>
                
                <h3>İletişim</h3>
                <p>Kullanım koşulları ile ilgili sorularınız için destek@nazliyavuz.com adresinden bize ulaşabilirsiniz.</p>',
                'meta_title' => 'Kullanım Koşulları - Nazliyavuz Platform',
                'meta_description' => 'Nazliyavuz Platform kullanım koşulları ve kuralları.',
                'is_active' => true,
                'sort_order' => 4,
            ],
            [
                'slug' => 'iletisim',
                'title' => 'İletişim',
                'content' => '<h2>İletişim Bilgileri</h2>
                
                <h3>Genel İletişim</h3>
                <p>Bizimle iletişime geçmek için aşağıdaki bilgileri kullanabilirsiniz:</p>
                
                <h3>E-posta Adresleri</h3>
                <ul>
                    <li><strong>Genel Destek:</strong> destek@nazliyavuz.com</li>
                    <li><strong>Teknik Destek:</strong> teknik@nazliyavuz.com</li>
                    <li><strong>İş Birliği:</strong> isbirligi@nazliyavuz.com</li>
                    <li><strong>Basın:</strong> basin@nazliyavuz.com</li>
                </ul>
                
                <h3>Çalışma Saatleri</h3>
                <p>Pazartesi - Cuma: 09:00 - 18:00<br>
                Cumartesi: 10:00 - 16:00<br>
                Pazar: Kapalı</p>
                
                <h3>Sosyal Medya</h3>
                <p>Bizi sosyal medyada takip edin:</p>
                <ul>
                    <li>Twitter: @nazliyavuz</li>
                    <li>Instagram: @nazliyavuz</li>
                    <li>LinkedIn: Nazliyavuz Platform</li>
                </ul>
                
                <h3>Adres</h3>
                <p>Nazliyavuz Platform<br>
                Teknoloji Geliştirme Bölgesi<br>
                İstanbul, Türkiye</p>',
                'meta_title' => 'İletişim - Nazliyavuz Platform',
                'meta_description' => 'Nazliyavuz Platform iletişim bilgileri ve destek kanalları.',
                'is_active' => true,
                'sort_order' => 5,
            ],
        ];

        foreach ($pages as $page) {
            ContentPage::create($page);
        }
    }
}
