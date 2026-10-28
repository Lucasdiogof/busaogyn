# BusãoGyn — comportamento de privacidade

Atualizado em 28/10/2026 (Etapa E), versão do app `1.0.0+1`.

Este documento descreve o que o app faz hoje com dados, a partir do código deste repositório. Ele **não é uma política de privacidade jurídica**; serve de base factual para redigi-la e para responder aos formulários das lojas (Google Play "Segurança dos dados" e App Store "Privacidade do app").

## Resumo

- Não há conta, login, cadastro nem identificador de usuário.
- O app de produção **não usa a localização do usuário**: o build release do Android não declara permissão de localização (o manifesto principal as remove e também o serviço de localização do plugin). O iOS tem a frase `NSLocationWhenInUseUsageDescription` no `Info.plist` (o arquivo é o mesmo para todos os builds), mas o app de produção nunca pede a permissão: "Perto de mim" só existe com o catálogo de desenvolvimento (seção 1.1).
- Não acessa contatos, fotos, câmera, microfone, arquivos ou calendário.
- Não tem analytics, crash reporting, publicidade nem SDK de rastreamento.
- **Compartilhar ponto** (também em produção): abre a folha de compartilhamento do sistema com o texto mostrado (código do ponto). Sem compartilhamento no aparelho ou navegador, o texto é copiado; nada é enviado pelo app.
- A política fica acessível **dentro do app** (Ajustes → Privacidade: resumo e link da política completa), como exige a App Store.
- O app guarda **no aparelho**, e só nele, a preferência de tema (claro, noturno ou sistema), os pontos favoritos, as linhas favoritas em cada ponto e os últimos pontos consultados com sucesso (seção 1). Nada disso sai do aparelho nem exige conta. Não guarda histórico de buscas, previsões de chegada nem posições.

## 1. Dados do app

| Dado | Onde fica | Por quanto tempo | Sai do aparelho? |
| --- | --- | --- | --- |
| Preferência de tema | `shared_preferences` (Android: SharedPreferences; iOS: NSUserDefaults; Web: `localStorage`) | Até o usuário trocar ou apagar os dados do app | Não |
| Pontos favoritos | `shared_preferences`, chave `busaogyn.saved_stops.v1`: código do ponto, nome só se a fonte der um nome confiável (hoje nenhuma dá) e hora em que foi favoritado. Máximo de 50 | Até o usuário remover o favorito ou apagar os dados do app | Não |
| Linhas favoritas num ponto | Mesma chave (`busaogyn.saved_stops.v1`): código do ponto, código da linha e hora em que foi favoritada. Nunca destino, sentido ou previsão. Máximo de 50 | Até o usuário remover a linha dos favoritos ou apagar os dados do app | Não |
| Pontos recentes | Mesma chave: código do ponto e hora da última consulta bem-sucedida. Máximo de 10, sem repetição; só entram consultas que deram certo | Até o usuário remover o item, limpar o histórico (com confirmação) ou apagar os dados do app | Não |
| Código do ponto digitado | Memória, durante a sessão | Até fechar o app | Sim, na consulta à API BusãoGyn |
| Número do ônibus acompanhado | Memória, durante a sessão | Até parar o acompanhamento ou fechar o app | Sim, na consulta de posição à API BusãoGyn |
| Números dos outros ônibus do ponto (vêm da própria resposta de chegadas) | Memória, durante a sessão | Até trocar de ponto ou fechar o app | Sim, juntos num pedido à API BusãoGyn com o código do ponto (ADR‑0006), ou um por pedido se a API ainda não tiver o lote |
| Posições observadas do ônibus (rastro e direção) | Memória, até 20 posições | Limpas ao trocar ou parar o acompanhamento | Não (vêm da API, não do aparelho) |

### 1.1 Builds de desenvolvimento (catálogo local, Etapa C)

Só existem com o catálogo de desenvolvimento, que não vai para produção:

