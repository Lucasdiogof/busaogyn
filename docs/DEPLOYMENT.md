# Deploy do Worker

O deploy de produção é manual pelo GitHub Actions:

```text
Actions -> Deploy Worker -> Run workflow
```

## Secrets necessários

No repositório GitHub, configure os secrets de Actions:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

O token deve ter somente as permissões necessárias para publicar o Worker `busaogyn-api`.

## Antes do deploy

O workflow executa obrigatoriamente:

```text
npm ci
npm run typecheck
npm test
```

Só depois chama `wrangler deploy`.

O `worker/package-lock.json` é versionado e os workflows usam `npm ci` para instalações reproduzíveis.

O SHA do commit é publicado na variável `BUILD_SHA` e fica disponível em:

```text
GET /v1/version
```

## Domínio

O primeiro deploy pode usar o endereço `workers.dev`. O domínio `api.busaogyn.com.br` deve ser configurado separadamente somente depois que o Worker estiver validado em produção.

Não coloque tokens Cloudflare no código, no `wrangler.toml` ou no Flutter.
