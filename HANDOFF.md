# BusãoGyn — handoff de progresso

Atualizado em 08/10/2026, no meio do redesign cartográfico do mapa.

Este arquivo existe só para continuar o trabalho em outra sessão/conta. Ele vive na branch `claude/eager-mendel-jpk57h` (junto de `handoff/real_map.cjs`) e **não deve ir para a main**.

## Estado atual

- `main` = `488b0bf6d5658312e54b118ea24abbc7e74599f7` — `feat(app): improve tracked vehicle details and position states (#26)`. CI da main (run 74) verde: flutter, build-android-web, build-ios.
- v1 em **FEATURE FREEZE**. Exceções liberadas pelo dono, em ordem: PR #26 (ficha do ônibus, já mergeado) e agora o **redesign cartográfico do mapa** (esta tarefa, em andamento).
- App `1.0.0+1`, Flutter 3.38.5 / Dart 3.10.4. **224 testes** passando na main.
- Remoto: só `main` e esta branch de handoff. A branch `chore/map-visual-polish` existe só localmente (criada de `488b0bf`, **sem nenhum commit**); recriar de `origin/main`.
- Nenhuma loja, site ou Worker foi publicado. O Worker não foi alterado.

## O que o #26 entregou (mergeado)

- Aba Meu ônibus: ficha compacta + seção "Detalhes do ônibus" (ônibus, linha/nome, destino, ponto de referência, posição, pontualidade, acessibilidade, **Lotação: "Informação não disponível"**, movimento, nota de que o rastro é só passado observado).
- Estados da posição separados: Ao vivo · há X; Última posição há X; Posição desatualizada (stale); **Posição temporariamente indisponível** (fonte respondeu sem posição utilizável); **Conexão instável** (só falha de rede/serviço). `isConnectivityError` em `error_messages.dart`.
- Posição do acompanhado expira em **90 s** de idade total (idade na API + tempo local): o marcador sai, o resto da ficha e o rastro ficam; a próxima posição válida traz o marcador de volta. `positionMaxAge` no `StopArrivalsCubit`.
- Marcador do acompanhado com **seta** à frente do para-brisa (variante `tracked-heading`, imagem `bus-tracked-heading`) só com direção observada e posição atual; tocar no acompanhado abre a ficha (`onTrackedTap`).

## TAREFA EM ANDAMENTO: redesign cartográfico do mapa (`chore/map-visual-polish`)

Pedido do dono (exceção só visual, "Waze-like em sensação, sem copiar identidade"):

- Mapa mais clean, com hierarquia: 1) ônibus acompanhado, 2) rastro/direção, 3) vias principais, 4) nomes relevantes, 5) resto recuado.
- **Prioridade: tema escuro** (grafite ~`#111311`–`#161714`, não preto). Claro: off-white/cinza suave, não branco estourado.
- Ruas locais finas, baixo contraste, sem halo; avenidas um pouco mais largas/claras; rodovias legíveis sem dominar; **sem amarelo/âmbar em vias** (âmbar reservado a ônibus acompanhado, rastro, foco, controles, seleção).
- Labels: menores, menos opacos, halo sutil, minzoom maior para ruas pequenas; bairros discretos; **POIs quase todos fora**; prédios tom-sobre-tom; parques/água discretos.
- Secundários neutros e menores que o acompanhado; rastro mais fino/transparente (continua sendo só passado observado); marcador do acompanhado deve ser achado em <1 s.
- Hierarquia por zoom (baixo: rodovias/avenidas/bairros; médio: + ruas principais; alto: ruas locais, labels extras, prédios discretos).
- Opcional só se barato: modo foco quando há tracking (atenuar POI/labels/ruas locais). Prioridade é o style base.
- **Continuar com MapLibre + OpenFreeMap.** Atribuição obrigatória sempre visível. Não mexer nos sources do app (tracked, secondary, trail), em polling, tracking, Worker, GTFS, nem em outra UI (dock, cards, header, abas).
- **Preservar a proteção de style reload do PR #25**: `_styleLoad`/`_invalidateStyle`, `step()` em `_onStyleLoaded`, `_setSource`; sem ids duplicados; tracked acima de secondary, rastro abaixo dos veículos.
- Testes só de invariantes do style (atribuição/sources/glyphs/sprite preservados, light e dark válidos, ids únicos, ordem tracked > secondary > trail, reload seguro). Sem snapshot visual.
- Git: commits pequenos, push OK, **NÃO abrir PR, NÃO mergear** (o dono quer revisar antes).
- Relatório final pedido: HEAD inicial/final; style (arquivos, light, dark, sources/sprites/glyphs); hierarquia (rodovias, avenidas, ruas, serviço, prédios, parques, água, POIs, labels); tracked, secundários, rastro; zoom; performance; testes; **screenshots antes/depois lado a lado** (390×844 e 1366×768, claro e escuro; estados: sem tracking, tracked, tracked+rastro, secundários); avaliação visual antes/depois; pendências. Fechar com: "Mapa do BusãoGyn recebeu lapidação cartográfica focada em hierarquia, redução de ruído e destaque do ônibus, sem alterar dados, tracking, regras de negócio ou significado do rastro. Não abri PR e não fiz merge."

