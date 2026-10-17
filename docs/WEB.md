# BusãoGyn Web (Cloudflare Workers + Static Assets)

Padrão: `Lucasdiogof/lucksrei-web-template`. Estado: **publicado em teste** em https://busaogyn-web.lucasdiogo1234.workers.dev (Worker `busaogyn-web`); domínio `busaogyn.lucksrei.com` ainda sem DNS.

- Arquivos em `app/`: `wrangler.jsonc` (Worker `busaogyn-web`, só assets, rota `busaogyn.lucksrei.com` comentada), `web/_headers`, `scripts/*.sh`.
- Build: `cd app && bash scripts/build-web.sh <json com BUSAOGYN_API_BASE_URL>`; o app não usa chaves (sem conta, sem Supabase).
  O CI do repositório fixa Flutter 3.38.5; a validação local usou 3.47.4 (o SDK fl338 do PC está incompleto).
- Deploy manual: `bash scripts/deploy-web.sh <json>`. Rollback: `npx wrangler rollback <id> --name busaogyn-web`.
- Sem deploy automático (nenhum secret criado). A API (`busaogyn-api`) continua com deploy manual pelo GitHub Actions.
- CORS: `worker/wrangler.toml` agora lista `https://busaogyn.lucksrei.com` em `ALLOWED_ORIGINS`. **Só vale depois de um novo deploy manual do Worker da API**; sem isso o app web em outro domínio não consegue chamar a API (o navegador bloqueia).
- Mapa na web carrega MapLibre GL JS do unpkg e tiles do OpenFreeMap; a política de privacidade já informa isso.

## Validado (2026-10-17)
`flutter build web --release` compila; `wrangler dev --local`: raiz, manifest, scripts e rota profunda respondem 200 e os headers estão presentes.
Testes do Worker: 26 passam. **Não validado**: mapa e consulta de chegadas no navegador.

## Privacidade
Sem conta, sem localização, sem analytics (ver `docs/PRIVACY.md` e `app/web/privacidade.html`, ambos atualizados para citar a Cloudflare
como hospedagem da versão web). Nada mudou no tratamento de dados. Pendente para publicar: a Cloudflare e o unpkg recebem IP/UA dos visitantes
(já informado na política).

## Verificação independente (2026-10-17, noite)
- A API em produção ainda era o deploy de 06/10 e não devolvia `Access-Control-Allow-Origin` para as origens web (só localhost): o app web não conseguia buscar chegadas. Reexecutado o workflow **Deploy Worker** (run 39069301894: typecheck, testes, deploy e smoke de produção, todos ok); agora a API responde CORS para `https://busaogyn-web.lucasdiogo1234.workers.dev` (e já lista `https://busaogyn.lucksrei.com`). Código da API sem mudança desde 06/10 além de `ALLOWED_ORIGINS`.
- Smoke estrito do template contra o `workers.dev`: HTML, scripts, `main.dart.js` (3,3 MB), manifest, `version.json`, rotas `/ponto/30402` e `/linhas`, headers: **passou**. `/privacidade.html` responde 307 para `/privacidade` (200, html) — comportamento do Static Assets, não erro.
- Navegador: Home e ponto 30402 com 10 linhas e chegadas em tempo real, mapa (OpenFreeMap) com os ônibus. `GET /v1/vehicles/50507/position` respondeu 502 (veículo sem posição no upstream RMTC); o app segue normalmente.
- Workflow: `SMOKE_URLS` só com a URL viva; o domínio volta à lista quando a rota for ativada.
