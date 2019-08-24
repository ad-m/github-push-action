FROM alpine

LABEL "name"="git-push"
LABEL "maintainer"="Adam Dobrawy <git+push@jawnosc.tk>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="cURL for GitHub Actions"
LABEL "com.github.actions.description"="Runs cURL in an Action"
LABEL "com.github.actions.icon"="upload-cloud"
LABEL "com.github.actions.color"="green"

COPY README.md LICENSE start.sh /

RUN apk add --no-cache git

CMD ["/start.sh"]
