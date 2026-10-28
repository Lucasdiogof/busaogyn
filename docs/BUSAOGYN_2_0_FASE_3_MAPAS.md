# BusãoGyn 2.0 — Fase 3: mapa inteligente com pontos e trajetos (desenvolvimento)

- **Data:** 28/10/2026
- **Branch:** `feat/cmtc-catalogo-dev` (sem merge na `main`, sem deploy)
- **Status:** implementado e validado **só no build de desenvolvimento** (`dev_catalog/main.dart`). O build de produção não tem catálogo, nem pontos/trajetos no mapa, nem as camadas novas (teste e verificação de artefato abaixo).
- **Motivo da restrição:** licença/redistribuição dos dados CMTC ainda pendente (`CMTC_2026_INVENTARIO_DADOS.md` §1); o repositório no GitHub é público, então nenhum dado oficial nem derivado é versionado.

---

## 1. O que funciona (com o catálogo de desenvolvimento)

| Requisito | Como funciona | Validação |
|---|---|---|
| Pontos oficiais no mapa | ~7,5 mil pontos numa source GeoJSON nativa do MapLibre, com **agrupamento** (cluster) até o zoom 13; acima disso, um círculo por ponto | Testes + visual web (celular e tablet) |
| Toque em grupo | Aproxima 2 níveis de zoom no grupo | Teste + visual web |
| Toque em ponto | Abre o painel do ponto (código, endereço, bairro, município, linhas do cadastro, "Ver chegadas", favoritar) e destaca o ponto com um halo | Teste + visual web |
| Foco a partir da busca, favoritos e recentes | Ao abrir um ponto, a câmera vai até ele (zoom ≥ 16); pedido feito antes do estilo carregar é aplicado depois | Testes |
| Trajeto completo da linha | Aba Linhas → linha → o trajeto da variante principal (ida) aparece e é enquadrado; chips **Ida/Volta** por variante trocam o trajeto | Testes + visual web |
| Diferenciar ida, volta e variantes | Ida: âmbar contínuo. Volta: traço tracejado na cor do texto (forma, não só cor). Demais trajetos da linha: cinza esmaecido | Visual web |
| Terminais e pontos da linha | Início e fim do trajeto selecionado como círculos fortes; pontos **cadastrados** na linha como anéis (sem ordem de parada — legenda diz isso) | Testes + visual web |
| Voltar ao mapa normal | "Limpar trajeto" ou "Voltar às linhas" removem o trajeto e devolvem os pontos agrupados | Testes + visual web |
| Pontos gerais com trajeto aberto | Ficam ocultos enquanto há trajeto (só os anéis da linha), para o traço ficar legível | Testes + visual web |
| Meu ônibus — associação experimental | Ônibus acompanhado é associado a **um** trajeto oficial só se nome do itinerário, destino, posição e deslocamento concordarem (seção 4). Confirmado: percurso oficial em cinza + trecho à frente em âmbar tracejado, rotulado "estimado". Caso contrário: nada é desenhado e o painel explica o motivo | Testes de unidade e de widget; **não validado com ônibus real** |
| Rastreamento atual preservado | O rastro observado e o marcador continuam iguais; a associação só acrescenta camadas | Testes |
| Offline | Pontos, trajetos e associação usam só o catálogo embutido; o mapa base continua precisando de internet (como antes) | Testes |
| Textos pt/en/es | 24 chaves novas nos três ARB | `flutter gen-l10n` + teste de textos em en |
| Mapa central, sem abas novas | Tudo acontece no mapa e no painel/folha existentes | — |

---

## 2. Arquitetura

