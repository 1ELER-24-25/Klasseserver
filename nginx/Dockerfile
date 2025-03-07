FROM nginx:alpine

# Remove default nginx configuration
RUN rm -rf /etc/nginx/conf.d/* /etc/nginx/nginx.conf

# Copy our custom configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create necessary directories
RUN mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/run/nginx \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/log/nginx \
    && mkdir -p /etc/nginx/conf.d \
    && touch /var/run/nginx.pid

# Set permissions
RUN chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && chown -R nginx:nginx /etc/nginx/conf.d \
    && chown -R nginx:nginx /var/run/nginx \
    && chown -R nginx:nginx /usr/share/nginx/html \
    && chown -R nginx:nginx /var/run/nginx.pid \
    && chmod -R 755 /var/cache/nginx \
    && chmod -R 755 /var/log/nginx \
    && chmod -R 755 /etc/nginx/conf.d \
    && chmod -R 755 /var/run/nginx \
    && chmod -R 755 /usr/share/nginx/html

USER nginx

CMD ["nginx", "-g", "daemon off;"]
