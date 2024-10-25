FROM golang:1.22.0-alpine as builder

WORKDIR /app

COPY . .

RUN go build -o shippingservice

########################
FROM alpine:3.19.1

WORKDIR /app

COPY --from=builder /app/shippingservice /app/shippingservice

EXPOSE 50051

ENTRYPOINT ["/app/shippingservice"]
