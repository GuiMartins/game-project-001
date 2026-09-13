<!--
  Documento congelado. Não edite para "corrigir" o que divergiu do código —
  a divergência é informação. Veja a seção Deriva, no fim.
-->

> **Documento de intenção, não de estado.** Este é o briefing original do
> projeto, escrito antes de existir uma linha de código. Ele diz o que o jogo
> deveria ser; **não** diz o que o jogo é.
>
> O que o jogo é hoje, e por quê, está em [PROTOTIPO.md](PROTOTIPO.md) — essa
> é a fonte da verdade. Nomes de arquivo, estrutura de pastas e vários sistemas
> daqui **não** correspondem ao repositório: o que mudou e por que está em
> [Deriva](#deriva), no fim deste arquivo.
>
> Congelado em 12/09/2026, versionado em 13/09/2026, exatamente como foi
> escrito. Ele está aqui porque `PROTOTIPO.md` cita "o que o GDD pede" para
> justificar decisões de código, e referência que ninguém consegue abrir não
> justifica nada.

---

# GAME DESIGN DOCUMENT (GDD)

# MVP - Jogo de Corrida de Entregadores

Versão: 1.0\
Objetivo: Documento técnico para criação do protótipo no Codex

------------------------------------------------------------------------

# 1. VISÃO DO JOGO

## Conceito

Jogo de corrida arcade com combate veicular inspirado em Road Rash.

O jogador controla um entregador competindo em corridas urbanas
brasileiras contra outros pilotos.

O jogo NÃO é simulador de entregas.

O foco é:

-   velocidade;
-   ultrapassagens;
-   combate;
-   risco;
-   adrenalina;
-   proteção da carga.

------------------------------------------------------------------------

# 2. OBJETIVO DO MVP

Criar uma versão jogável contendo:

-   uma pista;
-   um jogador;
-   cinco adversários controlados por IA;
-   uma moto;
-   combate lateral;
-   sistema de queda;
-   sistema de carga;
-   sistema de adrenalina;
-   trânsito.

A experiência alvo:

"Uma corrida rápida e divertida onde o jogador precisa decidir entre
atacar, correr riscos e proteger sua carga."

------------------------------------------------------------------------

# 3. TECNOLOGIA

## Engine

Godot 4

## Plataforma inicial

PC

## Estilo visual

Modelo híbrido:

-   cenário 3D pré-renderizado;
-   personagens 2D em sprites;
-   estética inspirada em Road Rash clássico.

------------------------------------------------------------------------

# 4. ESTRUTURA DO PROJETO

Criar o projeto seguindo esta organização:

    res://

    scenes/
        MainMenu.tscn
        RaceScene.tscn

    scripts/

    player/
        PlayerBike.gd
        CombatController.gd
        CargoSystem.gd

    enemy/
        EnemyBike.gd
        AIController.gd

    systems/
        RaceManager.gd
        NitroSystem.gd
        ScoreSystem.gd

    assets/

    sprites/
    backgrounds/
    audio/

------------------------------------------------------------------------

# 5. CENA PRINCIPAL

## MainMenu

Deve possuir:

-   botão Jogar;
-   botão Configurações;
-   botão Sair.

Ao clicar em Jogar:

Carregar RaceScene.

------------------------------------------------------------------------

# 6. CENA DE CORRIDA

## RaceScene

Elementos:

-   pista urbana brasileira;
-   jogador;
-   cinco inimigos;
-   carros de trânsito;
-   HUD.

------------------------------------------------------------------------

# 7. JOGADOR

## PlayerBike

Entidade principal controlada pelo usuário.

Propriedades:

    speed
    max_speed
    acceleration
    balance
    cargo_health
    nitro_amount
    position

------------------------------------------------------------------------

# 8. CONTROLES

Implementar:

## Movimento

Setas ou WASD:

-   esquerda;
-   direita;
-   acelerar;
-   frear.

## Ataque

Botão:

SPACE

Comportamento:

1.  Procurar inimigo mais próximo.
2.  Identificar se está do lado direito ou esquerdo.
3.  Executar golpe correspondente.

Regra:

Se inimigo estiver:

    x maior que jogador = ataque direita
    x menor que jogador = ataque esquerda

------------------------------------------------------------------------

# 9. SISTEMA DE COMBATE

O combate é baseado em equilíbrio.

Cada piloto possui:

    balance = 100

Quando recebe ataque:

    balance -= damage

Se:

    balance <= 0

Executar estado:

FALLING

------------------------------------------------------------------------

# 10. SISTEMA DE QUEDA

Estados:

    NORMAL
    HIT
    FALLING
    RECOVERING

Durante queda:

-   parar movimento;
-   tocar animação;
-   esperar 2 segundos;
-   retornar para corrida.

------------------------------------------------------------------------

# 11. SISTEMA DE CARGA

A moto possui uma caixa de entrega.

Variável:

    cargo_health = 100

Danos:

Colisão forte:

-10

Golpe:

-15

Queda:

-20

A carga não impede a corrida.

Ela influencia apenas a pontuação final.

------------------------------------------------------------------------

# 12. SISTEMA DE ADRENALINA

A adrenalina funciona como nitro.

Variável:

    nitro_amount = 0

Aumenta quando:

-   passar perto de carros.

Quando atingir:

    100

Permitir ativação.

Efeito:

    speed +50%
    duracao 3 segundos

------------------------------------------------------------------------

# 13. IA DOS ADVERSÁRIOS

Cada inimigo deve possuir:

Estados:

    FOLLOW_TRACK
    OVERTAKE
    ATTACK
    FALLING
    RECOVER

Comportamento:

FOLLOW_TRACK: seguir caminho.

OVERTAKE: tentar passar jogadores.

ATTACK: atacar quando próximo.

RECOVER: voltar após queda.

------------------------------------------------------------------------

# 14. SISTEMA DE CORRIDA

Configuração:

    Jogador = 1
    IA = 5
    Voltas = 1
    Duração média = 2 minutos

Vitória:

Maior posição na chegada.

------------------------------------------------------------------------

# 15. HUD

Criar interface mostrando:

-   velocidade;
-   posição;
-   barra de carga;
-   barra de adrenalina.

------------------------------------------------------------------------

# 16. SISTEMA DE PONTUAÇÃO

Resultado baseado em:

-   posição final;
-   integridade da carga.

Exemplo:

    Pontuação =
    posição +
    bônus carga

------------------------------------------------------------------------

# 17. ARTE TEMPORÁRIA

Para o primeiro protótipo usar:

-   sprites simples;
-   placeholders;
-   cenário simples.

Prioridade:

Gameplay antes da arte.

------------------------------------------------------------------------

# 18. ORDEM DE DESENVOLVIMENTO

## Fase 1

Criar:

-   projeto Godot;
-   cena corrida;
-   movimento da moto.

## Fase 2

Criar:

-   pista;
-   câmera;
-   trânsito.

## Fase 3

Criar:

-   inimigos IA;
-   sistema de posição.

## Fase 4

Criar:

-   combate;
-   golpes;
-   queda.

## Fase 5

Criar:

-   carga;
-   adrenalina;
-   HUD.

## Fase 6

Polimento:

-   sons;
-   efeitos;
-   menu.

------------------------------------------------------------------------

# 19. REGRAS PARA O CODEX

Ao implementar:

-   manter código modular;
-   criar scripts separados por sistema;
-   evitar sistemas desnecessários;
-   priorizar gameplay funcional;
-   não adicionar features fora deste documento.

O objetivo é criar primeiro uma corrida divertida e jogável.

------------------------------------------------------------------------

# Deriva

*Esta seção não faz parte do documento original. Ela existe para que ninguém
leia o texto acima e vá procurar uma pasta que não existe.*

O protótipo respondeu a algumas perguntas que o GDD não tinha como responder, e
cada resposta moveu alguma coisa. Onde o código diverge, **o código ganha** — o
raciocínio de cada divergência está em [PROTOTIPO.md](PROTOTIPO.md).

## Estrutura de arquivos (§4)

O GDD pede `scripts/player/`, `scripts/enemy/`, `scripts/systems/`. O repositório
é plano: [scripts/player_bike.gd](../scripts/player_bike.gd),
[scripts/rival_bike.gd](../scripts/rival_bike.gd),
[scripts/world.gd](../scripts/world.gd). Com ~15 arquivos, a pasta por sistema
custa mais navegação do que organiza. `EnemyBike` virou `RivalBike` porque
"inimigo" descreve errado quem está correndo a mesma corrida que você.

## Menu (§5)

`MainMenu.tscn` não existe e não vai existir enquanto a pergunta do protótipo
não tiver resposta. O jogo abre direto na corrida.

## Carga (§11)

**Saiu do jogo.** A barra de integridade da bag media a mesma coisa que o resto
do painel já media — quem cai e apanha também chega tarde e sem estilo — e
cobrava por isso uma barra permanente numa HUD de 320×180. O custo de raspar
virou estilo. O raciocínio completo está no cabeçalho de
[race_run.gd](../scripts/race_run.gd).

A bag continua existindo como **silhueta**: caixa grande e quadrada nas costas,
que é o que identifica um entregador a 96 px, e a cor dela é o que distingue
rival de rival.

## IA dos adversários (§13)

O GDD lista cinco estados num enum só. O código separa em dois eixos, porque
cair acontece por cima de qualquer intenção:

| GDD | Código |
| --- | --- |
| `FOLLOW_TRACK` | `Mode.FOLLOW` |
| `OVERTAKE` | `Mode.OVERTAKE` |
| `ATTACK` | `Mode.ATTACK` |
| `FALLING` / `RECOVER` | `State.STAGGERED` / `State.DOWN` |

## Adrenalina (§12)

O sistema sobreviveu, os números não. Não é +50% por 3 s: é multiplicador de
teto (`boost_speed_mult`) mais aceleração extra, gastando a barra por segundo
(`boost_drain`). A carga por passar perto de carro virou a raspada no corredor
(`boost_gain_near_miss`) — ver [bike_tuning.gd](../scripts/bike_tuning.gd).

## Estilo visual (§3, §17)

O GDD pede cenário 3D pré-renderizado com sprites 2D. O que existe é **greybox**:
caixas coloridas, nenhuma arte. Isso não é atraso, é a ordem do §17 levada a
sério — gameplay antes da arte, e nada de arte até "acelerar, inclinar e bater"
estar gostoso.

## Ferramenta (§19)

"Regras para o Codex" é histórico. O contrato de operação em vigor, para pessoa
ou IA, é o [CLAUDE.md](../CLAUDE.md) na raiz.

## O que se manteve

Cinco rivais (`rival_count = 5`), combate lateral por equilíbrio, queda com
recuperação, adrenalina por risco, trânsito, posição na chegada decidindo o
resultado, e o corredor entre os carros como mecânica central. O miolo do GDD
está de pé.
