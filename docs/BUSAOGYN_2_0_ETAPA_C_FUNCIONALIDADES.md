# BusãoGyn 2.0 — Etapa C: localização, viagens salvas e melhorias funcionais

Branch `feat/ux-redesign` (a partir de `ff003d9`). Sem merge na `main`, sem
deploy, sem serviço pago. Nenhuma API, regra de confiabilidade ou algoritmo de
rota foi alterado. Tudo o que depende do catálogo CMTC continua **só em
desenvolvimento**.

## 1. Perto de mim

**Fluxo:** aba Pontos → "Perto de mim" → (permissão pedida só neste momento)
→ uma leitura da posição atual → pontos do catálogo local até 1 km, do mais
perto ao mais longe, com "N m em linha reta" → tocar abre a prévia do ponto
(e dali as chegadas). O mapa mostra você (disco na cor do texto) e enquadra
você + os 4 pontos mais próximos na área visível.

| Situação | Comportamento |
|---|---|
| Permissão concedida | Lista + ponto "você" no mapa; "Atualizar" faz nova leitura |
| Negada | Explica e lembra a busca por código/rua/bairro; não pede de novo sozinho |
| Negada permanentemente | Explica e oferece "Abrir ajustes" do app |
| Serviço desligado | Explica e oferece "Abrir ajustes" de localização |
| Timeout (15 s) | Sugere tentar de novo em local aberto |
| Indisponível (navegador/aparelho) | Explica; o resto do app segue igual |
| Precisão > 150 m | Lista com aviso "Posição aproximada (± N m)" |
| Sem catálogo (produção) | O botão não existe; nada é pedido |

**Privacidade:** sem pedido no primeiro lançamento; sem segundo plano; sem
histórico; a posição fica só na memória e a busca é 100% local (nenhuma
coordenada sai do aparelho). Distância é em **linha reta** (dito na tela);
não há rota a pé (faltam dados de calçadas e travessias).

**Arquitetura:** `core/location/location_service.dart` (`LocationService`,
`DeviceLocationService` com `geolocator`, falhas tipadas em
`LocationProblem`), `catalog/domain/nearby.dart` (`nearbyStops`, haversine
sobre os ~7 mil pontos), `catalog/presentation/nearby_widgets.dart`
(`NearbyController`, que sobrevive à troca de aba, e `NearbyStopsSection`).
O ponto "você" é uma fonte/camada nova do overlay (`busao-net-me`), sem
recriar o MapLibre.

**Configuração por plataforma:**

- **Android:** o manifesto principal remove as permissões de localização (que
  o plugin do mapa declara) e o serviço `GeolocatorLocationService` (não
  usamos rastreamento contínuo). `src/debug` e `src/profile` declaram
  `ACCESS_COARSE_LOCATION`/`ACCESS_FINE_LOCATION` com `tools:node="replace"`.
  O release fica sem localização (verificado com `aapt`, seção 8).
- **iOS:** `NSLocationWhenInUseUsageDescription` no `Info.plist` (o mesmo
  arquivo para todos os builds; o release nunca pede porque o botão não
  existe sem catálogo). Sem `Always`.
- **Web:** API de geolocalização do navegador; exige HTTPS (o deploy atual é
  HTTPS) ou localhost.

Dependência nova: `geolocator ^14.0.2` (Android, iOS e Web; sem custo).

## 2. Viagens salvas

- No Planejar, com origem e destino escolhidos: **Salvar viagem** (vira
  "Viagem salva"; tocar de novo remove).
- Em **Salvos**, seção "Viagens" acima dos pontos favoritos: tocar abre o
  Planejar e **recalcula** o itinerário com o catálogo atual; o menu ⋮
  renomeia (até 40 caracteres; vazio volta a "origem → destino") e remove.
- O mesmo par não se repete (a volta é outra viagem); até 20, sem remoção
  automática.
