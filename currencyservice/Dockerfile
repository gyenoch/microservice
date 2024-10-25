FROM node:20.11.1-alpine as base

From base as builder

WORKDIR /app

COPY package*.json /app/

RUN npm install

##################

FROM base

WORKDIR /app

COPY --from=builder /app/node_modules /app/node_modules

COPY . .

ENV PORT=7000

EXPOSE 7000

ENTRYPOINT [ "node", "/app/server.js" ]