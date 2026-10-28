# BusãoGyn 2.0 — Fase 2: catálogo oficial de linhas e pontos (desenvolvimento)

- **Data:** 27/10/2026
- **Status:** implementado e validado **só em desenvolvimento**. Produção continua idêntica, sem catálogo.
- **Motivo da restrição:** a CMTC forneceu os dados (Ofício 728/2026, Parecer 226/2026), mas não definiu condições de redistribuição (`CMTC_2026_INVENTARIO_DADOS.md` §1). Além disso, **o repositório no GitHub é público**: nenhum dado oficial nem derivado pode ser versionado.

---

## 1. O que o passageiro consegue fazer (com o catálogo ligado)

| Requisito | Como funciona |
|---|---|
| Pesquisar ponto por código, endereço ou nome | Campo da aba Pontos aceita texto ("Código, rua, bairro ou cidade"); resultados aparecem enquanto digita |
| Encontrar pontos por bairro e município | Mesma busca; todas as palavras precisam casar, em logradouro, referência, bairro ou município |
| Ver nome e endereço do ponto | Detalhe do ponto: endereço (logradouro + referência), bairro, município |
| Ver linhas oficialmente associadas | Placas "Linhas que atendem este ponto", com o aviso de que são do cadastro e não indicam ônibus a caminho |
| Pesquisar linhas por número ou nome | Aba Linhas: busca por `3`/`003`/`NS1`, nome, terminais e município |
| Ver detalhes da linha e das variantes | Situação, tipo/forma, municípios; variantes com código, característica, situação, vigência, origem e destino; pontos associados (sem ordem nem sentido) |
| Abrir um ponto e consultar chegadas | "Ver chegadas" usa o fluxo e a API existentes (`/v1/stops/{id}/arrivals`); os dados oficiais ficam acima das chegadas |
| Usar busca e catálogo sem internet | Catálogo embutido no binário de desenvolvimento; busca, detalhes e linhas são 100% locais |
| Sem regressões | Com o catálogo desligado, nada muda (460 testes anteriores passam sem alteração) |

Também foi feito:
- **Favoritos e recentes** exibem o endereço do cadastro ("Ponto 280 · Bueno, Goiânia" + "Avenida T‑63 — Mc Donalds"). O armazenamento não muda: nenhum nome é gravado e nenhum favorito é alterado (testado).
- **Ajustes** mostra versão, referência e "redistribuição: pendente".

---

## 2. Arquitetura

```text
data/cmtc/raw/ (originais, fora do Git)
     │  python3 -I data/cmtc/pipeline/export_catalog.py
     ▼
app/dev_catalog/                      ← fora do Git (/dev_catalog/ em app/.gitignore)
  ├─ cmtc_catalog_payload.g.dart      const String cmtcCatalogJson = r'''{…}''' (~1 MB)
  └─ main.dart                        runBusaoGyn(devCatalogJson: cmtcCatalogJson)

app/lib/main.dart  ── runBusaoGyn()              (PRODUÇÃO: sem catálogo)
app/lib/src/bootstrap.dart
  loadDevCatalog(json, releaseMode: kReleaseMode)  → null em release, sem payload ou payload inválido
        │
BusaoGynApp(catalog: TransitCatalog?)  → RepositoryProvider<CatalogAccess>
        │
features/catalog/
  data/catalog_codec.dart        decodifica `busaogyn.catalog` v1 (tolerante, por nome de campo)
  domain/transit_catalog.dart    modelos + índices + busca + relação ponto↔linha
  domain/text_search.dart        normalização (acentos, caixa, abreviações) e caixa de leitura
  presentation/catalog_access.dart   context.catalog (null = desligado)
  presentation/catalog_widgets.dart  resultados, detalhe do ponto, resumo, aba Linhas
```

### Por que um entrypoint gerado e não um asset ou uma flag
- **Assets** declarados no `pubspec.yaml` vão para todos os builds e plataformas, e o Flutter não condiciona asset a `--dart-define`. Um asset local esquecido seria empacotado num release.
- **Flavors** não funcionam no Web e exigiriam mexer em configuração de publicação no Xcode e no Gradle.
- **Entrypoint gerado:** o `lib/main.dart` de produção nunca importa `dev_catalog/`. O tree‑shaking do compilador garante que o payload não entra no binário, mesmo que o arquivo exista na máquina de quem compila. Isso foi comprovado com builds reais (§6).
- **Segunda trava:** `loadDevCatalog` devolve `null` em `kReleaseMode`, mesmo que alguém compile o entrypoint de dev em release.

