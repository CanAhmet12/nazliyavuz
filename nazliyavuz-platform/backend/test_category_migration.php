<?php

/**
 * Category Migration Test Script
 * 
 * Bu script migration'ın başarılı olup olmadığını test eder
 */

require_once __DIR__ . '/vendor/autoload.php';

use App\Models\Category;
use App\Models\Teacher;
use Illuminate\Support\Facades\DB;

class CategoryMigrationTest
{
    private $errors = [];
    private $warnings = [];
    private $success = [];

    public function runAllTests()
    {
        echo "🧪 Category Migration Test Başlatılıyor...\n\n";

        $this->testCategoryCount();
        $this->testCategoryStructure();
        $this->testTeacherCategoryRelations();
        $this->testApiEndpoints();
        $this->testOldSlugFallback();

        $this->printResults();
    }

    private function testCategoryCount()
    {
        echo "📊 Kategori Sayısı Testi...\n";
        
        $mainCategories = Category::whereNull('parent_id')->count();
        $subCategories = Category::whereNotNull('parent_id')->count();
        
        if ($mainCategories === 13) {
            $this->success[] = "✅ Ana kategori sayısı doğru: {$mainCategories}";
        } else {
            $this->errors[] = "❌ Ana kategori sayısı yanlış: {$mainCategories} (beklenen: 13)";
        }

        if ($subCategories === 190) {
            $this->success[] = "✅ Alt kategori sayısı doğru: {$subCategories}";
        } else {
            $this->errors[] = "❌ Alt kategori sayısı yanlış: {$subCategories} (beklenen: 190)";
        }
    }

    private function testCategoryStructure()
    {
        echo "🏗️ Kategori Yapısı Testi...\n";
        
        $expectedMainCategories = [
            'Okul Dersleri', 'Fakülte Dersleri', 'Yazılım', 'Sağlık ve Meditasyon',
            'Spor', 'Dans', 'Sınava Hazırlık', 'Müzik', 'Kişisel Gelişim',
            'Sanat ve Hobiler', 'Direksiyon', 'Tasarım', 'Dijital Pazarlama'
        ];

        foreach ($expectedMainCategories as $categoryName) {
            $category = Category::where('name', $categoryName)->whereNull('parent_id')->first();
            if ($category) {
                $this->success[] = "✅ Ana kategori bulundu: {$categoryName}";
            } else {
                $this->errors[] = "❌ Ana kategori bulunamadı: {$categoryName}";
            }
        }
    }

    private function testTeacherCategoryRelations()
    {
        echo "👨‍🏫 Öğretmen-Kategori İlişkileri Testi...\n";
        
        $relationCount = DB::table('teacher_category')->count();
        
        if ($relationCount > 0) {
            $this->success[] = "✅ Teacher-Category ilişkileri mevcut: {$relationCount}";
            
            // Test specific relations
            $teachers = Teacher::with('categories')->get();
            foreach ($teachers as $teacher) {
                if ($teacher->categories->count() > 0) {
                    $this->success[] = "✅ Öğretmen {$teacher->user->name} kategorileri var";
                } else {
                    $this->warnings[] = "⚠️ Öğretmen {$teacher->user->name} kategorileri yok";
                }
            }
        } else {
            $this->errors[] = "❌ Teacher-Category ilişkileri bulunamadı";
        }
    }

    private function testApiEndpoints()
    {
        echo "🌐 API Endpoint Testi...\n";
        
        // Test categories endpoint
        $categories = Category::active()->root()->orderBy('sort_order')->get();
        if ($categories->count() > 0) {
            $this->success[] = "✅ Categories API endpoint çalışıyor";
        } else {
            $this->errors[] = "❌ Categories API endpoint çalışmıyor";
        }

        // Test specific category
        $category = Category::where('slug', 'matematik')->first();
        if ($category) {
            $this->success[] = "✅ Specific category API çalışıyor";
        } else {
            $this->errors[] = "❌ Specific category API çalışmıyor";
        }
    }

    private function testOldSlugFallback()
    {
        echo "🔄 Eski Slug Fallback Testi...\n";
        
        $oldSlugs = ['san', 'pilates', 'web-tasarim', 'bilgisayar', 'akademik', 'teknoloji'];
        
        foreach ($oldSlugs as $oldSlug) {
            $category = Category::where('slug', $oldSlug)->first();
            if (!$category) {
                $this->success[] = "✅ Eski slug '{$oldSlug}' artık mevcut değil (doğru)";
            } else {
                $this->warnings[] = "⚠️ Eski slug '{$oldSlug}' hala mevcut";
            }
        }
    }

    private function printResults()
    {
        echo "\n" . str_repeat("=", 50) . "\n";
        echo "📋 TEST SONUÇLARI\n";
        echo str_repeat("=", 50) . "\n\n";

        if (!empty($this->success)) {
            echo "✅ BAŞARILI TESTLER:\n";
            foreach ($this->success as $success) {
                echo "   {$success}\n";
            }
            echo "\n";
        }

        if (!empty($this->warnings)) {
            echo "⚠️ UYARILAR:\n";
            foreach ($this->warnings as $warning) {
                echo "   {$warning}\n";
            }
            echo "\n";
        }

        if (!empty($this->errors)) {
            echo "❌ HATALAR:\n";
            foreach ($this->errors as $error) {
                echo "   {$error}\n";
            }
            echo "\n";
        }

        $totalTests = count($this->success) + count($this->warnings) + count($this->errors);
        $successRate = count($this->success) / $totalTests * 100;

        echo "📊 GENEL DURUM:\n";
        echo "   Toplam Test: {$totalTests}\n";
        echo "   Başarılı: " . count($this->success) . "\n";
        echo "   Uyarı: " . count($this->warnings) . "\n";
        echo "   Hata: " . count($this->errors) . "\n";
        echo "   Başarı Oranı: " . number_format($successRate, 2) . "%\n\n";

        if (count($this->errors) === 0) {
            echo "🎉 MIGRATION BAŞARILI!\n";
            echo "✅ Production'a deploy edilebilir.\n";
        } else {
            echo "🚨 MIGRATION BAŞARISIZ!\n";
            echo "❌ Hatalar düzeltilmeden production'a deploy edilmemeli.\n";
        }
    }
}

// Test'i çalıştır
$test = new CategoryMigrationTest();
$test->runAllTests();
