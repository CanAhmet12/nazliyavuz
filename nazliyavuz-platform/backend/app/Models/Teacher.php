<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Teacher extends Model
{
    use HasFactory;

    protected $primaryKey = 'user_id';
    protected $keyType = 'int';
    public $incrementing = false;

    protected $fillable = [
        'user_id',
        'bio',
        'education',
        'certifications',
        'price_hour',
        'languages',
        'experience_years',
        'rating_avg',
        'rating_count',
        'online_available',
        'approved_at',
        'approved_by',
    ];

    /**
     * Scope for filtering by category
     */
    public function scopeByCategory($query, $categorySlug)
    {
        return $query->whereHas('categories', function ($q) use ($categorySlug) {
            $q->where('slug', $categorySlug);
        });
    }

    /**
     * Scope for filtering by price range
     */
    public function scopeByPriceRange($query, $minPrice, $maxPrice)
    {
        if ($minPrice) {
            $query->where('price_hour', '>=', $minPrice);
        }
        if ($maxPrice) {
            $query->where('price_hour', '<=', $maxPrice);
        }
        return $query;
    }

    /**
     * Scope for filtering by rating
     */
    public function scopeByMinRating($query, $minRating)
    {
        return $query->where('rating_avg', '>=', $minRating);
    }

    /**
     * Scope for online available teachers
     */
    public function scopeOnlineAvailable($query)
    {
        return $query->where('online_available', true);
    }

    /**
     * Scope for searching teachers
     */
    public function scopeSearch($query, $searchTerm)
    {
        return $query->where(function ($q) use ($searchTerm) {
            $q->where('bio', 'like', "%{$searchTerm}%")
              ->orWhereHas('user', function ($userQuery) use ($searchTerm) {
                  $userQuery->where('name', 'like', "%{$searchTerm}%");
              });
        });
    }

    /**
     * Scope for sorting teachers
     */
    public function scopeSortBy($query, $sortBy, $sortOrder = 'desc')
    {
        switch ($sortBy) {
            case 'price':
                return $query->orderBy('price_hour', $sortOrder);
            case 'rating':
                return $query->orderBy('rating_avg', $sortOrder);
            case 'name':
                return $query->join('users', 'teachers.user_id', '=', 'users.id')
                            ->orderBy('users.name', $sortOrder)
                            ->select('teachers.*');
            default:
                return $query->orderBy('created_at', $sortOrder);
        }
    }

    /**
     * Scope for popular teachers
     */
    public function scopePopular($query, $limit = 10)
    {
        return $query->orderBy('rating_avg', 'desc')
                    ->orderBy('rating_count', 'desc')
                    ->limit($limit);
    }

    /**
     * Scope for trending teachers
     */
    public function scopeTrending($query, $days = 30, $limit = 10)
    {
        return $query->whereHas('reservations', function ($q) use ($days) {
                $q->where('created_at', '>=', now()->subDays($days));
            })
            ->orderBy('rating_avg', 'desc')
            ->limit($limit);
    }

    protected function casts(): array
    {
        return [
            'education' => 'array',
            'certifications' => 'array',
            'languages' => 'array',
            'price_hour' => 'decimal:2',
            'rating_avg' => 'decimal:2',
            'online_available' => 'boolean',
            'is_approved' => 'boolean',
            'approved_at' => 'datetime',
        ];
    }
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the categories for the teacher
     */
    public function categories()
    {
        return $this->belongsToMany(Category::class, 'teacher_category', 'teacher_id', 'category_id')
                    ->withTimestamps();
    }

    /**
     * Get reservations for this teacher
     */
    public function reservations()
    {
        return $this->hasMany(Reservation::class);
    }

    /**
     * Get the availabilities for the teacher
     */
    public function availabilities()
    {
        return $this->hasMany(TeacherAvailability::class);
    }

    /**
     * Get students who favorited this teacher
     */
    public function favoritedBy()
    {
        return $this->belongsToMany(User::class, 'favorites')
                    ->withTimestamps();
    }

    /**
     * Get ratings for this teacher
     */
    public function ratings()
    {
        return $this->hasMany(Rating::class, 'teacher_id', 'user_id');
    }

    /**
     * Get certifications for this teacher
     */
    public function certifications()
    {
        return $this->hasMany(TeacherCertification::class, 'teacher_id', 'user_id');
    }

    /**
     * Calculate and update rating average
     */
    public function updateRating()
    {
        // This would be implemented when we add rating system
        // For now, we'll keep the default values
    }

    /**
     * Get formatted price
     */
    public function getFormattedPriceAttribute()
    {
        return number_format((float) $this->price_hour, 2) . ' TL/saat';
    }

    /**
     * Get short bio (first 100 characters)
     */
    public function getShortBioAttribute()
    {
        return strlen($this->bio) > 100 ? substr($this->bio, 0, 100) . '...' : $this->bio;
    }
}