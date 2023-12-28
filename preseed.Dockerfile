# Used to create a web server to host preseed file for remote VM creation
FROM nginx
RUN rm /usr/share/nginx/html/*
COPY preseed.cfg /usr/share/nginx/html
