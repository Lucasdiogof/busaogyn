# BusãoGyn 2.0 — Etapa E: auditoria de publicação, conformidade e readiness

- **Data:** 28/10/2026 · **Branch:** `feat/ux-redesign` (base `97410f5`)
- **Escopo:** preparar a publicação sem publicar: sem merge na `main`, sem deploy, sem envio às lojas, sem dados da CMTC em artefato público.
- **Evidência:** cada afirmação abaixo diz de onde veio: teste automatizado, navegador, simulador/emulador ou aparelho físico. **Nenhum aparelho físico foi usado nesta etapa.**

## 1. Resultado da auditoria (resumo)

| Área | Situação |
| --- | --- |
| Separação produção × desenvolvimento | **Pronto.** Verificada nos artefatos, no runtime e no CI (seção 3) |
| Android público atual | **Pronto com ressalvas** técnicas; publicação depende de ações externas (chave, Play Console, formulários) |
| iOS público atual | **Pronto com ressalvas** depois da correção da política dentro do app (era bloqueador da App Store) |
| Web público atual | **Pronto com ressalvas**; o site no ar é uma versão antiga (`2d4df69`) e a nova exige deploy autorizado |
| 2.0 completo (Android, iOS, Web) | **Bloqueado** pela licença da CMTC; tecnicamente funcional só em desenvolvimento |
| Privacidade | **Pronto com ressalvas**: textos corretos para a produção; propostas para a política pública (seção 7) |
| CI e segurança de release | **Pronto**: novos verificadores de catálogo com controle positivo; deploy só manual |
| Desempenho | **Pronto com ressalvas**: bom em release; risco de capacidade da API gratuita (seção 10) |

Problemas encontrados e corrigidos nesta etapa: E-1 a E-6 (seção 2). Testes automatizados passam, mas **não substituem** o teste em aparelho real, VoiceOver e TalkBack com uso humano (seção 9).

## 2. Problemas encontrados

| # | Gravidade | Problema | Evidência | Situação |
| --- | --- | --- | --- | --- |
| E-1 | P0 (App Store) | O app não tinha acesso à **política de privacidade dentro dele**. A diretriz 5.1.1(i) da Apple exige o link nos metadados **e** dentro do app | Busca no código: nenhuma tela ou texto de privacidade | **Corrigido**: Ajustes → Privacidade (resumo + link da política completa, copiável). Teste novo; verificado no simulador de iPad |
| E-2 | P1 | Web de desktop: **Compartilhar não respondia**. Sem Web Share, o plugin tentava abrir um e-mail (`mailto:`), e a cópia falhava sem tratamento (`Uncaught Error`), sem aviso | Navegador (console) | **Corrigido**: sem fallback de e-mail; cópia com tratamento de erro e aviso "Não foi possível compartilhar…". Teste de regressão com falha comprovada sem a correção |
| E-3 | P1 (Play) | O app não dizia que é **independente**. A política da Google Play para apps com informação de órgão público exige essa declaração | Ajustes só dizia "RMTC, via API BusãoGyn" | **Corrigido**: "App independente, sem vínculo com a RMTC, a CMTC ou a Prefeitura" (pt/en/es), com teste. A ficha da loja também precisa dizer isso (seção 5.2) |
| E-4 | P2 | A fonte devolvia **o mesmo ônibus como próximo e seguinte** (mesmo veículo, mesmo horário), e o app mostrava "Seguinte" duplicado | API real, ponto 30402, linha 003; emulador e TalkBack liam duas vezes | **Corrigido** na leitura do app (`ArrivalGroup.fromJson`): o "seguinte" idêntico ao "próximo" é descartado. O mesmo ônibus em outro horário continua. Teste novo. API inalterada |
| E-5 | P3 | Ícone de compartilhar do **iOS também no Android** | Emulador Android | **Corrigido**: `Icons.adaptive.share` (glifo nativo em cada plataforma) |
| E-6 | P2 (CI) | O CI não rodava o **verificador de catálogo** nos artefatos; o deploy Web usava outro Flutter (3.47.4, sem `--enforce-lockfile`) e fazia smoke num endereço morto | Leitura dos workflows; `workers.dev` responde 404/1042 | **Corrigido** (seção 8) |
| E-7 | Info | O site publicado carrega um **script de verificação anti-robô da Cloudflare** (`/cdn-cgi/challenge-platform`) não citado na política | `curl` em `busaogyn.lucksrei.com/privacidade` | Política do repositório atualizada; proposta para a política pública (seção 7) |
| E-8 | Risco | **Capacidade da API gratuita**: cerca de 16 requisições por minuto por pessoa parada num ponto com ônibus ao vivo | Medição no Web de produção (seção 10) | Documentado; decisão antes de divulgar amplamente |
| E-9 | Info | A **última execução do CI na `main`** (`afdad14`) falhou no APK release. A `feat/ux-redesign` contém esse commit e passa | API do GitHub | Resolve-se com o merge, quando autorizado |

