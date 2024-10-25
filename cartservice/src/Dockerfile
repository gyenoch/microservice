# https://mcr.microsoft.com/product/dotnet/sdk
FROM mcr.microsoft.com/dotnet/sdk:8.0.100 as builder

WORKDIR /app

COPY cartservice.csproj .

RUN dotnet restore cartservice.csproj \
    -r linux-musl-x64

COPY . .

RUN dotnet publish cartservice.csproj \
    -p:PublishSingleFile=true \
    -r linux-musl-x64 \
    --self-contained true \
    -p:PublishTrimmed=True \
    -p:TrimMode=Full \
    -c release \
    -o /cartservice \
    --no-restore

# https://mcr.microsoft.com/product/dotnet/runtime-deps
FROM mcr.microsoft.com/dotnet/runtime-deps:8.0.0-alpine3.18-amd64

WORKDIR /app

COPY --from=builder /cartservice .

ENV REDIS_ADDR=redis:6379

ENV ASPNETCORE_HTTP_PORTS=7070

EXPOSE 7070

ENTRYPOINT ["/app/cartservice"]
#############################################################

