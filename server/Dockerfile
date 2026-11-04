# Production image. Credentials are NOT baked in: pass the service account
# at runtime, e.g. FIREBASE_SERVICE_ACCOUNT_JSON as a secret env var.
#
# Build from the repository root (the server depends on packages/):
#   docker build -f server/Dockerfile -t parchis-server .
#   docker run -p 8080:8080 -e FIREBASE_SERVICE_ACCOUNT_JSON="$(cat server/service_account.json)" parchis-server

FROM dart:3.11.5 AS build
WORKDIR /src

COPY packages/ packages/
COPY server/pubspec.* server/
RUN cd server && dart pub get

COPY server/ server/
WORKDIR /src/server
RUN dart pub global activate dart_frog_cli 1.2.14 \
 && dart pub global run dart_frog_cli:dart_frog build

WORKDIR /src/server/build
RUN dart pub get --offline \
 && dart compile exe bin/server.dart -o bin/server

# Minimal runtime: the AOT binary plus the system libraries it needs.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /src/server/build/bin/server /app/bin/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/bin/server"]
