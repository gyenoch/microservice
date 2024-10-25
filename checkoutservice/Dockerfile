FROM golang:1.21.3-alpine as builder

WORKDIR /app

COPY . .

RUN go build -o checkoutservice

########################
FROM alpine:3.18.4

WORKDIR /app

COPY --from=builder /app/checkoutservice /app/checkoutservice

ENV PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550
ENV SHIPPING_SERVICE_ADDR=shippingservice:50051
ENV PAYMENT_SERVICE_ADDR=paymentservice:50051
ENV EMAIL_SERVICE_ADDR=emailservice:8080
ENV CURRENCY_SERVICE_ADDR=currencyservice:7000
ENV CART_SERVICE_ADDR=cartservice:7070

EXPOSE 5050

ENTRYPOINT ["/app/checkoutservice"]
