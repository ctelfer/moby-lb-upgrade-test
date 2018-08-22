FROM golang:1.10 as builder
WORKDIR /go/src/github.com/docker/
RUN go get -d github.com/docker/swarmkit
WORKDIR /go/src/github.com/docker/swarmkit
RUN go build -tags netgo -ldflags "-linkmode external -extldflags -static" -a -o ./bin/swarmctl ./cmd/swarmctl

FROM alpine:latest
COPY --from=builder /go/src/github.com/docker/swarmkit/bin/swarmctl /usr/bin/swarmctl
ENTRYPOINT ["/usr/bin/swarmctl"]