## 3. Separação entre produção e desenvolvimento (verificada na prática)

| Verificação | Como | Resultado |
| --- | --- | --- |
| Artefatos de produção sem catálogo | `check-no-official-catalog.sh` em Web, APK, AAB e `Runner.app` (Flutter 3.38.5) | OK nos quatro |
| Controle positivo | O mesmo verificador no Web e no APK de desenvolvimento | Acusa as marcas do payload (rc=1), como esperado |
| Site publicado | `main.dart.js` baixado de `busaogyn.lucksrei.com` | OK, sem catálogo |
| Runtime de produção (navegador) | Web release servido localmente | 3 abas (Pontos, Linhas, Salvos), sem Planejar, sem busca por texto, sem "Perto de mim" |
| Runtime de desenvolvimento (navegador) | Web profile com `dev_catalog` | 4 abas, 313 linhas, planejador, "Perto de mim" |
| Permissões Android release | `aapt2 dump permissions` | INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE e a permissão interna do app; nenhuma localização |
| Código | `test/core/catalog_separation_test.dart` | `lib/` não importa `dev_catalog`; release recusa o catálogo (`bootstrap.dart`) |
| Git | Novo passo do CI (`git ls-files`) | Nenhum arquivo de `app/dev_catalog` ou `data/cmtc/raw|processed|reports` versionado |

As capturas do build de desenvolvimento desta etapa mostram dados da CMTC e **ficaram só na máquina local**.

## 4. Matriz de funcionalidades por build

Legenda: ✅ sim · — não se aplica. "Pronta" = pode ir para a loja assim que as ações externas forem feitas.

| Funcionalidade | Produção atual | Só em desenvolvimento | Depende de autorização CMTC | Depende de validação técnica | Pronta para lançamento |
| --- | --- | --- | --- | --- | --- |
| Chegadas por código do ponto | ✅ | — | — | Aparelho físico | ✅ com ressalva |
| Acompanhar um ônibus (posição ao vivo) | ✅ | — | — | Aparelho físico | ✅ com ressalva |
| Outros ônibus ao vivo no mapa | ✅ | — | — | Capacidade da API (E-8) | ✅ com ressalva |
| Favoritos, linhas favoritas, recentes | ✅ | — | — | — | ✅ |
| Aba Linhas (linhas já vistas) | ✅ | — | — | — | ✅ |
| Compartilhar ponto | ✅ | — | — | Folha nativa em aparelho | ✅ |
| Ajustes (tema, privacidade, licenças) | ✅ | — | — | — | ✅ |
| Falha de rede, offline, retry | ✅ | — | — | — | ✅ |
| Busca por rua, bairro, cidade | — | ✅ | ✅ | — | Bloqueada |
| Catálogo de linhas e trajetos no mapa | — | ✅ | ✅ | — | Bloqueada |
| Horários por ponto | — | ✅ | ✅ | Vigência e calendário oficiais | Bloqueada |
| Sequência de paradas | — | ✅ | ✅ | Sequência oficial (hoje inferida) | Bloqueada |
| Estações e terminais | — | ✅ | ✅ | — | Bloqueada |
| Planejador de viagens | — | ✅ | ✅ | Estimativa, não itinerário oficial | Bloqueada |
| Perto de mim (localização) | — | ✅ | ✅ (usa o catálogo) | Permissões, formulários das lojas | Bloqueada |
| Viagens salvas, compartilhar linha/viagem | — | ✅ | ✅ | — | Bloqueada |

## 5. Lojas

### 5.1 Apple App Store