- Ponto que não existe mais no catálogo: o cartão avisa e abrir mostra a
  mensagem, sem rota inventada. Sem cobertura, o próprio planejador explica
  (mensagens da Fase 5).
- **Persistência:** mesma chave `busaogyn.saved_stops.v1`, `schema` 3 com
  `trips: [{from, to, name?, at}]`. `schema` 1 e 2 continuam legíveis
  (migração testada; favoritos, linhas e recentes preservados); a próxima
  gravação já sai no 3. Nada de itinerário gravado.

## 3. Compartilhamento

- **Ponto** (botão no cabeçalho do ponto; funciona também sem catálogo, só com
  o código), **linha** (detalhe da linha) e **viagem** (alternativa escolhida
  no Planejar).
- Folha nativa do sistema (`share_plus ^11.1.0`: Android, iOS, Web Share). Onde
  não há (ex.: navegador de desktop), o texto é copiado e um aviso aparece.
- Texto simples, com "app independente, não oficial"; linha e viagem dizem que
  são dados de cadastro/estimativa e pedem para conferir antes de sair. Nunca
  inclui a posição do usuário.
- **Links:** não foram criados. O domínio `busaogyn.lucksrei.com` ainda não tem
  DNS e a versão publicada não abre um ponto por link; um link hoje levaria a
  uma tela genérica. Estratégia proposta (precisa de deploy autorizado):
  `https://<domínio>/?ponto=<código>` aberto pelo app web e, depois, App
  Links/Universal Links. Linha e viagem dependem do catálogo restrito e
  **não** devem ganhar página pública.

## 4. Busca

Auditoria: a busca já era local, sem acento, com sinônimos (av, pça, jd, st,
term…), prefixo, terminal/estação acima de ruas homônimas, pesos por campo e
desempate por código; código numérico casa pelo início.

Melhorias:

- **Um erro de digitação** (inserção, remoção ou troca de uma letra) em
  palavras de 5+ letras, **só quando a busca exata não acha nada**, com o aviso
  "Nada exato: mostrando nomes parecidos". Palavras curtas e códigos nunca são
  aproximados (evita casar com o ponto errado). Vale na aba Pontos e nos
  campos do Planejar.
- Teste de desempenho existente (catálogo grande) continua passando.

Não feito: geocodificação de endereços e lugares (exigiria serviço externo ou
base de lugares que o projeto não tem); destaque do trecho encontrado.

## 5. Alertas de aproximação — estudo de viabilidade

| Aspecto | Situação |
|---|---|
| Dados | Previsão de chegada e posição via API própria (Worker → RMTC). Cache do Worker: chegadas frescas por 15 s (servíveis até 60 s), posição 5 s/45 s |
| Frequência | O app já consulta chegadas a cada 30 s e posição a cada 15 s, só em primeiro plano |
| Confiabilidade | Previsões da RMTC variam; a Fase 6 (8 ônibus) não basta para afirmar precisão. Há ônibus sem posição, GPS antigo e itinerário incompatível |
| Android em segundo plano | Exigiria serviço em primeiro plano com notificação fixa ou WorkManager (mínimo de 15 min, inútil para "chegando em 3 min") |
| iOS em segundo plano | Não há execução periódica garantida; *background fetch* é oportunista. Só push do servidor seria confiável, o que exige backend com agendamento por usuário, token de push e custos |
| Permissões | Notificações (Android 13+ e iOS pedem); localização não é necessária |
| Bateria/rede | Consulta a cada 15–30 s em segundo plano gasta bateria e dados |
| Falsos alertas | Previsão que "pula", ônibus que some, troca de veículo |

**Conclusão:** alertas confiáveis com o app fechado **não são viáveis** sem
backend de push (custo e coleta de token). Alternativa viável e honesta:
**aviso só com o app aberto** (ex.: vibração/aviso visual quando o ônibus
acompanhado passa a "chegando"), deixando claro que não funciona com o app
fechado. Não implementado nesta etapa: precisa de decisão de produto.

