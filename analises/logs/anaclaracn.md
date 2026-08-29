# Analise de access.log -- Ana Clara Carvalho Nascimento (@anaclaracn)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
awk '{total++} $9 ~ /^4/ {c4++} $9 ~ /^5/ {c5++} END {printf "total=%d 4xx=%d (%.2f%%) 5xx=%d (%.2f%%)\n", total, c4, 100*c4/total, c5, 100*c5/total}' dados/access.log
```

```
total=516866 4xx=6162 (1.19%) 5xx=11749 (2.27%)
```

**Leitura:** O log tem 516.866 requisições. As falhas de cliente (4xx) somam 6.162 (1,19%) e as de servidor (5xx) 11.749 (2,27%), juntas somam 3,46% do total. Os erros 5xx superam os 4xx quase em dobro, o que aponta para um problema do lado do servidor, não de requisições mal formadas. A contagem foi feita pelo campo `$9` (status), evitando o falso positivo do "500" que aparece no campo `$10` (tamanho da resposta).

## 2. Os 10 IPs mais frequentes

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
```

```
  88400 203.0.113.47
   1788 192.0.2.245
   1772 192.0.2.171
   1771 192.0.2.81
   1771 192.0.2.225
   1771 192.0.2.16
   1767 192.0.2.138
   1762 192.0.2.222
   1757 192.0.2.45
   1753 192.0.2.166
```

**Investigação do IP `203.0.113.47` (o suspeito):**

```bash
awk '$1 == "203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn
awk '$1 == "203.0.113.47"' dados/access.log | cut -d'"' -f6 | sort | uniq -c | sort -rn
awk '$1 == "203.0.113.47" {print $9}' dados/access.log | sort | uniq -c | sort -rn
awk '$1 == "203.0.113.47" {print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2 -n
```

```
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone

  88400 curl/8.5.0

  81500 200
   6900 503

  30940 22
  57460 23
```

**Leitura:** O IP `203.0.113.47` domina com 88.400 requisições (**17,1% de todo o log**) enquanto o segundo colocado tem apenas 1.788. Ele é claramente um bot feito para derrubar o endpoint, e não um usuário real, pois o user-agent é `curl/8.5.0` (linha de comando, não navegador), bate repetidamente em apenas 4 URLs de busca (`mochila`, `tenis`, `camiseta`, `fone`), e dispara num ritmo artificial concentrado entre 22h e 23h (30.940 + 57.460). Outro fato importante, ele é o **único** IP que recebe `503` no log inteiro (6.900 ocorrências), todas no `/api/busca`, ou seja, essa rajada de requisições automatizadas está sobrecarregando o endpoint e o levando à exaustão. Os demais IPs do top 10 (faixa `192.0.2.x`) têm tráfego humano e variado (~1.700 cada), sem nada de anômalo.

## 3. O endpoint quebrado

**Primeiro, qual caminho concentra mais erros `500`:**

```bash
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head
```

```
  3620 /api/relatorio/gerar
   228 /
   167 /api/produtos
   160 /produtos
   150 /produtos/detalhe
   117 /static/app.css
   105 /static/app.js
    92 /api/carrinho
    63 /api/busca
    44 /favicon.ico
```

O que mais gera é o `/api/relatorio/gerar`. **Agora, esse caminho quebra sempre ou só às vezes:**

```bash
awk '$7 == "/api/relatorio/gerar" {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```
   6780 200
   3620 500
```

```bash
awk '$7 == "/api/relatorio/gerar" && $9 == 500' dados/access.log | wc -l
awk '$7 == "/api/relatorio/gerar" && $9 == 500' dados/access.log | wc -l | awk '{printf "%.1f%% dos 500 totais\n", 100*$1/11749}'
```

```
3620
30.8% dos 500 totais
```

**Leitura:** O caminho `/api/relatorio/gerar` é o maior gerador de erro `500`, com 3.620 falhas (**30,8% de todos os 500 do log**). Ele **não quebra sempre**, das 10.400 requisições que recebeu, 6.780 retornaram `200` e 3.620 retornaram `500`, uma taxa de falha de ~34,8%. Isso sugere uma falha **intermitente e dependente de carga ou de dados de entrada** (ex.: o relatório trava quando a query é pesada ou quando algum parâmetro específico é passado), e não um endpoint completamente fora do ar, pois se fosse quebra total, veríamos ~100% de `500`.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2 -n
```

```
  3262 00
  1967 01
  1810 02
  1471 03
  1498 04
  1844 05
  3904 06
  9759 07
 19519 08
 27621 09
 30869 10
 32526 11
 31895 12
 29952 13
 31225 14
 32529 15
 30886 16
 28575 17
 25996 18
 22807 19
 18860 20
 15577 21
 43979 22
 68535 23
```

**Leitura:** O pico absoluto é às **23h**, com 68.535 requisições, seguido das 22h (43.979). Porém esse pico é quase todo artificial, como vimos na pergunta 2, o bot `203.0.113.47` disparou 57.460 requisições às 23h e 30.940 às 22h. Descontando o bot, o tráfego real é bem mais uniforme, com picos ao longo da tarde (11h–16h, ~30–32 mil/hora). 

## 5. Alguém batendo na porta

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/' dados/access.log | wc -l
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $1}' dados/access.log | sort -u | wc -l
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $9}' dados/access.log | sort | uniq -c | sort -rn
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $7}' dados/access.log | sort | uniq -c | sort -rn | head
```

```
2080
2
2080 404

  382 /admin/login
  368 /wp-login.php
  356 /.git/config
  343 /.env
  318 /phpmyadmin/index.php
  313 /admin
```

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $1}' dados/access.log | sort | uniq -c | sort -rn
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/' dados/access.log | cut -d'"' -f6 | sort | uniq -c
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2 -n
```

```
  1053 198.51.100.9
  1027 198.51.100.23

  2080 python-requests/2.32.3

   518 02
   497 03
   518 04
   547 05
```

**Leitura:** Sim, há varredura ativa de caminhos sensíveis: **2.080 tentativas** de acesso a `/admin`, `/.env`, `/.git/config`, `/wp-login.php` e `/phpmyadmin`, vindas de **apenas 2 IPs distintos** (`198.51.100.9` e `198.51.100.23`). O user-agent `python-requests/2.32.3` denuncia um *scanner* automatizado (não um humano digitando na barra do navegador), e o horário (madrugada, 02h–05h) confirma o padrão de ataque automatizado. O servidor respondeu **404** a todas elas, ou seja, nenhum desses recursos está exposto, e a varredura não teve sucesso.

## Conclusão: minha primeira ação como operador de plantão

Minha primeira ação seria **bloquear o IP `203.0.113.47` no nível do proxy/load balancer**, porque ele é a causa raiz imediata da degradação: concentra 17,1% de todo o tráfego, dispara um *burst* de milhares de requisições por hora em `/api/busca` via `curl`, e é o único responsável pelos 6.900 erros `503`, ou seja, está esgotando o backend. Em paralelo, eu abriria um alerta para o time sobre a varredura dos IPs `198.51.100.9`/`.23` (que tentaram 2.080 acessos a caminhos sensíveis, felizmente todos `404`) e investigaria o `/api/relatorio/gerar`, que responde `500` em ~35% das chamadas, que revela ser um bug intermitente que, diferente do ataque, não some sozinho quando a carga cai.
