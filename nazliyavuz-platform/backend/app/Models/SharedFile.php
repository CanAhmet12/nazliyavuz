<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SharedFile extends Model
{
    use HasFactory;

    protected $fillable = [
        'teacher_id',
        'student_id',
        'name',
        'file_path',
        'file_size',
        'mime_type',
        'category',
        'description',
        'shared_with',
    ];

    protected function casts(): array
    {
        return [
            'shared_with' => 'array',
        ];
    }

    /**
     * Get the teacher who shared the file
     */
    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    /**
     * Get the student who shared the file
     */
    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    /**
     * Get formatted file size
     */
    public function getFormattedSizeAttribute()
    {
        $bytes = $this->file_size;
        $units = ['B', 'KB', 'MB', 'GB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, 2) . ' ' . $units[$i];
    }

    /**
     * Get file extension
     */
    public function getExtensionAttribute()
    {
        return pathinfo($this->name, PATHINFO_EXTENSION);
    }

    /**
     * Check if file is image
     */
    public function getIsImageAttribute()
    {
        $imageTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        return in_array($this->mime_type, $imageTypes);
    }

    /**
     * Check if file is document
     */
    public function getIsDocumentAttribute()
    {
        $documentTypes = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'text/plain',
        ];
        return in_array($this->mime_type, $documentTypes);
    }
}