### O que já foi feito (só auditoria, nada commitado)

- **Estilos hoje:** claro = Liberty puro do OpenFreeMap por URL (`https://tiles.openfreemap.org/styles/liberty`, 111 layers); escuro = `app/assets/map/liberty-night.json` (107 layers), gerado por `app/tool/build_night_style.dart` + `app/lib/src/core/map/night_style.dart` (`deriveNightStyle`: só recolore `*-color` por transformação HSL genérica, remove layers `poi*`). Config em `app/lib/src/core/config/map_config.dart` (`MapStyles.resolve`, fallback = Liberty URL se o estilo não carregar em 12 s). Testes em `app/test/core/map_style_test.dart` (fixam `styles.light == defaultStyleUrl` e `dark == nightStyleAsset`; vão precisar ser atualizados se o claro virar asset).
- **Sources/sprite/glyphs (preservar):** sources `ne2_shaded` (raster) e `openmaptiles` (`https://tiles.openfreemap.org/planet`, de onde vem a atribuição); sprite `https://tiles.openfreemap.org/sprites/ofm_f384/ofm`; glyphs `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf`.
- **Layers do Liberty (ids):** fills (background, natural_earth raster, park, landuse_*, landcover_*, water, aeroway_fill, building, building-3d), linhas de via em 3 grupos tunnel_/road_/bridge_ (`*_motorway`, `*_trunk_primary`, `*_secondary_tertiary`, `*_minor`/`*_street`, `*_service_track`, `*_path_pedestrian`, `*_link`, `*_casing`, trilhos), `road_one_way_arrow*`, fronteiras (`boundary_*`), símbolos: `waterway_line_label`, `water_name_*`, `poi_r20/r7/r1`, `poi_transit`, `highway-name-path/minor/major`, `highway-shield-non-us`, `highway-shield-us-interstate`, `road_shield_us`, `airport`, `label_other/village/town/state/city/city_capital/country_*`.
- **Achados do "antes" (screenshots reais):** no claro, vias principais amarelo/laranja forte (concorrem com o âmbar do ônibus), POIs de loja/carro visíveis, muitos nomes de rua; no escuro, ruas locais com quase o mesmo peso das avenidas e muitos labels. Valores atuais de referência: `road_minor` branco, largura 2.5→18 (z14→20), casing `#cfcdca`; `road_secondary_tertiary`/`road_trunk_primary` `#fea`; `road_motorway` `#fc8`; `highway-name-minor` minzoom 15, tamanho 12–13, cor `#666`, halo 1; `highway-name-major` minzoom 12.2; `building` minzoom 13.

### Plano decidido (ainda não implementado)

