FROM node:20.11.1-alpine as base

FROM base as builder

WORKDIR /app

COPY package*.json /app/

RUN npm install

##################

FROM base

WORKDIR /app

COPY --from=builder /app/node_modules /app/node_modules

COPY . .

ENV PORT=50051

EXPOSE 50051

ENTRYPOINT [ "node", "index.js" ]