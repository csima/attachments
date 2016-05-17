FROM alpine
RUN mkdir /go
ENV GOPATH /go
ADD . /go/src/github.com/badkode/attachments_go
RUN apk add --update go git gzip tar bash && \
    go get gopkg.in/redis.v3 && \
    go get github.com/aws/aws-sdk-go/aws && \
    go get github.com/aws/aws-sdk-go/service/s3 && \
    go get github.com/jrallison/go-workers && \
    go get github.com/davecgh/go-spew/spew && \
    go get golang.org/x/oauth2 && \
    go get google.golang.org/api/gmail/v1 && \
    go install github.com/badkode/attachments_go && \
    apk del git go && \
    rm -rf /go/pkg && \
    rm -rf /go/src && \
    rm -rf /var/cache/apk/*

ENTRYPOINT ["/go/bin/attachments_go"]