# Atividade 4 — Containerizar a aplicação

Entrega da Atividade 4 da disciplina DevOps na Prática (DCC/UFLA).

**Autor:** Ana Clara Carvalho Nascimento (@anaclaracn)

## O que foi feito

`Dockerfile` multi-stage com base `python:3.12-alpine` + `.dockerignore`. A imagem
final roda como usuário não-root, tem `HEALTHCHECK` em `/health` e encerra em
menos de meio segundo no `docker stop`.

---

## 1. Antes e depois (`docker images`)

A primeira versão (single-stage com `python:3.12-slim`) e a final (multi-stage
com `python:3.12-alpine`), lado a lado:

```
IMAGE                DISK USAGE   CONTENT SIZE
ufla-shop:1.0-slim   280MB        61.1MB          <- antes (slim, single-stage)
ufla-shop:1.0        140MB        31.2MB          <- depois (alpine, multi-stage)
```

A métrica que a correção usa é o `{{.Size}}` do `docker image inspect` (a coluna
"content size" nesta versão do Docker):

| Versão | `{{.Size}}` |
|---|---|
| antes (`slim`) | 61 146 447 bytes (~61 MB) |
| depois (`alpine`) | **31 155 914 bytes (~31 MB)** ✅ (< 150 MB) |

## 2. O que mudou e quanto economizou (`docker history`)

| Mudança | Economia | Onde aparece no `docker history` |
|---|---|---|
| **Base: `slim` (Debian) → `alpine`** | ~100 MB | antes: camadas Debian de 110 MB + 44,6 MB + 4,99 MB; depois: Alpine de 9,31 MB + 2,94 MB + 48,1 MB |
| **Multi-stage (venv no builder)** | ~12 MB | antes: `pip install` deixava pip + cache + `.pyc` (60,1 MB); depois: `COPY /venv` de 47,9 MB |
| **`--no-compile`** | ~10 MB | derrubou o `COPY /venv` de 58,4 MB para 47,9 MB (sem `.pyc`) |
| **`.dockerignore`** | evita lixo | `COPY . .` na 1ª versão trouxe só 98 kB (`.venv`, `.git`, `tests`, `dados/` ficaram fora) |

Total: `DISK USAGE` de **280 MB → 140 MB** (metade), e `{{.Size}}` de **61 MB → 31 MB**.

## 3. Saída dos comandos de verificação

```bash
docker run --rm ufla-shop:1.0 id -u
# 100  (diferente de 0 = não-root)

docker inspect --format '{{.State.Health.Status}}' loja
# healthy

curl -s localhost:8000/health
# {"status":"ok","versao":"1.0.0"}

curl -s localhost:8000/api/produtos | head -c 200
# [{"id":1,"nome":"Caneca DevOps na Prática","descricao":"Cerâmica, 350 ml: 'funciona na minha máquina'","preco":39.9,"estoque":25,...

time docker stop loja
# docker stop loja  0.01s user 0.00s system 3% cpu 0.401 total   (< 2 s)
```

## 4. Por que o `HEALTHCHECK` consulta `/health` e não `/ready`?

`/health` é o probe de *liveness*: responde se o processo está vivo, sem tocar
em banco nem cache. Usar `/ready` seria errado porque, se o PostgreSQL/Redis
caíssem, ele devolveria 503 e o Docker reiniciaria o container à toa — reiniciar
não conserta uma dependência externa fora do ar.
