# Container image of the reference relay (tools/signaling_server.dart) for
# free container hosts (Render, Koyeb, Fly.io, …). Build from the tools/
# folder:  docker build -f signaling/Dockerfile -t insato-signaling .
FROM dart:stable AS build
WORKDIR /app
COPY signaling_server.dart bin/server.dart
RUN printf 'name: insato_signaling\nenvironment:\n  sdk: ^3.5.0\n' > pubspec.yaml \
 && dart pub get \
 && dart compile exe bin/server.dart -o /app/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
