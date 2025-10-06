FROM php:8.2-cli-alpine

# Install system dependencies
RUN apk add --no-cache \
    sqlite \
    sqlite-dev \
    curl \
    git \
    zip \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo \
        pdo_sqlite \
        mbstring \
        zip \
        exif \
        pcntl \
        gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install --optimize-autoloader --no-dev --no-scripts --ignore-platform-reqs

# Copy application files
COPY . .

# Create database directory and file
RUN mkdir -p /var/www/database && touch /var/www/database/database.sqlite

# Set permissions
RUN chmod 777 /var/www/database/database.sqlite

# Generate application key
RUN php artisan key:generate --force || true

# Run migrations and seed
RUN php artisan migrate --force || true
RUN php artisan db:seed --force || true

# Clear caches
RUN php artisan config:clear || true
RUN php artisan cache:clear || true
RUN php artisan route:clear || true
RUN php artisan view:clear || true

# Expose port
EXPOSE 8000

# Start server
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]