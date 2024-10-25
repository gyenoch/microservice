FROM golang:1.21.3-alpine as builder

WORKDIR /app

COPY . .

RUN go build -o frontend

########################
FROM alpine:3.18.4

WORKDIR /app

COPY --from=builder /app/frontend /app/frontend

COPY ./templates ./templates

COPY ./static ./static

EXPOSE 8080

ENV PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550

ENV CURRENCY_SERVICE_ADDR=currencyservice:7000

ENV CART_SERVICE_ADDR=cartservice:7070

ENV RECOMMENDATION_SERVICE_ADDR=recommendationservice:8080

ENV CHECKOUT_SERVICE_ADDR=checkoutservice:5050

ENV SHIPPING_SERVICE_ADDR=shippingservice:50051

ENV AD_SERVICE_ADDR=adservice:9555

ENTRYPOINT ["/app/frontend"]