```text
data/cmtc/raw/LINHAS RMTC.kmz          (fora do Git)
   │ export_catalog.py: read_shapes → simplify(3 m) → encode_polyline(1e-5)
   ▼
app/dev_catalog/cmtc_catalog_payload.g.dart   (fora do Git; tabela "shapes")
   │ catalog_codec.dart → CatalogShape (polyline decodificada sob demanda)
   ▼
NetworkOverlayBuilder (domain/network_geojson.dart)
   │ monta 6 coleções GeoJSON, reaproveitando as que não mudaram (identidade)
   ▼
TransitMap (_syncNetwork) → só as coleções que mudaram vão ao nativo
   │ addNetworkLayers (network_map_layers.dart) recria tudo em cada estilo
   ▼
MapLibre: sources/layers nativos (nenhum widget Flutter por ponto)
```

Arquivos novos:

| Arquivo | Papel |
|---|---|
| `app/lib/src/features/catalog/domain/route_geometry.dart` | `decodePolyline`, `RouteLine` (projeção, trecho à frente, comprimento), `GeoBounds`, `fitZoom` |
| `app/lib/src/features/catalog/domain/network_geojson.dart` | Coleções GeoJSON (pontos, trajetos, terminais, pontos da linha, ponto selecionado, trajeto do ônibus), `MapFocus`, `NetworkOverlay`, `NetworkOverlayBuilder` |
| `app/lib/src/features/catalog/domain/route_match.dart` | Associação conservadora ônibus → trajeto oficial |
| `app/lib/src/features/transit/presentation/widgets/network_map_layers.dart` | Ids e criação das sources/layers nativas |

Alterados: `transit_catalog.dart` (`CatalogShape`, `shapesOf`), `catalog_codec.dart` (tabela `shapes`), `tracked_vehicle_map.dart` (`network`, `onStopTap`, sincronização e foco), `stop_arrivals_page.dart` (estado de trajeto/foco, associação, painel), `catalog_widgets.dart` (chips Ida/Volta, faixa "No mapa", legenda, `RouteMatchNote`), `home_chrome.dart` (logo oculto < 360 px), ARBs, pipeline (`geo.encode_polyline`).

**Separação produção × desenvolvimento**
- As camadas só existem quando `network != null`, e `network` só existe com catálogo (`context.catalog`), que só é carregado por `dev_catalog/main.dart` e nunca em release (`loadDevCatalog(releaseMode: kReleaseMode)`).
- `lib/main.dart` (produção) não importa o payload; a árvore de produção não contém a string do catálogo (verificado nos artefatos).
- Teste `sem a rede (produção): só as camadas de sempre` garante que o mapa de produção cria exatamente as 4 camadas anteriores.

**Desempenho (decisões)**
- Um único `GeojsonSource` com cluster nativo para todos os pontos; nenhum marcador/widget por ponto.
- Polylines decodificadas sob demanda (`late final`) — só a linha aberta paga o custo.
- O builder mantém a mesma instância de cada coleção enquanto a entrada não muda; `_syncNetwork` compara por identidade e envia ao nativo só o que mudou (teste "só o que mudou vai ao nativo").
- Troca de tema recria sources/layers uma vez por carga de estilo, sem duplicar (teste com controller simulado que falha em id repetido).
- O controller do mapa continua criado uma única vez (ADR‑0003), também ao trocar abas, tema e trajeto (teste).

---

## 3. Geometria e precisão

| Etapa | Valor |
|---|---|
| Fonte | `LINHAS RMTC.kmz` (geometria original preservada em `data/cmtc/raw/`, fora do Git) |
| Simplificação (só para desenho) | Douglas‑Peucker, tolerância **3 m** (`version.shapeToleranceM`) |
| Codificação | Google Encoded Polyline, precisão **1e‑5°** (~1,1 m) |
| Volume | 912 trajetos; payload total de desenvolvimento ≈ 1,44 MB |
| Erro máximo desenhado | ≤ ~4 m em relação ao KMZ (3 m + arredondamento) |

O comprimento (`lengthM`) e o número de vértices originais (`sourceVertices`) vêm da geometria **não simplificada**. A sequência de pontos da linha **não** é inferida: os anéis mostram pertencimento do cadastro, sem ordem, e a legenda diz isso.

