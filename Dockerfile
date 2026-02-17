FROM nginx:alpine

# remove default nginx site
RUN rm -rf /usr/share/nginx/html/*

# copy only dist content into nginx html folder
COPY dist/ /usr/share/nginx/html

# copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