| Item | Situação | Evidência |
| --- | --- | --- |
| Bundle ID | `com.lucksrei.busaogyn` | `Info.plist` do `Runner.app` release |
| Versão / build | `1.0.0` (`1`). **O build precisa ser maior que o último enviado**; a Apple já revisou capturas do app, então provavelmente já houve envio. Usar `flutter build ipa --build-number=<N>` | Info.plist |
| Assinatura | Fora do repositório (Team no Xcode). Release sem assinatura compila | `flutter build ios --release --no-codesign` |
| Deployment target | iOS 15.0 | `MinimumOSVersion` |
| Ciclo de vida | UIScene já adotado (`FlutterSceneDelegate`, `FlutterImplicitEngineDelegate`) | `Info.plist`, `AppDelegate.swift` |
| Criptografia | `ITSAppUsesNonExemptEncryption = false` (só HTTPS do sistema) | Info.plist |
| Localização | `NSLocationWhenInUseUsageDescription` presente (o arquivo é o mesmo do build de desenvolvimento). **A produção nunca pede a permissão** | Código; Info.plist |
| Privacy manifests | Flutter, MapLibre, `shared_preferences_foundation`, `share_plus`, `geolocator_apple`, `package_info_plus`: todos dentro do `Runner.app` | Inspeção do bundle |
| SDKs de terceiros | Sem analytics, anúncios, crash reporting ou login | Dependências |
| iPhone e iPad | iPad Air 11" (simulador): painel lateral, mapa, Ajustes, Privacidade, retrato e paisagem OK. iPhone: Etapa D | Simulador |
| Política dentro do app | **Corrigido (E-1)** | Teste + simulador |
| Conteúdo de terceiros | Mapa OpenFreeMap/OpenStreetMap com atribuição visível; dados RMTC via API própria; declaração de app independente (E-3) | Ajustes |
| Capturas | Só na Etapa F, **tiradas de build iOS em simulador ou aparelho iOS**, nunca do Android ou do Web; barra de status e teclado do iOS; ícone de compartilhar já é o do iOS | Regra da Etapa F |

**Respostas derivadas do comportamento comprovado:**

- Privacidade do app: **Data Not Collected**; Tracking: **não**. O código do ponto e o número do ônibus saem do aparelho só para atender a consulta pedida, sem conta nem identificador, e não ficam associados a uma pessoa.
- Classificação etária: sem conteúdo sensível (questionário da Apple; esperado 4+).
- Categoria: Navegação (ou Viagem).

**Riscos conhecidos de rejeição e mitigação:**

| Diretriz | Risco | Mitigação |
| --- | --- | --- |
| 2.3.3 / 2.3.10 (capturas) | Já houve questionamento: capturas que não mostravam a interface iOS | Etapa F só com capturas de build iOS, iPhone 6.9" e iPad 13" |
| 5.1.1(i) (política) | Faltava dentro do app | Corrigido (E-1) |
| 2.1 (completude) | Se a RMTC estiver fora do ar na revisão, o app parece quebrado | Notas para a revisão com o ponto 30402 e a explicação de que só ônibus com GPS aparecem |
| 5.1.1 (propósito de permissão) | A frase de localização existe, mas a produção não pede | Risco baixo; se perguntarem, explicar que o recurso não está nesta versão |
| 4.1 / 5.2 (vínculo com órgão público) | Parecer app oficial da RMTC | Declaração de independência (E-3) e nada de logotipo oficial |

### 5.2 Google Play

| Item | Situação | Evidência |
| --- | --- | --- |
| Application ID | `com.lucksrei.busaogyn` | `aapt2 dump badging` |
| versionCode / versionName | `1` / `1.0.0`. **Precisa ser maior que qualquer upload anterior** (`--build-number`) | badging |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36. Atende ao requisito de target 35+ | badging |
| Permissões | Só rede (seção 3). No Android 17, o sistema acrescenta `ACCESS_LOCAL_NETWORK` por compatibilidade; não está no APK | `aapt2`, `dumpsys package` no emulador |
| Componentes | Só a `MainActivity` exportada; `ShareFileProvider`, `SharePlusPendingIntent`, `InitializationProvider`, `ProfileInstallReceiver` (bibliotecas) | Manifesto do APK |
| Páginas de 16 KB | OK | `tool/check_android_release.py` |
| Assinatura | Upload key fora do repositório; sem ela o release falha (protegido no CI) | `build.gradle.kts` |
| Compatibilidade | Android 7 (API 24) ou mais novo; emulador Android 17 OK | Emulador |

**Segurança dos dados (derivada do app e das dependências):** nenhum dado coletado e nenhum compartilhado. Os códigos de ponto e os números de ônibus são processados de forma efêmera para atender a consulta. Criptografia em trânsito: sim. Exclusão de conta: não se aplica (não há conta). `play-services-location` (do `geolocator_android`) está no binário, mas o release não declara localização nem a usa.

