FROM php:8.2-fpm-alpine

# Install nginx and required PHP extensions
RUN apk add --no-cache nginx postgresql-dev \
    && docker-php-ext-install pgsql pdo_pgsql

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Create necessary directories
RUN mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/www \
    && mkdir -p /var/run/nginx \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/log/nginx \
    && mkdir -p /etc/nginx/conf.d \
    && touch /var/run/nginx.pid

# Copy web files
COPY www /usr/share/nginx/html/
COPY php /var/www/

# Set permissions
RUN chown -R www-data:www-data /var/www \
    && chown -R www-data:www-data /var/cache/nginx \
    && chown -R www-data:www-data /var/log/nginx \
    && chown -R www-data:www-data /etc/nginx/conf.d \
    && chown -R www-data:www-data /var/run/nginx \
    && chown -R www-data:www-data /usr/share/nginx/html \
    && chown -R www-data:www-data /var/run/nginx.pid

# Configure PHP-FPM
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# Create startup script
RUN echo '#!/bin/sh' > /start.sh \
    && echo 'php-fpm -D' >> /start.sh \
    && echo 'nginx' >> /start.sh \
    && chmod +x /start.sh

CMD ["/start.sh"]