1. Criar `app/lib/src/core/map/busao_style.dart` com um gerador **explícito e determinístico** (`buildBusaoStyle(liberty, BusaoMapTheme)`), substituindo a derivação HSL genérica: remove camadas de ruído (`poi*`, `building-3d`, `road_one_way_arrow*`, shields extras, etc.), aplica paleta **por grupo de ids** (não por transformação global), ajusta larguras, `minzoom`, tamanho/opacidade/halo dos labels. Não duplicar o JSON gigante: o gerador lê o Liberty e escreve os assets.
2. Gerar `app/assets/map/busao-dark.json` e `busao-light.json` (via `app/tool/build_map_styles.dart`, determinístico), registrar no `pubspec.yaml`, e apontar `MapStyles.resolve` para os dois assets por padrão (custom `MAP_STYLE_URL` continua valendo para os dois temas; fallback = Liberty URL). Manter ou migrar `liberty-night.json`/`night_style.dart` (remover só se nada mais usar; atualizar `map_style_test.dart`).
3. Ajustar em `tracked_vehicle_map.dart` (só paint/layout, **sem tocar sources**): halo e contorno do acompanhado, secundários neutros e menores, rastro mais fino/transparente (dark: âmbar opacidade moderada; light: âmbar mais escuro). Refinar o desenho do marcador em `vehicle_marker_image.dart` se necessário (frente identificável sem seta enorme).
4. Testes de invariantes do style; `dart format`, `flutter analyze`, `flutter test`, `flutter build web --release`; capturas "depois" com o mesmo harness e relatório com antes/depois.

## Como capturar o mapa de verdade nesta infraestrutura (aprendido na prática)

Rede da sessão em nuvem: o dono liberou `tiles.openfreemap.org` e `unpkg.com` no ambiente (Settings do ambiente → Network access → Allowed domains). A **API BusãoGyn (`busaogyn-api.lively-cloud-f009.workers.dev`) continua bloqueada**: o harness a simula (`page.route`), e o mapa/tiles/MapLibre são reais. Se uma sessão nova não tiver os domínios liberados, pedir ao dono.

Script pronto: `handoff/real_map.cjs` nesta branch (Playwright 1.56 em `/opt/node-tools`). Uso:

```bash
# 1) build e servidor local
cd app && flutter build web --release
cd build/web && nohup python3 -m http.server 8766 --bind 127.0.0.1 >/dev/null 2>&1 &
# 2) captura: <pasta> <WxH> <light|dark> <nome> <track|idle>
cd /opt/node-tools && NODE_PATH=/opt/node-tools/node_modules \
  node /caminho/handoff/real_map.cjs /pasta/saida 390x844 dark antes-390-dark track
```

Pegadinhas:
- Chromium precisa de `--proxy-server=$HTTPS_PROXY` com `--proxy-bypass-list=127.0.0.1;localhost` (senão manda o localhost pelo proxy e dá erro 405).
- **Locale `pt-BR` no contexto do navegador**, senão o Flutter Web não inicia ("Incorrect locale information provided").
- WebGL: `--use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist`.
- O script ativa a semântica do Flutter (`flt-semantics-placeholder`), busca `30402`, toca em "Acompanhar ônibus 20693" e espera ~34 s para colher 3 posições simuladas (direção + rastro). `idle` só carrega o app, sem tracking.
- Para telas do app sem mapa real (QA de layout), os testes de widget com `mapBuilder` fake e screenshots via `renderViews.first.debugLayer.toImage` funcionam (precisa carregar as fontes Geist e MaterialIcons com `FontLoader`).
- SDK Flutter 3.38.5 não vem na imagem: baixar `flutter_linux_3.38.5-stable.tar.xz`, `chown -R` para o usuário atual (senão o git do SDK reclama de "dubious ownership") e usar `flutter --disable-analytics`.
- `flutter test` pode travar com `await` em retomadas no relógio simulado: usar `unawaited(...)` + `tester.pump`.

## Regras que o dono do projeto pediu

