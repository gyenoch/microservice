FROM golang:1.21.3-alpine as builder

WORKDIR /app

COPY . .

RUN go build -o productcatalogservice

####################

FROM alpine:3.18.4

WORKDIR /app

COPY --from=builder /app/productcatalogservice /app/productcatalogservice

COPY products.json .

EXPOSE 3550

ENTRYPOINT ["/app/productcatalogservice"]