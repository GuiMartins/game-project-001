# Executivo de terno — caminhada integrada

Caminhada aprovada pelo Guilherme em 22/10/2026, com altura corrigida de 175 pixels (1,75 m) e pés na linha 196 em todos os 32 quadros. O atlas tem quatro vistas reais: frente, 3/4 frente, perfil direito e costas.

## No jogo

`assets/sprites/pedestres/executivo_andando.png` e sua ficha entram no elenco de `PedestreSprite`, nas calçadas, travessias e testador. O shader espelha a esquerda e usa a própria vista traseira no ângulo de 3/4 costas, cuja geração expirou. Não foi gerada arte nova nem gasto crédito nesta integração.

O escopo continua sendo apenas andar: reações sem atlas mantêm um quadro do próprio executivo; no voo e no chão, esse quadro acompanha o giro e a posição do ator. Isso é uma representação provisória, não animação de susto/queda. Ele não é sorteado para desembarcar de carros. A moça de moletom mantém seu comportamento histórico.

## Reprodução e evidências

```bash
python3 tools/dev.py personagem montar arte/flow/personagens/executivo/personagem.json --animacao andando --saida assets/sprites/pedestres
python3 tools/dev.py sprites-ver --sprite executivo_andando
```

A ficha registra as fases selecionadas, quatro vistas e `altura_estavel_px: 175`. A estabilização é optativa e preserva proporções e pés; outras animações e personagens continuam usando escala constante por clipe. Fontes com membros cortados continuam rejeitadas. O recorte final usa alfa binário e remove franja verde das bordas após o redimensionamento.

- `conferencia/andando-altura-estavel.gif`: prévia com altura corrigida aprovada pelo usuário.
- `conferencia/andando-integrado.gif`: mesmos quadros do atlas integrado, com bordas limpas para o shader.
- `conferencia/integrado-cena.png`: executivo no testador com câmera e escala do jogo.
- `conferencia/integrado-playground.png`: caminhada na pista do playground.
- Originais, hashes e tentativas rejeitadas em `personagem.json` e `originais/`.

O movimento aprovado mantém suas fases originais; a análise automática ainda aponta abertura das pernas e transição entre alguns quadros. Os limites dos diagnósticos não foram afrouxados. Não se trata de personagem completo com cinco ações.

## Créditos

Teto autorizado: 175 créditos. Foram submetidas dez gerações de 7 créditos (70); uma expirou e anunciou reembolso de 7, resultando em 63 estimados. O reembolso final não foi auditado. Imagens foram informadas como gratuitas pelo Flow. Gerações encerradas a pedido do usuário.

## Validação da integração

358 testes unitários passaram, sem erros, falhas ou nós órfãos. O selftest passou nas 14 verificações, com todas as medidas dentro do baseline. Lint, 11 testes do montador e regressão visual diurna (`shots`, 19 quadros) passaram. Conferidos o atlas no catálogo, a cena e o playground; os 32 quadros têm 175 px de altura, pés em y=196 e alfa binário.
