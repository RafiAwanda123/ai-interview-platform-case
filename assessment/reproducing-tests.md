# Reproducing Backend Test Suite

Panduan ini mendokumentasikan cara menjalankan seluruh test suite RSpec backend secara independen tanpa memodifikasi database development (`rakamin_development`).

## Prasyarat
- Database PostgreSQL khusus test: `rakamin_test`.
- Ruby `3.3.2` (sesuai `api/.ruby-version` dan `Gemfile`) atau Docker container.

## Opsi 1: Menjalankan Langsung di Host (Bila Ruby 3.3.2 Terpasang)
Pastikan PostgreSQL aktif pada host, lalu jalankan:

```bash
cd api
export RAILS_ENV=test
export DB_NAME=rakamin_test
export DB_USERNAME=postgres
export DB_PASSWORD=postgres
export DB_HOST=localhost
export DB_PORT=5432
export SECRET_KEY_BASE=dummy_test_secret_key_base_for_rspec
export GEMINI_API_KEY=dummy_test_gemini_api_key
export GEMINI_LIVE_MODEL=dummy_live
export GEMINI_FLASH_MODEL=dummy_flash
export GEMINI_PRO_MODEL=dummy_pro

bundle install
bundle exec rails db:test:prepare
bundle exec rspec
```

## Opsi 2: Menjalankan Menggunakan Docker Standar
Bila host menggunakan versi Ruby berbeda (misal sistem Ubuntu dengan Ruby 3.2), gunakan isolated docker container:

```bash
# 1. Pastikan container postgres test aktif
docker network create ai-interview-test-net 2>/dev/null || true
docker run -d --name pg-test --network ai-interview-test-net \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=rakamin_test \
  postgres:16 2>/dev/null || true

# 2. Build test runner image (berbasis ruby:3.3.2)
docker build -t ai-interview-test-runner:ruby33 - << 'EOF'
FROM ruby:3.3.2-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential git libpq-dev tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
EOF

# 3. Jalankan rspec
docker run --rm --network ai-interview-test-net \
  -v $(pwd)/api:/app \
  -w /app \
  -e RAILS_ENV=test \
  -e DB_HOST=pg-test \
  -e DB_PORT=5432 \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_NAME=rakamin_test \
  -e SECRET_KEY_BASE=dummy_test_secret_key_base_for_rspec \
  -e GEMINI_API_KEY=dummy_test_gemini_api_key \
  -e GEMINI_LIVE_MODEL=dummy_live \
  -e GEMINI_FLASH_MODEL=dummy_flash \
  -e GEMINI_PRO_MODEL=dummy_pro \
  ai-interview-test-runner:ruby33 bundle exec rspec
```

