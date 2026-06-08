FROM nginx:alpine

MAINTAINER Robin Schmid <support@robinski.ch>

RUN curl "https://raw.githubusercontent.com/Robinski07/ps-toolkit/refs/heads/main/toolkit.ps1" -o /usr/share/nginx/html/toolkit.ps1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]