## 6. Reportar dado incorreto — avaliação

Não há canal de suporte no app. Existe o contato público da Lucksrei nas
páginas de suporte (`docs/PRIVACY.md`). Recomendação: um item "Reportar
problema" em Ajustes que abra o **e-mail** do usuário com assunto e corpo
pré-preenchidos (ponto/linha, sem identificadores), deixando claro que o
BusãoGyn não é canal da CMTC. Não implementado: o endereço de suporte
definitivo e o processo de resposta precisam ser confirmados pelo
responsável.

## 7. Problemas encontrados e corrigidos

- **Snackbars cobriam o dock** (o toque na navegação não funcionava enquanto
  o aviso estava na tela): avisos agora flutuam acima do dock (tema global).
- **Diálogo de renomear** descartava o campo antes da animação de saída
  (erro "controller used after dispose"): o diálogo passou a ser dono do
  campo.
- **Ações do Planejar transbordavam** a 200% de fonte em 390 px: viraram
  `Wrap`.
- Dependências: `share_plus` 13 puxava `jni`/`objective_c` (hooks nativos);
  fixado em 11.1.0. Ainda assim o `path_provider` atual usa esses pacotes; os
  builds Android, iOS e Web passaram com eles (seção 8).

## 8. Testes e builds

- Flutter 3.38.5: **612 testes** passando (eram 589), `flutter analyze` sem
  problemas, `dart format` sem mudanças. Pipeline Python não foi tocado.
- Novos testes: perto de mim (concedida, negada, negada para sempre, serviço
  desligado, timeout, indisponível, imprecisa, sem catálogo, nenhum pedido ao
  abrir, mapa criado uma vez), ordenação/raio por distância, viagens salvas
  (persistência, migração 1/2 → 3, dados inválidos, renomear, remover,
  limite, abrir recalculando, ponto fora do catálogo), compartilhamento
  (ponto/linha/viagem, avisos, sem posição, fallback para área de
  transferência), busca sem acento e com um erro de digitação.
| Build | Resultado | Catálogo CMTC (verificador) | Localização |
|---|---|---|---|
| Web produção (release) | OK, `main.dart.js` 3.912.025 bytes | Ausente | Botão não existe |
| Android produção (release APK) | OK, 86,7 MB | Ausente | Sem permissão e sem serviço de localização (`aapt`) |
| Android dev (profile APK) | OK, 124,7 MB | Presente (controle positivo: verificador falha) | `ACCESS_COARSE/FINE_LOCATION` |
| iOS produção (release, `--no-codesign`, Flutter master) | OK, 29,6 MB | Ausente | Frase de uso no `Info.plist`; nunca pede |
| Web dev (profile) | OK | Presente | Validado no navegador com posição simulada |

Validação visual pontual (local, `artifacts/etapa_c/`, não versionado):
celular 390×844 escuro e 375×812 claro com a lista e o ponto "você" no mapa;
painel recolhido com "Perto de você · N pontos"; permissão bloqueada no
navegador; tablet 1024×1366 com o painel lateral.

Problema achado na validação web: o registro de plugins do build local estava
desatualizado (`MissingPluginException`, o app mostrava "indisponível").
Era cache local; depois de `flutter clean` funcionou. O CI faz builds limpos.
Também no web: bloqueio da permissão agora pede para liberar "nas permissões
do navegador", sem botão de ajustes (que não existe no navegador).

Testado em: testes de widget, navegador (build web) e builds nativos sem
assinatura. **Não** testado em aparelho físico nem com GPS real.

## 9. Pendências

- Validar "Perto de mim" em aparelho físico (Android e iPhone) e no
  navegador do celular.
- Decidir alertas só com o app aberto (seção 5) e o canal de "Reportar
  problema" (seção 6).
- Links compartilháveis dependem de domínio e deploy autorizados.
