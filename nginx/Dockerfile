FROM php:8.2-fpm-alpine

# Install required tools and nginx
RUN apk add --no-cache \
    nginx \
    postgresql-dev \
    && docker-php-ext-install pgsql pdo_pgsql

# Configure PHP-FPM to use Unix socket
RUN sed -i 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = www-data/listen.owner = www-data/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/;listen.group = www-data/listen.group = www-data/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' /usr/local/etc/php-fpm.d/www.conf

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Create necessary directories
RUN mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/www/php \
    && mkdir -p /var/run/nginx \
    && mkdir -p /var/log/nginx

# Copy web files and PHP files
COPY www /usr/share/nginx/html/
COPY php /var/www/php/

# Set correct permissions
RUN chown -R www-data:www-data /var/www \
    && chown -R www-data:www-data /usr/share/nginx/html \
    && chown -R www-data:www-data /var/run \
    && chmod -R 755 /var/www \
    && chmod -R 755 /usr/share/nginx/html

# Create startup script
RUN echo '#!/bin/sh' > /start.sh \
    && echo 'php-fpm &' >> /start.sh \
    && echo 'nginx -g "daemon off;"' >> /start.sh \
    && chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
