# Atividade 5 — A stack completa

Entrega da Atividade 5 da disciplina DevOps na Prática (DCC/UFLA).

**Autor:** Ana Clara Carvalho Nascimento (@anaclaracn)

## O que foi feito

`compose.yaml` com quatro serviços (PostgreSQL, Redis, API e Nginx), volume
nomeado para os dados do banco, healthchecks e `restart: unless-stopped`. A API
roda no **modo completo** (`banco=postgresql`, `cache=redis`) e a imagem está
publicada no GHCR.

---

## (a) `docker compose ps` — tudo healthy

```
NAME                       IMAGE                                STATUS                    PORTS
ufla-devops-shop-api-1     ghcr.io/anaclaracn/ufla-shop:1.0.0   Up (healthy)              8000/tcp
ufla-devops-shop-banco-1   postgres:16-alpine                   Up (healthy)              5432/tcp
ufla-devops-shop-cache-1   redis:7-alpine                       Up (healthy)              6379/tcp
ufla-devops-shop-nginx-1   nginx:1.27-alpine                    Up                         0.0.0.0:80->80/tcp
```

Só o Nginx publica porta (`80`). API, banco e cache ficam expostos apenas na
rede interna do compose (a API fala com eles pelo nome do serviço).

## (b) Roteiro de persistência (down + up sem `-v`)

```bash
# 1. subiu tudo com --wait
docker compose up -d --wait

# 2. a loja responde via nginx
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/
# 200

# 3. modo completo
curl -s http://localhost/api/info
# {"aplicacao":"ufla-devops-shop","versao":"1.0.0","banco":"postgresql","cache":"redis",...}

# 4. cria um produto
curl -s -X POST http://localhost/api/produtos -H 'Content-Type: application/json' \
  -d '{"nome":"Prova de persistencia","preco":9.9,"estoque":1}'
# {"id":13,"nome":"Prova de persistencia",...}

# 5. derruba TUDO (sem -v, para não apagar o volume)
docker compose down

# 6. sobe de novo
docker compose up -d --wait

# 7. o produto continua lá
curl -s 'http://localhost/api/busca?q=persistencia'
# {"termo":"persistencia","total":1,"resultados":[{"id":13,"nome":"Prova de persistencia",...}]}
```

> Sobre o `curl -I http://localhost` do roteiro: ele devolve **405**, não 200 —
> o `-I` envia HEAD e as rotas do FastAPI são só GET (a resposta traz
> `allow: GET`). É comportamento da própria aplicação; o GET devolve 200 (acima).

O volume nomeado `ufla-devops-shop_pgdata` é o que faz os dados sobreviverem.

## (c) Endereço da imagem no GHCR

```
ghcr.io/anaclaracn/ufla-shop:1.0.0
```

Visibilidade **Public**, para a correção fazer `docker pull` sem credencial.

## (d) Por que `depends_on` sozinho não resolve, e o que o `service_healthy` acrescenta?

`depends_on` apenas ordena o *start*: espera o container subir (o processo ser
iniciado), não que o serviço esteja pronto para aceitar conexões. O PostgreSQL,
por exemplo, ainda leva alguns segundos depois de "iniciado" para aceitar
conexões, então a API tentaria conectar antes e levaria `connection refused`. O
`condition: service_healthy` faz o compose esperar o healthcheck passar
(`pg_isready` no banco, `redis-cli ping` no cache), garantindo que os dois estão
realmente prontos **antes** de subir a API.