- Não fazer PR nem merge sem pedido explícito.
- Mensagens de squash para a main escritas à mão, **sem** "Claude", "AI", "Generated", `Co-Authored-By` de IA ou `Claude-Session`.
- Descrições de PR e comentários sem rodapé de IA. O GitHub MCP acrescenta um rodapé "Generated by Claude Code" sozinho: **remover editando a descrição/comentário depois de criar** (aconteceu em todos os PRs).
- Commits da branch de handoff e commits de trabalho: sem trailers de IA quando o dono pedir (ele pediu para o handoff).
- Nunca commitar `.keystore`, `.jks`, senhas, `key.properties` com segredos, certificados ou provisioning profiles; não criar chaves/certificados falsos.
- Não adicionar permissões de localização. Não alterar nem fazer deploy do Worker sem pedido.
- Não usar KML/GTFS nem inventar geometria de rota; rastro/direção só de posições reais recebidas. **Não inventar lotação, trajeto futuro, operadora, modelo**.
- Não mascarar falhas de CI (`continue-on-error`, `|| true`, skip). Se `build-android-web` falhar por resolução do `plugins.gradle.org`/Kotlin (já aconteceu uma vez, passou no rerun), ler o log antes e rerodar só o job uma vez.
- Não atualizar dependências sem motivo concreto. Não reescrever histórico. Não incluir `.idea/`, `worker/node_modules/`, `worker/.wrangler/` nem mudanças de ambiente em `app/analysis_options.yaml` / `app/android/gradle.properties`.
- O CI só roda em push para `main`, `feat/**`, `fix/**`, `chore/**` e em PRs; branches `claude/**` não disparam CI.
- Depois de cada exceção do freeze, voltar ao FEATURE FREEZE (só bug comprovado, crash, regressão, performance, acessibilidade, ajuste visual, QA).

## Pendências

- **Mapa:** concluir o redesign acima (nada commitado ainda). Depois: PR `chore/map-visual-polish → main` só se o dono pedir.
- **Cosméticas:** destino longo pode quebrar palavra com fonte ≥150%; "Meu ônibus" truncado a 200% em tela estreita; secundário desatualizado pode ficar no mapa até o próximo ciclo de 30 s.
- **Dados futuros:** lotação real (hoje não há contrato nem campo; só UI honesta), GTFS/shape para trajeto e próximas paradas.
- **Teste físico** em Android e iPhone contra a API real; decidir sobre `ACCESS_WIFI_STATE` depois (Wi-Fi/rede móvel).
- **Publicação (fora do escopo agora):** política de privacidade em lucksrei.com; Play Store (chave de upload, Play App Signing, listing, Segurança dos dados, teste interno antes de produção); App Store (Team, certificado, `pod install` num Mac); Web público (hosting, domínio, `ALLOWED_ORIGINS` do Worker). `docs/PRIVACY.md` e `docs/MOBILE_RELEASE.md` na main são a base.
- **Pós-lançamento:** UIScene no iOS; Node 24 nas actions; alvos de 48 dp no Android; MapLibre GL JS local em vez do unpkg.

## Prompt para retomar

> Repositório Lucasdiogof/busaogyn. Leia `HANDOFF.md` e `handoff/real_map.cjs` na branch `claude/eager-mendel-jpk57h`, e `docs/MOBILE_RELEASE.md` na main. A main está em `488b0bf` (PR #26 mergeado, CI verde, 224 testes), v1 em feature freeze. Continue **somente** o redesign cartográfico do mapa descrito na seção "TAREFA EM ANDAMENTO" do HANDOFF: crie `chore/map-visual-polish` a partir de `origin/main` (a branch local antiga não tem commits), implemente o plano (gerador `busao_style.dart`, assets `busao-dark.json`/`busao-light.json`, ajustes só de paint/layout do marcador e do rastro, testes de invariantes), capture antes/depois reais com o harness (o "antes" deve ser refeito: as imagens anteriores se perderam com o container), valide (format, analyze, test, web build), faça commits pequenos e push. **Não abra PR e não faça merge.** Se os domínios `tiles.openfreemap.org` e `unpkg.com` estiverem bloqueados, avise o dono. Siga as regras do HANDOFF (sem trailers/rodapés de IA em squash, PR e comentários; preservar a proteção de style reload; nada de rota futura, lotação ou dados inventados).
