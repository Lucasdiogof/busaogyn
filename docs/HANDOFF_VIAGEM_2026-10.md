# Handoff — correções da viagem (14–15/10/2026)

Dois itens vieram de uso real em aparelho: BUS-001 (trajeto à frente) e
BUS-OFF-001 (estado offline em Chegadas). Este documento registra o
diagnóstico, o que foi feito, o que **não** dá para fazer e o que falta
validar em aparelho.

## BUS-001 — trajeto à frente e próximos pontos

### Diagnóstico (causa raiz)

O app mostra só o rastro já percorrido porque **a fonte não fornece mais do
que isso**. O que a RMTC devolve por ônibus
(`worker/src/sources/rmtc/vehicle-position.source.ts`):

| Campo | Existe | Uso |
| --- | --- | --- |
| Número do veículo, linha (`LinhaNumero`) | sim | identidade |
| Itinerário (`LinhaItinerario`) | sim, **texto livre** | só exibição |
| Destino (`DestinoNome`, ex.: "CENTRO") | sim | "Indo para CENTRO" |
| Posição atual (lat/lon) | sim | marcador |
| Pontualidade, acessibilidade | sim | selos |
| Ponto consultado e previsão em minutos até ele | sim | "3 min até o ponto" |
| **Sequência de paradas** | **não** | — |
| **Sentido (ida/volta) como dado** | **não** (só o destino em texto) | — |
| **Geometria/shape da linha** | **não** | — |

Isso já estava registrado no ADR-0002 (dados confiáveis e não inferência):
ordem de paradas, sentido e geometria só existem com fonte oficial licenciada
(GTFS), cujo protocolo está pendente. O ADR proíbe inferir por coordenada,
ID, nome de via ou texto do itinerário, e o prompt do item também veta linha
reta entre paradas, pontos fictícios e ETA inventado.

### O que foi feito

- O cartão "Meu ônibus" agora diz de forma explícita o que o mapa mostra e o
  que não mostra: o rastro é só por onde o ônibus **já passou**; a fonte não
  informa o trajeto à frente nem a ordem dos próximos pontos, então **nenhuma
  rota é desenhada**. (`tracking_card.dart`)
- Mantido o que já existia e está correto: posição ao vivo, rastro observado,
  direção observada, expiração em 90 s, descarte de respostas de ônibus/ponto
  anterior por geração (nenhum dado antigo sobrevive à troca de ônibus).
- "Quais ônibus ainda vão passar por este ponto": já é o que a lista de
  Chegadas mostra (previsão da própria RMTC por linha, próximo e seguinte).
  Nada além disso é determinável com confiança.

### O que permanece indisponível e por quê

- Trajeto futuro desenhado, próximos pontos em ordem e destaque do "próximo
  ponto" **dependem de GTFS (ou fonte equivalente) licenciado**. Sem ele,
  qualquer implementação seria inferência. Gate C do plano v2.
- Não há ETA além do que a RMTC já informa para o ponto consultado.

### Para destravar

1. Obter autorização/GTFS da RMTC (protocolo 2026106554419306 no ADR-0002).
2. Ingerir `stop_times` → `LineStop.sequence` e `direction_id`, e `shapes`.
3. Só então ligar as capabilities `hasStopSequence`, `hasDirections`,
   `hasShapes` e desenhar a camada futura (traço diferente do passado).

## BUS-OFF-001 — estado offline em Chegadas

### Diagnóstico

1. Falha de conexão e falha da fonte pintavam a **borda de erro do campo de
   busca**, como se o código estivesse errado.
2. O painel abaixo continuava com "Digite o código do ponto", sugerindo
   consulta normal.
3. Não havia ação de tentar de novo no aviso.
4. O aviso de atualização que falhou não dizia de que hora era a consulta
   mostrada.

### O que foi feito

- Borda de erro só para **código inválido** e **ponto não encontrado**.
  Conexão, timeout e fonte indisponível ficam só com o aviso.
  (`SearchFeedback.isConnectivity`, `search_header.dart`)
- Botão **Tentar de novo** no aviso (uma consulta por toque, mantém o código
  digitado, sem repetição automática).
- Painel com estado próprio para falha de conexão/fonte, sem "Digite o código":
  sem internet explica que o mapa segue disponível e que nenhuma previsão
  antiga é mostrada como atual; falha da fonte diz que o código não foi o
  problema. Botão "Tentar o ponto <código>". (`arrivals_panel.dart`)
- Quando uma atualização falha e a consulta anterior continua na tela, o
  aviso informa a hora dela ("consulta das 17:57, que pode já não valer").
- Estados já distintos e preservados: sem internet, tempo esgotado, fonte
  indisponível, ponto não encontrado, código inválido e "Nenhuma chegada
  prevista agora".

### Limitação deliberada: sem cache de chegadas

O app não guarda chegadas em disco, e o prompt só pede cache "se existir cache
local confiável". Previsões envelhecem em minutos; mostrá-las offline seria
arriscar passar dado antigo por ao vivo. Decisão: **não criar cache**. O que
funciona offline é o mapa base já carregado e a interface.

## Arquivos alterados

- `app/lib/src/features/transit/presentation/formatters/search_feedback.dart`
- `app/lib/src/features/transit/presentation/widgets/search_header.dart`
- `app/lib/src/features/transit/presentation/widgets/arrivals_panel.dart`
- `app/lib/src/features/transit/presentation/pages/stop_arrivals_page.dart`
- `app/lib/src/features/transit/presentation/widgets/tracking_card.dart`

Worker, API, mapa, polling, expiração e tracking não foram alterados.

## Verificação

Nesta etapa **não foram rodados** `flutter analyze`, testes nem builds (regra
do pacote). Apenas `dart format`. Os testes existentes não dependem dos
textos alterados, mas **não há teste novo** cobrindo os estados novos.

## Checklist manual em aparelho

Modo avião:
1. Abrir o app com modo avião, buscar `30402`: campo **sem** borda vermelha,
   aviso "Sem conexão" com **Tentar de novo**, painel "Chegadas precisam de
   internet"; código continua digitado.
2. Desligar o modo avião e tocar em **Tentar de novo**: uma consulta, chegadas
   carregam.
3. Consultar um ponto com internet, ligar o modo avião e tocar em atualizar:
   aviso de que não foi possível atualizar, com a hora da consulta mostrada;
   nada rotulado como ao vivo.
4. Reconectar: a atualização automática volta sem reabrir o app.

Outros estados:
5. Código inexistente: borda de erro e "Ponto não encontrado" (sem botão).
6. Fonte fora do ar (como em 8–9/10): aviso de serviço indisponível, campo sem
   borda de erro, painel "Não conseguimos consultar as chegadas".
7. Ponto sem ônibus previstos: "Nenhuma chegada prevista agora".

Acompanhamento:
8. Acompanhar um ônibus: o cartão explica que o rastro é só o passado e que a
   rota à frente não é informada; nenhuma linha futura aparece no mapa.
9. Trocar de ônibus e de ponto: nada do ônibus anterior fica na tela.
