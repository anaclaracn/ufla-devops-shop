# ---- estagio 1: build — instala as dependencias num venv ----
FROM python:3.12-alpine AS builder

WORKDIR /build
COPY requirements.txt .
RUN python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir --no-compile -r requirements.txt

# ---- estagio 2: runtime — imagem enxuta, sem pip-cache ----
FROM python:3.12-alpine

# usuario nao-root
RUN addgroup -S app && adduser -S -G app app

WORKDIR /app

# copia so o que a aplicacao precisa
COPY --from=builder /venv /venv
COPY app/ ./app/
COPY static/ ./static/

ENV PATH="/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    SQLITE_PATH=/data/loja.db

# diretorio gravavel para o SQLite (modo autonomo)
RUN mkdir -p /data && chown app:app /data

USER app

EXPOSE 8000

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
