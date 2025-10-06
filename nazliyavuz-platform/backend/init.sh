#!/bin/sh

echo "🚀 Starting Nazliyavuz Backend Initialization..."

# Create database directory if it doesn't exist
mkdir -p /var/www/database

# Run migrations
echo "📊 Running database migrations..."
php artisan migrate --force

# Run seeders to create sample data
echo "🌱 Seeding database with sample data..."
php artisan db:seed --force

# Clear and cache config
echo "⚡ Optimizing application..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Start the server
echo "🌟 Starting Laravel server..."
php artisan serve --host=0.0.0.0 --port=8000