Bug encontrado e corrigido: no Web (dart2js), operadores bit a bit são de 32 bits sem sinal, e o `~x` do decodificador clássico gerava longitudes como −166,98° (mapa "sumia" ao abrir um trajeto). A decodificação usa `-(x >> 1) - 1`; há teste com o texto exato gerado pelo exportador Python (`~xxdB~{{kHcBg^`).

---

## 4. Meu ônibus: associação ao trajeto oficial (experimental)

Regras, em ordem — qualquer falha encerra **sem desenhar nada**:

1. A linha (`routeId`) tem trajetos no catálogo (senão: *indisponível — sem trajetos*).
2. Há posição atual não expirada e o acompanhamento está ativo (senão: *indisponível — sem posição*).
3. O `routeName` da RMTC é igual (palavras normalizadas, ≥ 3 letras, sem "terminal") à DENOMINAÇÃO de **exatamente uma** variante (senão: *ambíguo*).
4. O destino aponta um sentido: casa com o último trecho da denominação → ida; com o primeiro → volta; com nenhum trecho → *ambíguo*. **Desde a Etapa E (28/10/2026):** se casa só com um trecho do meio (ex.: "ST AEROPORTO" em "T. Cruzeiro / St. Aeroporto / Eixo T-8", linha 016) ou com os dois extremos, decide o deslocamento: confirma só se, entre ida e volta, exatamente um sentido é coerente com as posições observadas e já avançou 20 m; os dois coerentes depois de andar → *ambíguo*.
5. Existe exatamente um trajeto dessa variante nesse sentido.
6. Posição atual e rastro observado a até **50 m** do trajeto (senão: *ambíguo — fora do trajeto*).
7. Rastro avança ≥ **20 m** no sentido do trajeto, sem recuar mais de 15 m entre amostras (senão: *pendente — aguardando deslocamento* ou *ambíguo — andando no sentido contrário*).

Só no nível **confirmado** aparecem: o percurso oficial inteiro (cinza) e o trecho à frente (âmbar tracejado), sempre com o texto "estimado". **Nenhum ETA nem "próxima parada" é inventado.** O rastro observado continua sendo desenhado como antes, independentemente da associação.

Limitação: a regra foi validada com dados sintéticos (testes); ainda não foi observada com um ônibus real em circulação. Espera-se muitos casos "ambíguo" no início (nomes da RMTC diferentes da denominação do cadastro) — esse é o comportamento desejado até haver mais evidência.

---

## 5. Testes

| Suíte | Conteúdo |
|---|---|
| `test/features/catalog/network_test.dart` (23) | Polyline (vetor de referência, vetor do exportador, ida e volta), projeção/trecho, `fitZoom`, shapes no catálogo, GeoJSON das camadas, reaproveitamento do builder, associação (confirmado, volta, 6 recusas, pendente, sem posição/sem trajeto, só confirmado vira camada), desempenho com 7,5 mil pontos e 900 trajetos |
| `test/features/catalog/network_map_test.dart` (8) | Camadas com/sem rede (produção), troca de tema sem duplicar, só o que mudou vai ao nativo, foco (um movimento por pedido; pendente até o estilo), toque em ponto/grupo, trajeto do ônibus isolado |
| `test/features/catalog/catalog_map_ui_test.dart` | Toque no ponto → painel e destaque; foco pela busca; linha: ida → volta → variante → limpar → voltar; linha sem trajeto; Meu ônibus confirmado e recusado; tema/abas sem recriar o mapa; sem overflow em 320 px 100 %, 390 px 200 %, 1024 px 130 % |
| `test/features/catalog/catalog_ui_test.dart` | Atualizado para os chips Ida/Volta |
| `data/cmtc/pipeline/tests` (28) | + `PolylineEncoding` (vetor do algoritmo do Google) |

Medições (`network_test`, máquina local): decodificar 900 trajetos ≈ 75–102 ms; GeoJSON de 7,5 mil pontos ≈ 5–9 ms; 50 trocas de trajeto ≈ 0,5–0,9 s (≈ 10–18 ms cada).

