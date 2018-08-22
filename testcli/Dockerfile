FROM alpine:latest
RUN apk add --update curl bash
COPY run.sh /usr/bin
ENTRYPOINT ["/usr/bin/run.sh"]
