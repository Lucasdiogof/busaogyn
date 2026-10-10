# BusãoGyn — UX do MVP

Atualizado em 06/10/2026.

Este documento define o comportamento do MVP enquanto a rede estática/GTFS oficial ainda não foi recebida.

> **Navegação v2 (aprovada em 10/10/2026, ainda não implementada):** quatro destinos — **Linhas, Pontos, Favoritos e Meu ônibus** —, com **Ajustes na TopBar** e **Chegadas como detalhe do ponto**. Entra de forma gradual, por feature flag desligada em release até a validação (PR‑6). Até lá, **tudo neste documento continua valendo** (dock Chegadas / Meu ônibus / Ajustes). Detalhes: [ADR‑0001](adr/0001-navegacao-e-catalogo-v2.md) e [contrato do PR‑6](v2/PR-6-home-shell-aceite.md).

## Proposta central

O MVP precisa tornar simples e confiável este fluxo:

```text
código do ponto
    ↓
próximas chegadas
    ↓
realtime x programado
    ↓
acompanhar
    ↓
posição real do ônibus
```

Não tentar reproduzir nesta fase um planejador de viagens completo.

## Home

A direção de produto é map-first, mas sem inventar dados estáticos.

Enquanto não houver GTFS:

- busca principal por código RMTC do ponto;
- mapa como área principal de acompanhamento;
- nenhuma parada artificial desenhada;
- nenhuma linha/shape inventado;
- nenhum botão de "perto de mim" enquanto localização + rede estática não forem implementadas de verdade.

## Resultado do ponto

Depois da consulta, mostrar:

- código do ponto;
- estado de atualização;
- grupos por linha/destino;
- próximo ônibus;
- seguinte, quando existir;
- tempo restante;
- realtime ou programado;
- veículo, somente quando houver identidade válida;
- ação `Acompanhar`, somente em chegada realtime com `vehicleNumber != null`.

Chegada programada nunca deve parecer realtime.

## Texto de qualidade

Preferências de apresentação:

- realtime: `Tempo real`
- scheduled: `Programado`
- unknown: não apresentar como realtime; usar texto neutro quando necessário

Minutos:

- `0` -> `< 1 min`
- número positivo -> `N min`
- ausente -> `—`

## Tracking

Ao iniciar tracking:

- registrar explicitamente qual `vehicleNumber` está ativo;
- limpar visualmente a posição do veículo anterior ao trocar para outro;
- mostrar estado de carregamento sem perder a identidade do veículo escolhido;
- após sucesso, manter `trackingVehicleNumber` no estado;
- em falha transitória, manter a identidade do veículo acompanhado;
- manter a última posição válida quando existir;
- não voltar o botão para uma aparência de "não acompanhando" enquanto o timer continua ativo.

Estados sugeridos:

```text
Acompanhar
Buscando…
Acompanhando
Posição temporariamente indisponível
Última posição válida há X s
```

## Atualização

Intervalo atual do app: cerca de 15 segundos.

A UI deve diferenciar:

- snapshot novo;
- cache fresh;
- snapshot stale;
- ausência de posição.

Não apresentar interpolação como posição real.

## Mapa

Quando houver posição real:

- mostrar o ônibus na coordenada recebida;
- preservar zoom quando possível;
- atualizar marcador sem reconstruir todo o mapa;
- mover câmera suavemente em atualizações reais;
- não inferir bearing/direção.

### Auto-follow

Comportamento desejado:

1. ao começar a acompanhar, centralizar no ônibus;
2. enquanto o usuário não interage, acompanhar novas posições;
3. se o usuário fizer pan/zoom manual, suspender auto-follow;
4. botão `Centralizar ônibus` recentraliza e reativa auto-follow.

Isso evita a câmera disputar controle com o usuário.

Implementação (maplibre_gl 0.27.1): o plugin não informa se um movimento de câmera veio de gesto (o Android envia `isGesture`, mas a camada Dart descarta; iOS/Web não enviam). Por isso todo movimento disparado pelo app (`animateCamera`, `updateContentInsets`) abre uma janela programática; início/movimento de câmera fora dela (`isCameraMoving`, `onCameraMove`) ou toque direto no mapa suspendem o follow. A lógica fica em `CameraFollow`, testada sem platform view.

Câmera inicial: centro de Goiânia, apenas contexto. Nenhum marcador é desenhado sem posição real.

### Atribuição

Usa sempre o controle nativo do MapLibre, com os créditos e links definidos pelo estilo em uso (funciona para qualquer `MAP_STYLE_URL`). Nada de texto estático.

