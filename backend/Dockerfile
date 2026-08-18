FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini .
COPY migrations migrations
COPY app app
COPY docker-entrypoint.sh docker-entrypoint.sh

RUN chmod +x docker-entrypoint.sh

CMD ["./docker-entrypoint.sh"]
