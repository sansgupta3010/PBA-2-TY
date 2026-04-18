# ──────────────────────────────────────────────────────────────
#  ClassSense AI — Teacher Dashboard
#  Docker Image: nginx:alpine (lightweight, production-grade)
#  Serves all 4 HTML pages as a static web app
# ──────────────────────────────────────────────────────────────

FROM nginx:1.25-alpine

LABEL maintainer="ClassSense AI DevOps <devops@classsense.ai>"
LABEL description="ClassSense AI — AI-powered Teacher Dashboard for online classes"
LABEL version="1.0.0"

# Remove default nginx placeholder
RUN rm -rf /usr/share/nginx/html/*

# Copy all pages into nginx web root
COPY home.html          /usr/share/nginx/html/home.html
COPY about.html         /usr/share/nginx/html/about.html
COPY teacher.html       /usr/share/nginx/html/teacher.html
COPY index.html         /usr/share/nginx/html/index.html

# Custom nginx config
RUN printf '\
server {\n\
    listen 80;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index home.html;\n\
\n\
    # Serve HTML with no-cache headers so updates reflect immediately\n\
    location ~* \\.html$ {\n\
        add_header Cache-Control "no-cache, must-revalidate";\n\
        add_header X-Frame-Options "SAMEORIGIN";\n\
        add_header X-Content-Type-Options "nosniff";\n\
        add_header X-XSS-Protection "1; mode=block";\n\
        try_files $uri $uri/ =404;\n\
    }\n\
\n\
    # Health-check endpoint for Jenkins / load balancers\n\
    location /health {\n\
        return 200 '"'"'{"status":"ok","app":"classsense-ai","version":"1.0.0"}'"'"';\n\
        add_header Content-Type application/json;\n\
    }\n\
\n\
    # Gzip compression for faster loads\n\
    gzip on;\n\
    gzip_types text/html text/css application/javascript;\n\
\n\
    error_page 404 /home.html;\n\
}\n' > /etc/nginx/conf.d/default.conf

# Expose HTTP
EXPOSE 80

# Docker-native health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