- Celular: o controle fica no canto inferior direito do mapa, logo acima do bottom sheet, acompanhando sua altura. Android/iOS usam `attributionButtonMargins`; no Web o plugin ignora margens, então o app informa a altura coberta pelo painel na variável CSS `--busao-map-attribution-bottom`, lida pelo `web/index.html`.
- O sheet expandido sempre deixa uma faixa de mapa abaixo do cabeçalho para a atribuição. O botão `Centralizar ônibus` só aparece quando cabe sem cobri-la.
- `.maplibregl-map { isolation: isolate }` impede que os controles do MapLibre passem por cima dos painéis do Flutter no Web.
- Telas largas (painel lateral): canto inferior direito do mapa, sem deslocamento.

## Timeout

O `ApiClient` usa timeout de 20 s (o Worker espera até ~6 s por tentativa na RMTC, com 1 retry). Ao expirar: `ApiException` com código `CLIENT_TIMEOUT`, `retryable: true`, sem retry automático. Mensagens técnicas do Worker nunca vão para a tela: códigos são mapeados para textos em português.

## Cartão do ônibus acompanhado

Quando houver dados, pode mostrar:

- número do ônibus;
- linha;
- destino;
- pontualidade;
- acessibilidade;
- idade da posição;
- stale quando aplicável.

Não exibir latitude/longitude cruas como informação principal de produto. Coordenadas podem continuar disponíveis apenas para debug, se necessário.

## Estados de erro

### Falha ao consultar o ponto

Mostrar mensagem clara e ação de tentar novamente.

### RMTC/Worker temporariamente indisponível

Se houver snapshot stale permitido pela API:

- manter conteúdo;
- mostrar aviso discreto de desatualização;
- informar idade aproximada.

### Tracking falhou, mas existe posição anterior

- manter marcador anterior;
- informar que é a última posição válida;
- não apagar o mapa abruptamente.

### Tracking sem posição anterior

- manter painel de mapa/estado;
- explicar que a posição está temporariamente indisponível;
- não inventar coordenada.

## Recarregar

Decidido em 07/10/2026:

- **Atualizar chegadas** (botão no cabeçalho do ponto, ou buscar de novo o mesmo código) recarrega só as chegadas e **preserva o tracking**: o acompanhamento é por número do veículo e independe da lista.
- **Buscar outro ponto** encerra o tracking.
- **Acompanhar outro ônibus** troca o tracking, limpa a posição anterior e descarta respostas atrasadas do anterior.
- Falha ao atualizar mantém as chegadas anteriores com aviso; respostas de buscas antigas nunca sobrescrevem a mais recente.
- Pull-to-refresh foi removido: dentro do bottom sheet, puxar para baixo recolhe o painel e os dois gestos brigariam.

## Favoritos e recentes

Podem entrar depois sem conta obrigatória.

Primeira versão aceitável:
- pontos recentes;
- pontos favoritos;
- persistência local.

Na v2 isso evolui para o destino **Favoritos** (favoritos de ponto e de par ponto‑linha, mais recentes, só no aparelho, sem conta), planejado nos PRs 5 e 7 e **ainda não implementado**. Favoritos guardam só a intenção do usuário (códigos) e continuam funcionando para chegadas mesmo sem catálogo. Ao entrar em produção, `PRIVACY.md` deixa de dizer que o app não guarda pontos consultados.

Não persistir amostras GPS do ônibus no Supabase.

## Localização do usuário

Fora do MVP atual.

Só adicionar quando houver uma funcionalidade real, por exemplo:
- pontos próximos;
- ordenar paradas por distância;
- centralizar mapa no usuário.

Ao implementar, pedir permissão de localização somente no momento em que o usuário acionar a funcionalidade correspondente.

## Quando o GTFS oficial chegar

A rede estática poderá habilitar, sem inferência:

- catálogo de pontos;
- nomes/endereço das paradas;
- linhas atendidas;
- pesquisa;
- pontos próximos;
- shapes/trajetos oficiais;
- visualização de linha completa;
- melhor contexto espacial no mapa.

Nada disso deve ser criado a partir de suposição antes dos dados oficiais.

## Quando dados de occupancy/capacidade chegarem

Somente então avaliar:

- lotação;
- capacidade;
- indicadores de ocupação.

Não usar dados simulados para preencher esse espaço.

## Critério visual

A interface deve parecer um produto de mobilidade urbana, não uma tela administrativa da API.

Prioridades:

1. tempo para chegada;
2. realtime/programado;
3. linha e destino;
4. acompanhamento;
5. mapa;
6. detalhes secundários.

Evitar excesso de IDs técnicos, coordenadas e metadados na tela principal.

## Acessibilidade

- todos os controles precisam de labels/semantics apropriados;
- marcador do ônibus deve ser acessível semanticamente;
- cores não podem ser a única forma de distinguir realtime/programado/stale;
- estados de carregamento não devem bloquear leitores de tela desnecessariamente.

## Não fazer nesta fase

- login obrigatório;
- localização do usuário sem função concreta;
- planejamento origem/destino inventado;
- shapes calculados por ruas;
- bearing estimado;
- ocupação simulada;
- GPS histórico persistido;
- dependência Flutter direta da RMTC.