- **Perto de mim:** uma leitura da posição atual, em primeiro plano, **só quando o usuário toca no botão** (Android debug/profile declaram `ACCESS_COARSE_LOCATION`/`ACCESS_FINE_LOCATION`; iOS pede "durante o uso"; Web usa a API do navegador). A posição fica na memória até o usuário sair do app, é usada só para ordenar os pontos do catálogo do próprio aparelho e **não é gravada nem enviada** a nenhum servidor. Sem segundo plano, sem histórico.
- **Viagens salvas:** na mesma chave `busaogyn.saved_stops.v1` (schema 3): códigos de origem e destino, nome opcional dado pelo usuário (até 40 caracteres) e hora. Máximo de 20. O itinerário não é gravado.
- **Compartilhar:** abre a folha de compartilhamento do sistema com um texto que o usuário vê (código/endereço do ponto, linha ou passos da viagem). Nada é enviado sem a ação do usuário; nunca inclui a posição dele.

As posições do rastro são do **ônibus**, recebidas da API, e não do usuário. Elas não são gravadas em disco.

Favoritos, linhas favoritas e recentes guardam **só códigos de ponto, códigos de linha e horas**. Nenhuma previsão de chegada, posição de ônibus, coordenada ou texto livre digitado pelo usuário é gravada. A aba Favoritos consulta a API BusãoGyn (com os códigos dos pontos favoritos, até 10 por vez) ao abrir e ao atualizar; o resultado fica só na memória. Os códigos só vão para a API BusãoGyn quando o usuário consulta as chegadas de um ponto, como sempre. Se o aparelho não permitir gravar, o app avisa e a lista vale até fechar o app.

## 2. Dados técnicos de rede

Toda comunicação usa HTTPS. Como em qualquer requisição de rede, cada serviço consultado recebe o endereço IP do aparelho, o horário e os cabeçalhos padrão (User-Agent, idioma e, no Web, `Origin`/`Referer`).

O app não envia identificadores próprios, cookies nem tokens.

## 3. Serviços externos

| Serviço | Para quê | O que recebe | Plataformas |
| --- | --- | --- | --- |
| API BusãoGyn (Cloudflare Workers, `busaogyn-api.lively-cloud-f009.workers.dev`) | Chegadas por ponto e posição do ônibus | Código do ponto, número do ônibus e dados técnicos de rede | Todas |
| OpenFreeMap (`tiles.openfreemap.org`) | Estilo, tiles, fontes e ícones do mapa | Área e zoom do mapa exibido, dados técnicos de rede | Todas |
| unpkg (`unpkg.com`) | Biblioteca MapLibre GL JS 6.4.1 e seu CSS, carregados pelo plugin `maplibre_gl_web` | Dados técnicos de rede | Somente Web |
| Google Fonts (`fonts.gstatic.com`) | Fontes de fallback do Flutter Web, baixadas só se a tela precisar de caracteres fora das fontes do app (por exemplo, emoji) | Dados técnicos de rede | Somente Web |
| Cloudflare Workers (Static Assets, Worker `busaogyn-web`, publicado em `busaogyn.lucksrei.com`) | Arquivos do app Web; a zona também injeta uma verificação anti-robô (`/cdn-cgi/challenge-platform`, observada em 28/10/2026) | Dados técnicos de rede e sinais do navegador usados pela verificação, conforme a plataforma | Somente Web |

Notas:

- **API BusãoGyn**: o código do Worker registra em log o método, o caminho da requisição (que contém o código do ponto ou o número do ônibus), o status e a duração (`worker/src/infra/logger.ts`). O código da aplicação não registra deliberadamente o IP nem cabeçalhos. A Cloudflare processa as requisições como provedora da infraestrutura e pode manter registros e métricas próprios da plataforma, conforme a configuração da conta e os termos dela. Este repositório não configura nem comprova o que a plataforma retém.
- A API repassa consultas às fontes públicas da RMTC/RedeMob. O app não acessa essas fontes diretamente.
- No Web, o CanvasKit (motor gráfico do Flutter) é servido pelo próprio site, e não pelo CDN `gstatic.com`.
- O plugin de mapa (MapLibre) não recebe a localização do usuário. As permissões de localização que ele declararia no Android são removidas do manifest final.