### Camada de catálogo
- **Modelos:** `CatalogVersion` (id, fonte, referências de linhas e pontos, `licenseStatus`, `restricted`), `CatalogLine` (base: `003`, `NS1`, `MGP-07`), `CatalogVariant` (`003-1`…), `CatalogStop` (PED, ou estação/ponto só do KMZ), relação ponto→linha (`lineIds`) e linha→pontos (índice).
- **Códigos** sempre como texto. A linha usa a mesma normalização da API (1–3 dígitos → 3 dígitos). Pontos mantêm zeros à esquerda (`00294` ≠ `294`).
- **Busca de pontos:** todas as palavras precisam casar como prefixo de alguma palavra do ponto.
  - Pesos: logradouro 4, referência e bairro 3, município 1; palavra exata vale o dobro.
  - Código exato vale 10.000; prefixo de código vale 5.000.
  - Abreviações: `pça`/`pca`/`pc`→praça, `jd`→jardim, `st`→setor, `vl`→vila, `pq`→parque, `rod`→rodovia, `res`→residencial, `term`→terminal.
  - Sem duplicidade, porque cada ponto é avaliado uma vez.
- **Busca de linhas:** número (com ou sem zeros); depois nome e nomes das variantes (peso maior); depois origem, destino e municípios.
- **Desempenho:** cerca de 7,5 mil pontos varridos em memória. O teste com 7,5 mil pontos sintéticos faz 50 buscas bem abaixo do limite de 3 s. No browser, a busca é instantânea ao digitar.

---

## 3. Formato do catálogo (`busaogyn.catalog` v1)

```json
{
  "format": "busaogyn.catalog", "formatVersion": 1,
  "version": { "id": "cmtc-2026-10", "marker": "busaogyn-cmtc-payload", "generatedAt": "…",
               "source": "CMTC — Ofício nº 728/2026 e Parecer nº 226/2026 (resposta LAI)",
               "referenceDates": {"lines": "2026-09-01", "stops": "2026-10"},
               "licenseStatus": "pendente", "restricted": true, "files": {"<arquivo>": "<sha256>"} },
  "lines":    {"fields": ["id","name","type","form","areas","cities"], "rows": [[…], …]},
  "variants": {"fields": ["id","line","code","name","characteristic","status","origin","destination","city","validFrom","company1","company2"], "rows": […]},
  "stops":    {"fields": ["id","kind","streetType","street","reference","district","city","lat","lon","lines","label"], "rows": […]}
}
```

- Leitura **por nome de campo**: colunas novas ou reordenadas não quebram o app (testado).
- Formato ou versão desconhecidos → `CatalogFormatException` → catálogo desligado, e o app segue como antes.
- `restricted` ausente → tratado como restrito.
- Valores "vazios" do cadastro (`-`, `0`, `.`) viram ausência. Antes apareciam como "Avenida Anhanguera — -".
- Só dados **oficiais**: cadastro de linhas, cadastro de pontos e KMZ de pontos. Nada inferido (nem sequência, nem sentido, nem trajeto).
- Conteúdo atual: 313 linhas, 426 variantes, 7.480 pontos (7.350 do cadastro e 130 só do KMZ, incluindo estações 40000+). O payload tem 1,0 MB de JSON.

---

## 4. Estratégia offline e estados

| Situação | O que aparece |
|---|---|
| Busca, detalhe do ponto, aba Linhas | funcionam sem rede; rodapé "Cadastro oficial CMTC · referência 2026‑10 · disponível offline · Dados de desenvolvimento, não publicados" |
| "Ver chegadas" sem rede | fluxo existente: aviso "Sem conexão" + "Tentar de novo"; **nenhuma previsão antiga é mostrada** (sem cache de chegadas, como antes) |
| Código fora do cadastro | "Este código não está no cadastro oficial. A consulta de chegadas pode funcionar mesmo assim." A consulta segue liberada, porque a API conhece códigos que o cadastro não tem (ex.: `30402`) |
| Estação sem endereço | "Estação sem endereço no cadastro" + nome do KMZ |
| Nenhum resultado | "Nenhum ponto encontrado" + dica |
| Linhas cadastradas × chegadas | blocos separados: "Linhas que atendem este ponto" (cadastro, placas neutras) acima de "Próximos ônibus" (API, com selos **Tempo real** e **Programado** já existentes) |
| Mapa e rastreamento | inalterados (invariantes do ADR‑0003 preservados; nenhum arquivo do mapa ou dos Cubits de tempo real foi alterado) |

---

## 5. Interface e fluxos

