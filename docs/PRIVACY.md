# BusãoGyn — comportamento de privacidade

Atualizado em 08/10/2026, versão do app `1.0.0+1`.

Este documento descreve o que o app faz hoje com dados, a partir do código deste repositório. Ele **não é uma política de privacidade jurídica**; serve de base factual para redigi-la e para responder aos formulários das lojas (Google Play "Segurança dos dados" e App Store "Privacidade do app").

## Resumo

- Não há conta, login, cadastro nem identificador de usuário.
- O app **não usa a localização do usuário**: não há permissão de localização no Android, nem chave `NSLocation*` no iOS.
- Não acessa contatos, fotos, câmera, microfone, arquivos ou calendário.
- Não tem analytics, crash reporting, publicidade nem SDK de rastreamento.
- Não guarda histórico de buscas, de pontos consultados ou de posições.
- O único dado persistido no aparelho é a preferência de tema (claro, noturno ou sistema).

## 1. Dados do app

| Dado | Onde fica | Por quanto tempo | Sai do aparelho? |
| --- | --- | --- | --- |
| Preferência de tema | `shared_preferences` (Android: SharedPreferences; iOS: NSUserDefaults; Web: `localStorage`) | Até o usuário trocar ou apagar os dados do app | Não |
| Código do ponto digitado | Memória, durante a sessão | Até fechar o app | Sim, na consulta à API BusãoGyn |
| Número do ônibus acompanhado | Memória, durante a sessão | Até parar o acompanhamento ou fechar o app | Sim, na consulta de posição à API BusãoGyn |
| Posições observadas do ônibus (rastro e direção) | Memória, até 20 posições | Limpas ao trocar ou parar o acompanhamento | Não (vêm da API, não do aparelho) |

As posições do rastro são do **ônibus**, recebidas da API, e não do usuário. Elas não são gravadas em disco.

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
| Hospedagem do site (a definir) | Arquivos do app Web | Dados técnicos de rede, conforme os logs do provedor escolhido | Somente Web |

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

- **Google Play — Segurança dos dados**: nenhum dado coletado nem compartilhado. Os códigos de ponto e os números de ônibus são enviados apenas para a consulta pedida e não ficam associados a uma pessoa. Dados criptografados em trânsito: sim. Exclusão de dados: não se aplica, porque não há conta.
- **App Store — Privacidade do app**: "Data Not Collected". Tracking: não.

## Mudanças planejadas (NÃO implementadas)

Esta seção descreve intenção para a v2 ([plano](v2/PLANO_BUSAOGYN_V2.md)). **Nada abaixo existe no app atual**, e todas as seções acima continuam sendo a descrição correta do comportamento da versão `1.0.0+1`.

- **Favoritos e recentes (planejado):** o app passará a guardar **localmente** (`shared_preferences`) os pontos e os pares ponto‑linha que o usuário favoritar, e uma lista curta de pontos recentes: códigos, data de inclusão e, no máximo, um rótulo opcional. Não saem do aparelho (os códigos só são enviados à API BusãoGyn quando o usuário consulta chegadas, como hoje). Sem conta e sem sincronização.
- **Efeito sobre este documento:** quando isso for implementado, o resumo deixará de afirmar que o app “não guarda histórico de buscas ou de pontos consultados” e que o “único dado persistido é a preferência de tema”; o mesmo vale para a tabela da seção 1 e para as respostas das lojas (seção 5). Esta revisão é pré‑requisito para publicar a funcionalidade.
- **Catálogo de linhas e pontos (planejado):** quando houver autorização, o aparelho poderá guardar uma cópia local do catálogo oficial (dados públicos de transporte, sem dado pessoal). Até lá, apenas dados sintéticos em desenvolvimento e testes.
- **Localização do usuário:** continua **não usada** e **não prevista para o próximo release**. Se algum dia entrar (por exemplo, “pontos perto de mim”), será pedida apenas no momento do uso, processada no aparelho e este documento, o CI de permissões e os formulários das lojas serão revistos antes.
- **Telemetria e crash reporting:** nenhum previsto.

## Pendências

- **Política de privacidade publicada**: as duas lojas exigem uma URL pública. É preciso redigir a política a partir deste documento e hospedá-la, de preferência no mesmo domínio do app Web.
- Revisar este documento sempre que mudarem as dependências de rede (estilo do mapa, CDN, API) ou entrar qualquer SDK novo.
