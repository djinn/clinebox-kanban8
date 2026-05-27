FROM node:22-bookworm-slim AS build

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends git python3 make g++ && rm -rf /var/lib/apt/lists/*

ARG KANBAN_VERSION=v0.1.68
RUN git clone --depth 1 --branch ${KANBAN_VERSION} https://github.com/cline/kanban.git .

RUN npm ci
RUN npm --prefix web-ui ci
RUN npm run web:build
RUN npm run build
RUN npm prune --production || true
RUN rm -rf web-ui/node_modules 2>/dev/null || true

FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system user.email "kanban@clinebox.dev" \
    && git config --system user.name "Cline Kanban"

COPY --from=build /build/dist /kanban/dist
COPY --from=build /build/node_modules /kanban/node_modules
COPY --from=build /build/package.json /kanban/package.json
COPY --from=build /build/web-ui/dist /kanban/dist/web-ui

WORKDIR /kanban

EXPOSE 3484

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3484/api/passcode/status',r=>{process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"

ENTRYPOINT ["node", "dist/cli.js", "--host", "0.0.0.0", "--no-passcode", "--no-open", "--skip-shutdown-cleanup"]
