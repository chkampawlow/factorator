FROM php:8.3-cli

WORKDIR /app

RUN docker-php-ext-install mysqli pdo pdo_mysql

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY . /app

RUN composer install --no-dev --optimize-autoloader || true

CMD sh -c "php -S 0.0.0.0:${PORT:-8080} -t php"