## 4. Manifestos de privacidade de SDKs (iOS)

- O Flutter e o `shared_preferences_foundation` (UserDefaults, motivo `1C8F.1`) trazem `PrivacyInfo.xcprivacy` próprio.
- O MapLibre iOS 6.28.0 traz `PrivacyInfo.xcprivacy` próprio (tag `ios-v6.28.0`): sem tracking, sem coleta, APIs FileTimestamp `C617.1`, SystemBootTime `35F9.1` e UserDefaults `CA92.1`.
- O código do próprio app (`AppDelegate.swift`) não usa nenhuma API que exija justificativa ("required reason API"), por isso o Runner não tem manifesto próprio. Antes da submissão, confira o relatório de privacidade gerado pelo Xcode (Organizer → Generate Privacy Report).

## 5. Respostas sugeridas para as lojas

São sugestões factuais, a confirmar junto com a política final: os formulários têm definições próprias, como "coleta" e "processamento efêmero". Elas valem para o comportamento atual e devem ser revistas se surgir login, analytics, crash reporting ou localização.

- **Google Play — Segurança dos dados** (favoritos, linhas favoritas e recentes ficam só no aparelho): nenhum dado coletado nem compartilhado. Os códigos de ponto e os números de ônibus são enviados apenas para a consulta pedida e não ficam associados a uma pessoa. Dados criptografados em trânsito: sim. Exclusão de dados: não se aplica, porque não há conta.
- **App Store — Privacidade do app**: "Data Not Collected". Tracking: não.

## Mudanças planejadas (NÃO implementadas)

Esta seção descreve intenção para as próximas versões ([plano](v2/PLANO_BUSAOGYN_V2.md)). **Nada abaixo, exceto o que está marcado como implementado, existe no app atual.**

- **Favoritos, linhas favoritas e recentes (implementados):** descritos no resumo e na seção 1. Os dados ficam só no aparelho e não são transmitidos, mas a política publicada deve citar que o app guarda esses itens localmente.
- **Catálogo de linhas e pontos (planejado):** quando houver autorização, o aparelho poderá guardar uma cópia local do catálogo oficial (dados públicos de transporte, sem dado pessoal). Até lá, apenas dados sintéticos em desenvolvimento e testes.
- **Localização do usuário:** continua **não usada** e **não prevista para o próximo release**. Se algum dia entrar (por exemplo, “pontos perto de mim”), será pedida apenas no momento do uso, processada no aparelho e este documento, o CI de permissões e os formulários das lojas serão revistos antes.
- **Telemetria e crash reporting:** nenhum previsto.

## Pendências

- **Política pública em lucksrei.com** (atualizada em 22/10/2026): falta citar o compartilhar e a verificação anti-robô da Cloudflare na versão Web. Texto proposto em [BUSAOGYN_2_0_ETAPA_E_PUBLICACAO.md](BUSAOGYN_2_0_ETAPA_E_PUBLICACAO.md#7-privacidade-e-segurança); o app aponta para `https://lucksrei.com/projects/busaogyn/privacy/`.

- **Páginas públicas em três idiomas** (privacidade, exclusão de dados e suporte) em https://lucksrei.com/projects/busaogyn/ (repositório do site). Contato: marketing@lucksrei.com. Mantenha-as iguais a este documento quando algo mudar.
- **Política de privacidade publicada**: o texto público está em `app/web/privacidade.html` (servido em `/privacidade.html` com o app Web). Falta só publicar o app Web e informar essa URL nas duas lojas. Mantenha a página igual a este documento quando algo mudar.
- Revisar este documento sempre que mudarem as dependências de rede (estilo do mapa, CDN, API) ou entrar qualquer SDK novo.