- **Pontos:** digitar → lista (endereço, código · bairro, município, placas) → tocar → **detalhe** (cabeçalho "Ponto N · bairro, município", fechar volta à busca) → "Ver chegadas" ou estrela de favorito → chegadas com o resumo oficial acima.
- Digitar só números e tocar em "Buscar" consulta as chegadas direto, como antes. Texto + "Buscar" não chama a API: o texto nunca sai do aparelho.
- **Linhas:** busca no topo, linhas favoritas como atalhos (chips "042 · 1201"), lista paginada (60 por vez), detalhe com "Voltar às linhas". Tocar num ponto da linha abre o detalhe na aba Pontos. A linha aberta e a busca sobrevivem à troca de aba.
- **Nenhuma aba nova.** Identidade visual mantida (tokens existentes: âmbar/escuro, `RoutePlate`, `SectionLabel`, `FootNote`).
- **Intro da aba Pontos** com o catálogo ligado: "Busque um ponto — pelo código da placa, pela rua, pelo bairro ou pela cidade".
- **Idiomas:** 43 textos novos em pt, en e es.

### Correções encontradas durante a fase
1. **Bug de produção pré‑existente corrigido:** em português, `linesCount(0)` mostrava **"1 linha"** e `minutesLong(0)` "1 minuto". O gen‑l10n mapeia `=1` para a categoria `one`, e o CLDR pt põe o 0 em `one`. Adicionada a forma `=0` em todos os plurais (pt/en/es), com teste que exige `=0` em todo plural novo.
2. Ordem dos parâmetros de `settingsCatalogBody`: o gen‑l10n ordena em ordem alfabética, e a versão saía no lugar da licença. Pego por teste e corrigido.
3. `RoutePlate` dentro de `Wrap` ocupava a linha inteira (corrigido com `IntrinsicWidth`, sem mudar o componente compartilhado).

---

## 6. Testes e builds

### Testes automatizados (Flutter 3.38.5, a versão do CI)
| Suíte | Resultado |
|---|---|
| Total | **511/511** (460 anteriores + 51 novos) |
| `test/features/catalog/catalog_test.dart` | 28: normalização, códigos com zeros, decodificação tolerante, colunas reordenadas, busca por código/logradouro/bairro/município/sem acento, pesos, estações, desempenho com 7,5 mil pontos, linhas por número/nome/terminal, relação ponto‑linha, endereço de exibição, traço como ausência, bootstrap desligado em release |
| `test/features/catalog/catalog_ui_test.dart` | 16: catálogo desligado (dígitos e "linhas vistas" como antes), busca local sem API, bairro/município, detalhe offline → chegadas, código digitado, código fora do cadastro, favoritar guarda só o código, favoritos e recentes enriquecidos sem gravação, aba Linhas completa, Ajustes, 4 tamanhos/escalas de fonte sem overflow (320 px a 1366 px, 100% a 200%), en e es |
| `test/core/catalog_separation_test.dart` | 5: nada em `lib/` importa `dev_catalog`, nenhuma marca do payload no código, `main.dart` de produção sem catálogo, nenhum asset de catálogo no `pubspec`, `.gitignore` cobre `dev_catalog/` e `data/cmtc/{raw,processed,reports}`, guarda de release no bootstrap |
| `test/core/l10n_test.dart` | +2: plurais com zero e exigência de `=0` |

`flutter analyze`: sem problemas. `dart format`: aplicado.

### Verificação dos artefatos (`app/scripts/check-no-official-catalog.sh`)
Procura marcas que só existem no payload (`busaogyn-cmtc-payload`, `cmtc-2026-10`, `"stops":{"fields"` e a forma escapada), **em UTF‑8 e em UTF‑16LE**. Abre `.apk`, `.aab`, `.ipa`, `.zip` e pastas.

> A primeira versão do script usava `grep` e dava **falso negativo** em binários AOT: o Dart guarda strings não ASCII (o payload tem "Goiânia") em UTF‑16 no `libapp.so`/`App.framework`. Isso foi descoberto pelo controle positivo e corrigido. Os controles positivos abaixo provam que o script enxerga o catálogo em cada formato.

| Plataforma | Build | Entrypoint | Esperado | Resultado |
|---|---|---|---|---|
| Web | release | `lib/main.dart` | sem catálogo | **OK** (main.dart.js 3,7 MB) |
| Web | profile | `dev_catalog/main.dart` | com catálogo (controle) | encontrado em `main.dart.js` (12,2 MB) |
| Android | **release** (86,0 MB) | `lib/main.dart` | sem catálogo | **OK** |
| Android | debug | `dev_catalog/main.dart` | com catálogo (controle) | encontrado em `kernel_blob.bin` |
| Android | profile AOT | `dev_catalog/main.dart` | com catálogo (controle) | encontrado em `libapp.so` (UTF‑16) |
| iOS | **release** no‑codesign (29,2 MB) | `lib/main.dart` | sem catálogo | **OK** |
| iOS | profile no‑codesign (40,3 MB) | `dev_catalog/main.dart` | com catálogo (controle) | encontrado em `App.framework/App` (UTF‑16) |
| iOS | release no‑codesign | `dev_catalog/main.dart` | — | **sem catálogo**: em release o compilador elimina o payload como código morto, porque `kReleaseMode` é constante e `loadDevCatalog` devolve `null`. É a terceira trava, comprovada no binário |

