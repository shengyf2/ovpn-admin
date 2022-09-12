FROM node:16-alpine3.15 AS frontend-builder
COPY frontend/ /app
RUN cd /app && npm install && npm run build

FROM golang:1.17.3-buster AS backend-builder
RUN export GOPROXY=https://goproxy.cn \        # 解决国内服务器安装go依赖库失败
    && go install github.com/gobuffalo/packr/v2/packr2@latest
COPY --from=frontend-builder /app/static /app/frontend/static
COPY . /app
RUN export GOPROXY=https://goproxy.cn \        # 解决国内服务器安装go依赖库失败
    && cd /app && packr2 && env CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -a -tags netgo -ldflags '-linkmode external -extldflags -static -s -w' -o ovpn-admin && packr2 clean

FROM alpine:3.16
WORKDIR /app
COPY --from=backend-builder /app/ovpn-admin /app
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \  # 设置国内源
    && export GOPROXY=https://goproxy.cn \        # 解决国内服务器安装go依赖库失败
    && apk add --update bash easy-rsa openssl openvpn coreutils  && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && \
    wget https://github.com/pashcovich/openvpn-user/releases/download/v1.0.4/openvpn-user-linux-amd64.tar.gz -O - | tar xz -C /usr/local/bin && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*