Resultados finais: **552/552** testes Flutter, `flutter analyze` sem problemas, `dart format` sem mudanças (exceto o payload gerado, fora do Git), pipeline **28/28**.

---

## 6. Builds e separação de dados

| Build | Resultado | Catálogo no artefato |
|---|---|---|
| Web produção (`flutter build web --release`) | OK, `main.dart.js` 3.725.208 bytes | **Ausente** (`check-no-official-catalog.sh` OK) |
| Web desenvolvimento (profile, `-t dev_catalog/main.dart`) | OK | Presente (controle positivo) |
| Android produção (release APK, Flutter 3.38.5) | OK, 86,0 MB | **Ausente** (verificador OK) |
| Android desenvolvimento (profile APK, `-t dev_catalog/main.dart`) | OK, 151,2 MB | Presente (controle positivo) |
| iOS produção (release, `--no-codesign`, Flutter master) | OK, 29,2 MB | **Ausente** (verificador OK) |
| iOS desenvolvimento (profile, `-t dev_catalog/main.dart`) | OK, 41,2 MB | Presente (controle positivo) |

O verificador (`app/scripts/check-no-official-catalog.sh`) procura os marcadores do payload em UTF‑8 e UTF‑16LE, inclusive dentro de APK/zip. Os controles positivos provam que ele detectaria o catálogo se vazasse.

---

## 7. Validação visual (Web dev, painel do navegador)

- **Celular 375×812, tema escuro:** grupos com contagem, toque em grupo aproxima, toque em ponto abre o painel com halo; linha 003 → trajeto ida enquadrado acima da folha, pontos gerais ocultos, terminais e anéis; Volta → traço tracejado claro, ida esmaecida.
- **Tablet 768×1024:** painel em coluna central. Problema encontrado: com o painel alto, o trajeto era enquadrado numa faixa mínima. Correção: com trajeto aberto, o painel ocupa no máximo a metade de baixo e o enquadramento espera o novo layout; no celular, a folha expandida desce para o meio antes de enquadrar. Revalidado.
- **Ajuste de legibilidade:** anéis dos pontos da linha escondiam o traço em zoom de cidade; o raio agora cresce com o zoom (1,5 px no zoom 11 → 5 px no 15).
- **Tema claro:** sources/layers recriados no novo estilo, sem erros no console.
- Memória (Web dev, 375×812): heap JS ≈ 61 MB usado / 72 MB total.

Observações do ambiente: com o painel do navegador oculto, a página roda em segundo plano e o MapLibre não desenha (não é bug do app). O texto dos grupos usa a fonte "Noto Sans Bold" do estilo online; sem internet, o mapa base já não carrega.

---

## 8. Riscos e limitações

1. **Licença** — nada disto pode ir para produção antes da definição de redistribuição da CMTC.
2. **Associação do ônibus** — validada só em testes; precisa de observação com ônibus reais antes de qualquer uso público.
3. **Sentido por destino** — depende do texto do destino da RMTC casar com um extremo da denominação; linhas circulares ou com extremos de nomes parecidos ficam "ambíguas".
4. **Pontos da linha** — sem ordem nem sentido no cadastro; não há "próxima parada".
5. **Trajetos só do KMZ** — linhas com trajeto mas sem variante equivalente no cadastro aparecem numa seção separada ("só no KMZ").
6. **iOS** — o ambiente local só compila iOS com o Flutter master (3.38.5 + Xcode 27.1 falha); o CI é a referência.
7. **Tamanho** — o payload de desenvolvimento passou de ~1 MB para ~1,44 MB por causa dos trajetos.

## 9. Próximo passo sugerido

Rodar o build de desenvolvimento num aparelho Android/iOS real, acompanhar ônibus de 3–5 linhas e registrar quantas associações saem "confirmado" × "ambíguo" e por qual motivo, para calibrar as regras (sem relaxá-las às cegas).
