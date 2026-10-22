class_name LargadaDaMoto
extends RefCounted
## As faixas e os numeros da largada: o giro do motor na contagem e o que cada
## cor faz quando o sinal abre. Moram aqui porque a `PlayerBike` e a `Hud`
## precisam concordar, e a barra nao pode mentir sobre a faixa.

## Giro do motor na contagem (`rpm_largada`, 0..1). Sobe com o gas aberto e
## cai sem ele: em ~1,4 s de gas cheio chega ao teto, entao segurar o
## acelerador a contagem inteira e o jeito de errar. A faixa na hora do sinal
## decide a largada: amarela larga normal, verde empina, vermelha patina.
const RPM_SOBE: float = 0.7
const RPM_DESCE: float = 0.9
const RPM_ZONA_VERDE: float = 0.55
const RPM_ZONA_VERMELHA: float = 0.7
## Empinada: o angulo da frente erguida e quanto ela dura, em segundos. Gira
## em torno do eixo traseiro, que e onde a moto apoia.
const EMPINA_GRAUS: float = 38.0
const EMPINA_DURA: float = 2.2
## m/s2 a mais de aceleracao com a frente no ar: a recompensa do verde, no
## nivel do nitro (`boost_accel`), e some quando a empinada acaba.
const EMPINA_ACEL: float = 12.0
## Patinada (`_patina`, 0..1): perde forca e aderencia lateral e rabeia, para
## o jogador perder tempo na saida. Recupera em ~2 s.
const PATINA_RECUPERA: float = 0.5
const PATINA_PERDA_DE_FORCA: float = 0.8
const PATINA_PERDA_DE_GRIP: float = 0.7
## Guinada de rabeada em rad/s com a patina cheia, e a frequencia dela.
const PATINA_RABEADA: float = 0.9
const PATINA_RABEADA_HZ: float = 7.0
## m/s de derrapada que a roda girando em falso mostra a patina cheia.
const PATINA_FUMACA: float = 7.0