**Política de órgão governamental:** a ficha precisa dizer que o app é independente e citar a fonte dos dados. Texto sugerido para a descrição:

> O BusãoGyn é um aplicativo independente e não tem vínculo com a RMTC, a CMTC ou a Prefeitura de Goiânia. As chegadas e posições vêm dos serviços públicos da RMTC (https://www.rmtcgoiania.com.br).

Público-alvo: maiores de 13 anos (o app não é direcionado a crianças). Anúncios: não.

### 5.3 Web

- O site `busaogyn.lucksrei.com` está no ar com o build de `2d4df69` (19/10, `workflow_dispatch` da branch `web/custom-domain`). O endereço `workers.dev` responde 404 (erro 1042).
- A nova versão só vai ao ar com um deploy autorizado.

## 6. Permissões

| Plataforma | Produção | Desenvolvimento |
| --- | --- | --- |
| Android | INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE (MapLibre, sem prompt). Localização removida (`tools:node="remove"`) e serviço do geolocator removido | + ACCESS_COARSE/FINE_LOCATION (Perto de mim) |
| iOS | Nenhuma pedida em uso. Frase de localização presente no Info.plist | "Durante o uso", só ao tocar em Perto de mim |
| Web | Nenhuma. `Permissions-Policy: geolocation=()` no `_headers` | Geolocalização do navegador ao tocar |

## 7. Privacidade e segurança

| Ponto | Resultado |
| --- | --- |
| Dados persistidos | Tema, favoritos, linhas favoritas e recentes, só no aparelho (`shared_preferences`) |
| Logs do app | Só `debugPrint` de tipo de erro (nunca o texto compartilhado nem a posição) |
| Chamadas externas | API BusãoGyn, OpenFreeMap; no Web também unpkg, Google Fonts e a hospedagem Cloudflare |
| Analytics / SDKs | Nenhum |
| Credenciais | Nenhuma no app; `check-bundle-secrets.sh` OK no Web |
| Worker | 26 testes e typecheck OK, `npm audit` sem vulnerabilidades. Só GET, CORS por lista exata, erro genérico sem detalhes internos, log com método, caminho, status e duração (sem IP nem cabeçalhos). Código igual ao da `main` |
| Política do repositório | `app/web/privacidade.html` e `docs/PRIVACY.md` atualizados: compartilhar, verificação anti-robô da Cloudflare, política dentro do app |

**Proposta para a política pública em lucksrei.com (não publicada; outro repositório):**

1. Acrescentar: "Compartilhar abre a opção do sistema com um texto que você vê (o código do ponto). O app não envia nada sozinho; sem compartilhamento no aparelho ou navegador, o texto é copiado."
2. Acrescentar na parte da versão Web: "A Cloudflare pode executar no navegador verificações automáticas de segurança contra robôs."
3. Manter a data de atualização e as três línguas iguais.

## 8. CI e segurança de release

| Verificação | Resultado |
| --- | --- |
| Branches de desenvolvimento não publicam | `deploy-web.yml` só roda em `main` com `AUTO_DEPLOY == 'true'` ou manualmente; todas as execuções em `main` foram `skipped`. `worker-deploy.yml` é só manual |
| Publicação exige autorização | Deploys manuais; o ambiente `production` do GitHub **não tem revisor obrigatório** e a `main` não tem proteção (recomendação, não bloqueio) |
| Segredos em log | Os tokens só entram como `secrets.*` (mascarados) |
| Lançamentos públicos | Nenhum workflow cria release ou tag; o repositório tem 0 releases |
| Workflows de outras branches | `store-bundle*` e `store-screenshots` existem só em `claude/charming-pascal-4rvfwo` (artefatos com retenção de 7 dias, sem catálogo) |

**Mudanças nesta etapa:**

- `flutter-ci.yml`:
  - passo que falha se dados da CMTC forem versionados;
  - verificador de catálogo no Web, APK e AAB, com **controle positivo** (uma marca de teste precisa ser detectada) e verificador de segredos;
  - verificador de catálogo no `Runner.app` do iOS.
- `deploy-web.yml`:
  - Flutter 3.38.5, igual ao CI, com `--enforce-lockfile`;
  - `flutter test` antes do build;
  - verificador de catálogo;
  - smoke só no domínio vivo.
- `app/scripts/build-web.sh` (deploy manual): verificador de catálogo depois do de segredos.

## 9. Testes multiplataforma (evidências separadas)

| Tipo | O que foi verificado |
| --- | --- |
| **Automatizado** | 625 testes Flutter, incluindo diretrizes de acessibilidade, Tab/Enter, ciclo de vida, separação do catálogo, política, compartilhamento e chegada duplicada; 51 Python; 26 Worker |
| **Navegador** (Chromium) | Web de produção: chegadas reais do ponto 30402, acompanhamento ao vivo, favoritos, Salvos, Ajustes, compartilhar com e sem cópia; sem internet, erro 500, JSON inválido e reconexão; Web de desenvolvimento: Linhas e Planejar |
| **Safari** (iOS 26.5, simulador iPhone 17) | Web de produção: mapa (WebGL2), teclado numérico, consulta do 30402, folha de compartilhamento nativa (Web Share) |
| **Simulador iOS** (iPad Air 11", iOS 26.5) | App de produção: painel lateral, mapa, Ajustes, diálogo Privacidade, rotação retrato ↔ paisagem |
| **Emulador Android** (Android 17) | APK release de produção: permissões, inicialização, memória, CPU, chegadas reais; **TalkBack ativo**: botões rotulados e focáveis (dock, Ajustes, Compartilhar, Favoritar, Acompanhar) na árvore de acessibilidade |
| **Aparelho físico** | **Nenhum.** Não houve aparelho conectado |

**Ainda não validado** (exige aparelho ou uso humano):

- VoiceOver em iPhone/iPad e TalkBack com gestos reais: a árvore foi conferida, mas a navegação por voz não foi feita por uma pessoa.
- Teclado físico em iPad.
- Permissão real de localização: só desenvolvimento, Etapa D.
- Folha de compartilhamento nativa no app Android/iOS em aparelho.
- Segundo plano prolongado e economia de bateria.
- Safari de desktop (macOS): a automação remota do Safari não está habilitada nesta máquina.

## 10. Desempenho (builds release/profile)

| Medida | Resultado | Ambiente |
| --- | --- | --- |
| Inicialização a frio | 0,78 s a 1,30 s (3 execuções, `am start -W`) | Emulador Android 17, APK release |
| Memória com mapa e ponto aberto | PSS 125 MB | Emulador, release |
| CPU parado num ponto | 0–0,2% | Emulador, release (`top`) |
| Web: app pronto | 3,0–3,4 s com cache vazio | Chromium local (renderização por software) |
| Web: heap JS | 55–57 MB | Chromium |
| Rede parado num ponto | 2 consultas de chegadas e 14 de posições por minuto (~10 KB/min) | Web de produção |
| Acompanhamento | 1 consulta a cada 15 s; aba oculta: 0 | Etapa D |
| Busca/planejador (dev) | Busca 1–12 ms; planejador ≤ 6 ms | Etapa D |

**Risco E-8 (capacidade):** o plano gratuito do Cloudflare Workers aceita 100 mil requisições por dia. Com cerca de 16 requisições por minuto por pessoa parada num ponto, isso dá em torno de 100 horas de uso por dia. Acima disso, a API devolve erro até virar o dia.

Opções sem serviço pago, a decidir antes de divulgar amplamente:

- consultar a posição dos outros ônibus com menos frequência;
- criar um endpoint que devolva as posições de um ponto numa só chamada (mudança de API, precisa de justificativa e ADR).

## 11. Dependências e builds

| Item | Valor |
| --- | --- |
| Flutter do CI / Dart | 3.38.5 / 3.10.4 (fixado em `flutter-ci.yml` e agora também em `deploy-web.yml`) |
| Flutter local | master 3.50.0-0.2.pre, usado só para o simulador iOS: o 3.38.5 falha no build de simulador com o Xcode 27.1 local (status 255). Release para aparelho com o 3.38.5 funciona |
| Xcode local | 27.1 |
| Diretas desatualizadas | `geolocator` 14.0.2 → 14.1.2, `share_plus` 11.1.0 → 13.3.1 (major), `shared_preferences` 2.5.5 → 2.5.6, `intl` 0.20.2 (fixado pelo SDK). **Nenhuma atualização**: não há incompatibilidade comprovada, e o lockfile do CI garante build reproduzível |
| Nativas | MapLibre Android 13.5.0, MapLibre iOS 6.28.0, MapLibre GL JS 6.4.1 (Web), `play-services-location` 21.2.0 |
| CocoaPods / SPM | O projeto versionado usa CocoaPods + SPM; a cópia local do usuário (não versionada) usa só SPM. Os builds desta etapa restauraram os arquivos locais do usuário depois de cada `pod install` |
| Avisos de build | Web: aviso do dry-run de WebAssembly (informativo); iOS: "codesigning disabled" (esperado) |

Tamanhos do release (Flutter 3.38.5): ver seção 12.

## 12. Testes e builds desta etapa

Execução final com o Flutter 3.38.5 (o do CI) e o lockfile versionado:

| Verificação | Resultado |
| --- | --- |
| `dart format` / `flutter analyze` | sem mudanças / sem problemas |
| `flutter test` | **625 passaram** (622 da Etapa D + 3 novos: política, cópia recusada, chegada duplicada) |
| Python (`data/cmtc`) | 51 OK |
| Worker | typecheck OK, 26 testes OK |
| Web release | `main.dart.js` 3.929.788 bytes; `build/web` 33 MB |
| APK release (validação, chave de debug) | 86.747.400 bytes; só permissões de rede; 16 KB OK |
| AAB release | 58.241.944 bytes |
| iOS release sem assinatura | `Runner.app` 29,3 MB |
| Verificador de catálogo | OK em Web, APK, AAB e `Runner.app` (rc=0) |
| Controle positivo | Web e APK de desenvolvimento acusados (rc=1) |
| Segredos no Web | OK |

Os testes de regressão de E-2 foram conferidos por mutação: sem a correção, o teste falha.

## 13. Matriz de release

| Build | Técnico | Externo (ações humanas) | Classificação |
| --- | --- | --- | --- |
| 1. Android público atual | Pronto com ressalvas (sem aparelho físico; capacidade E-8) | Upload key, Play Console, Segurança dos dados, ficha com declaração de independência, classificação de conteúdo, teste fechado | **Pronto com ressalvas** |
| 2. iOS público atual | Pronto com ressalvas (sem aparelho físico nem VoiceOver humano) | Team/assinatura, App Store Connect, Privacidade do app, capturas iOS reais (Etapa F), notas de revisão, build number maior | **Pronto com ressalvas** |
| 3. Web público atual | Pronto com ressalvas (E-8; script anti-robô a citar na política pública) | Autorizar o deploy da nova versão | **Pronto com ressalvas** |
| 4. Android 2.0 completo | Funcional em desenvolvimento | Licença CMTC; sequência e vigência oficiais | **Bloqueado** |
| 5. iOS 2.0 completo | Funcional em desenvolvimento | Licença CMTC; sequência e vigência oficiais | **Bloqueado** |
| 6. Web 2.0 completo | Funcional em desenvolvimento | Licença CMTC; sequência e vigência oficiais | **Bloqueado** |

**Bloqueadores concretos:**

- **2.0 completo:**
  - licença de redistribuição da CMTC ([pedido técnico](CMTC_2026_PEDIDO_AUTORIZACAO.md), não enviado);
  - sequência oficial de paradas (hoje inferida);
  - vigência e calendário dos horários.
- **Versão pública, para publicar** (fora desta etapa, todos humanos ou de conta):
  - chave de upload e Play Console;
  - Team Apple e App Store Connect;
  - formulários de privacidade (respostas na seção 5);
  - capturas reais (Etapa F);
  - teste em aparelho físico;
  - autorização de deploy do Web.

## 14. Plano de correções e próximos passos

1. **Ao autorizar o merge e o deploy Web:**
   - merge de `feat/ux-redesign` na `main` (corrige o CI vermelho de `afdad14`);
   - deploy manual do Web;
   - smoke em `busaogyn.lucksrei.com`.
2. **Antes de divulgar amplamente:** decidir a mitigação de capacidade E-8.
3. **Teste em aparelho:**
   - Android e iPhone físicos, com TalkBack e VoiceOver por uma pessoa;
   - compartilhar nativo;
   - rotação;
   - teclado físico no iPad.
4. **Lojas:**
   - formulários com as respostas da seção 5;
   - ficha da Play com a declaração de independência;
   - build numbers acima dos últimos envios.
5. **Etapa F:** pacote visual completo, com capturas iOS só de build iOS.
6. **CMTC:** revisar e, se o responsável autorizar, enviar o pedido.
7. **Opcional:**
   - revisor obrigatório no ambiente `production` do GitHub;
   - proteção da `main`.

## 15. Pendências externas

- Resposta da CMTC (licença, sequência, vigência, calendário).
- Atualização da política pública em lucksrei.com (proposta na seção 7).
- Contas e chaves das lojas.
