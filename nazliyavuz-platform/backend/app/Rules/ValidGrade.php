<?php

namespace App\Rules;

use Illuminate\Contracts\Validation\Rule;

class ValidGrade implements Rule
{
    private const VALID_GRADES = [
        'A+', 'A', 'A-',
        'B+', 'B', 'B-',
        'C+', 'C', 'C-',
        'D+', 'D', 'D-',
        'F'
    ];

    /**
     * Determine if the validation rule passes.
     *
     * @param  string  $attribute
     * @param  mixed  $value
     * @return bool
     */
    public function passes($attribute, $value)
    {
        return in_array(strtoupper($value), self::VALID_GRADES, true);
    }

    /**
     * Get the validation error message.
     *
     * @return string
     */
    public function message()
    {
        return 'Geçersiz not formatı. İzin verilen notlar: ' . implode(', ', self::VALID_GRADES);
    }

    /**
     * Get all valid grades
     *
     * @return array
     */
    public static function getValidGrades(): array
    {
        return self::VALID_GRADES;
    }

    /**
     * Convert grade to numeric value (for average calculation)
     *
     * @param string $grade
     * @return float|null
     */
    public static function gradeToNumeric(string $grade): ?float
    {
        $gradeMap = [
            'A+' => 4.0,
            'A'  => 4.0,
            'A-' => 3.7,
            'B+' => 3.3,
            'B'  => 3.0,
            'B-' => 2.7,
            'C+' => 2.3,
            'C'  => 2.0,
            'C-' => 1.7,
            'D+' => 1.3,
            'D'  => 1.0,
            'D-' => 0.7,
            'F'  => 0.0,
        ];

        return $gradeMap[strtoupper($grade)] ?? null;
    }

    /**
     * Convert numeric grade to letter grade
     *
     * @param float $numeric
     * @return string
     */
    public static function numericToGrade(float $numeric): string
    {
        if ($numeric >= 3.85) return 'A+';
        if ($numeric >= 3.50) return 'A';
        if ($numeric >= 3.15) return 'A-';
        if ($numeric >= 2.85) return 'B+';
        if ($numeric >= 2.50) return 'B';
        if ($numeric >= 2.15) return 'B-';
        if ($numeric >= 1.85) return 'C+';
        if ($numeric >= 1.50) return 'C';
        if ($numeric >= 1.15) return 'C-';
        if ($numeric >= 0.85) return 'D+';
        if ($numeric >= 0.50) return 'D';
        if ($numeric >= 0.35) return 'D-';
        return 'F';
    }
}

