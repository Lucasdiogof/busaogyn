# BusãoGyn Web (Cloudflare Workers + Static Assets)

Padrão: `Lucasdiogof/lucksrei-web-template`. Estado: **preparado, não publicado** (nenhum Worker `busaogyn-web` foi criado e não há DNS).

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
