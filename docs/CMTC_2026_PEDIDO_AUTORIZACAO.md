# CMTC 2026 — Pendências técnicas para o pedido de autorização

- **Data:** 28/10/2026 · **Etapa:** BusãoGyn 2.0 — Etapa E (auditoria de publicação)
- **Situação:** rascunho técnico. **Não foi enviado** e não deve ser enviado sem autorização expressa do responsável pelo projeto.
- **Base:** Ofício nº 728/2026/CMTC e Parecer nº 226/2026 (respostas ao pedido LAI, protocolo 2026106554419306). Ver [CMTC_2026_INVENTARIO_DADOS.md](CMTC_2026_INVENTARIO_DADOS.md), seção 1.

Receber os arquivos pela LAI **não equivale a autorização** para redistribuí-los em um aplicativo. A resposta da CMTC não traz licença, termo de uso, nem autorização ou restrição. Até haver resposta formal, o catálogo continua só em desenvolvimento ([ADR-0002](adr/0002-dados-confiaveis-e-nao-inferencia.md), [ADR-0005](adr/0005-sequencia-estimada-so-em-desenvolvimento.md)).

## 1. O que o aplicativo faria com os dados

Descrição para a CMTC avaliar, sem jargão:

- O BusãoGyn é um aplicativo **independente e gratuito**, sem vínculo com a CMTC, a RMTC ou a Prefeitura. Existe para Android, iOS e Web.
- O app guardaria **no aparelho** uma cópia compacta (cerca de 2 MB) do cadastro de pontos e linhas, dos trajetos e dos horários. Com ela, funcionariam a busca por rua e bairro, o mapa das linhas, os horários por ponto e um planejador de viagens, inclusive sem internet.
- Os arquivos seriam **transformados**: conversão de coordenadas, junção de pontos e linhas, simplificação dos trajetos e cálculo de horários por ponto. Os originais não seriam publicados.
- Nada seria vendido. Não há anúncios nem coleta de dados pessoais.

## 2. Perguntas à CMTC

### 2.1 Autorização e licença

1. A CMTC autoriza a **reutilização** desses dados em um aplicativo independente e gratuito?
2. Autoriza a **redistribuição** dentro do aplicativo, nas lojas Google Play e App Store e na versão Web?
3. Autoriza que o aplicativo guarde a cópia **no aparelho** para uso sem internet?
4. Autoriza o **processamento e a transformação** descritos na seção 1 (conversão, junção, simplificação, horários por ponto)?
5. Há uma **licença** aplicável (por exemplo, uma licença de dados abertos) ou um termo a assinar? Se houver, qual o texto?
6. Há restrição a **uso comercial**? O app é gratuito hoje; a resposta define se doações ou patrocínio seriam possíveis no futuro.
7. Qual **atribuição** a CMTC exige (texto, logotipo, link) e onde ela deve aparecer (tela de ajustes, loja, site)?
8. Há restrição ao uso do nome "RMTC" ou "CMTC" no aplicativo ou nas lojas?

### 2.2 Vigência e atualização

9. Qual a **vigência** de cada arquivo? As planilhas horárias têm datas por aba de 2022 a 2026. Quais estão em vigor hoje?
10. Com que **periodicidade** os cadastros, trajetos e horários são atualizados?
11. Existe um **canal oficial** (URL, API, feed ou e-mail) para receber as atualizações e os avisos de mudança?
12. A CMTC publica ou pode publicar os dados em **GTFS**? Isso já resolveria a maior parte das perguntas abaixo.

### 2.3 Itens técnicos que faltaram na resposta

13. **Sequência oficial de paradas** por linha e sentido. É o item (d) do pedido original e não foi entregue. Hoje o app só estima a ordem a partir do trajeto, e por isso a sequência fica restrita ao desenvolvimento.
14. **Calendário operacional**: dias úteis, sábados, domingos, feriados e férias escolares, e como cada planilha horária se aplica a eles.
15. **Dicionário de campos** dos cadastros de linhas e pontos: significado dos códigos, das colunas LINHA 01..27 e de "SEM CADASTRO".
16. **Especificação dos arquivos**: formato, codificação, sistema de coordenadas dos KMZ e se o nome das variantes (`003-1`, `003-7`) é estável entre versões.
17. Como identificar linhas **canceladas ou suspensas**, já que o cadastro entregue só traz linhas em operação.

## 3. O que a resposta precisa conter para liberar a publicação

| Necessário | Por quê |
| --- | --- |
| Autorização por escrito, com número de documento (SEI) | ADR-0002, item 6: registrar o identificador antes de usar em produção |
| Escopo: Android, iOS e Web, com cópia no aparelho | Os três builds distribuem o catálogo |
| Texto de atribuição | A tela Ajustes e as lojas precisam reproduzi-lo |
| Vigência e calendário dos horários | Sem isso, horários não podem ser apresentados como atuais |
| Sequência oficial (ou a confirmação de que não existe) | Sem ela, a sequência continua estimada e só em desenvolvimento |

Sem autorização, ou com autorização parcial, a publicação da versão completa continua **bloqueada**. A versão pública atual (chegadas e acompanhamento via API, sem catálogo) não depende desta resposta.

## 4. Antes de enviar

- Revisar o texto com o responsável pelo projeto. Ele decide se envia e por qual canal (Ouvidoria ou e-mail institucional da CMTC).
- Citar o protocolo 2026106554419306 e o Ofício nº 728/2026/CMTC.
- Não anexar dados pessoais nem os arquivos recebidos.