**Ambiente dos builds nativos (máquina local):**
- **Android:** o `~/.gradle/gradle.properties` global do usuário fixa `org.gradle.java.home` no JDK 17, mas o `maplibre_gl 0.27.1` exige Java 21. Os builds rodaram com `GRADLE_OPTS=-Dorg.gradle.java.home=<JDK 21>` (OpenJDK 21 instalado via Homebrew), sem alterar o arquivo global. O CI já usa Java 21.
- O release Android foi assinado com a configuração local `android/key.properties` (fora do Git). O artefato ficou só na máquina: nada foi publicado.
- **iOS:** com o Flutter 3.38.5 (CI) + Xcode 27.1 local, o build falha ("Flutter.framework does not contain architectures arm64 x86_64"). Os builds iOS acima usaram o Flutter master local (3.50‑pre). O **simulador** falha também no master pelo mesmo motivo de arquitetura, então a validação visual foi feita no Web (§ abaixo) e pelos testes de widget. O CI usa outro Xcode e não foi afetado por nada desta fase.
- Os builds reescrevem `pubspec.lock`, `Podfile.lock` e `project.pbxproj`, que já estavam modificados antes desta fase. Os três foram restaurados byte a byte a partir de cópia.

### Validação visual (build de dev no navegador embutido, dados reais)
- 375×812: busca "t‑63 bueno" → 3 pontos; detalhe do PED 280 (Avenida T‑63 — Mc Donalds, Bueno, Goiânia, 8 linhas); "Ver chegadas" → **5 linhas com previsão em tempo real** da API de produção, abaixo das 8 linhas do cadastro, com ônibus no mapa.
- Aba Linhas: "313 linhas no cadastro oficial"; detalhe da 003 com 4 variantes (origem/destino, vigência), 98 pontos.
- 768×1024: coluna central, sem cortes.
- Isso gerou **1 consulta real** de chegadas (PED 280), pela API própria, com cache.

---

## 7. Como habilitar em desenvolvimento

```bash
cd data/cmtc && python3 -I pipeline/export_catalog.py
```
```bash
cd app && flutter run -t dev_catalog/main.dart
```

No Web: `flutter run -d chrome -t dev_catalog/main.dart`. Para compilar: `flutter build web --profile -t dev_catalog/main.dart --output build/web_dev_catalog`. Requer os originais em `data/cmtc/raw/` (fora do Git).

## 8. Como garantir que continue desligado em produção

1. Builds de produção usam o entrypoint padrão (`lib/main.dart`). Os workflows (`flutter-ci.yml`, `deploy-web.yml`) não passam `-t`, e nenhum foi alterado.
2. `lib/main.dart` não importa `dev_catalog/`. O teste `catalog_separation_test.dart` falha se isso mudar.
3. Mesmo compilado em release, o entrypoint de dev não liga o catálogo (`kReleaseMode`).
4. `app/dev_catalog/` e `data/cmtc/{raw,processed,reports}/` estão no `.gitignore`. Antes de qualquer commit: `git status` não deve listar nada disso.
5. Antes de publicar qualquer build: `bash app/scripts/check-no-official-catalog.sh <artefato>` (pasta `build/web`, `.apk`, `.aab` ou `.ipa`).
6. Liberar em produção exige: autorização registrada (ADR‑0002 item 6), decidir onde o catálogo mora (asset empacotado ou download) e remover esta trava de forma consciente, num ADR novo.

---

## 9. Limitações conhecidas
- **Desenvolvimento apenas:** nada disto chega ao usuário final até a licença ser resolvida.
- O catálogo de dev é embutido no binário (~1 MB a mais no JS do Web de dev; +~0,6 MB gzip). Para produção, recomendo asset/download versionado (`BUSAOGYN_2_0_PLANO_INTEGRACAO.md`).
- Sem horários programados, trajetos, sentido, sequência de paradas ou pontos no mapa nesta fase (decisão do escopo e do ADR‑0002).
- Estações do Eixo/BRT (40000+) não têm linhas associadas no cadastro: aparecem pelo código e pelo nome, mas sem placas.
- Busca por prefixo: erros de digitação não são tolerados (sem busca aproximada).
- O ponto `30402` (exemplo do app, plataforma de terminal) não está no cadastro; o app avisa e consulta normalmente.
- Automação de digitação no Flutter Web pelo navegador embutido é instável (texto duplicado); não afeta o app, só a validação automatizada.
