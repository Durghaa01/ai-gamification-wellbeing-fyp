FROM ghcr.io/cirruslabs/flutter:stable as build

WORKDIR /app

# Pre-cache dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter config --enable-web && flutter pub get

# Copy the rest of the Flutter sources
COPY . .
RUN flutter pub get && \
    flutter build web --release \
      --dart-define=APP_ENV=production \
      --dart-define=JOURNAL_API_BASE=http://api:8000 \
      --dart-define=USE_REMOTE_BACKEND=true

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
