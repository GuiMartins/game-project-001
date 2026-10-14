class_name WorldTuning
extends Resource
## Constantes do transito e dos rivais.
##
## Separado de BikeTuning de proposito: aquele arquivo responde "a moto esta
## gostosa?", este responde "o corredor esta passavel?". Sao duas perguntas
## diferentes, e misturar os sliders faz voce ajustar uma achando que ajusta
## a outra.

const SAVE_PATH: String = "user://world_tuning.tres"

@export_group("Transito")

## Quantos carros existem ao mesmo tempo. ESTE e o numero da densidade.
##
## Os carros nao sao criados e destruidos: sao reciclados pra viver sempre na
## janela [-traffic_behind, +traffic_ahead] em volta do jogador. Entao a
## densidade real e count / (ahead + behind).
##
## Caiu de 20 pra 10 quando o engarrafamento foi removido, e o motivo importa:
## o `jam_share` recrutava metade da frota pra montar a fila, entao METADE
## destes carros nunca estava no fluxo. Tirar o engarrafamento sem mexer aqui
## dobrou a densidade efetiva sem ninguem ter mexido no slider da densidade -
## o piloto do banco de provas passou a bater de frente em sequencia e a
## corrida caiu de 1345 m pra 960 m em 45 s.
##
## Subiu de 10 pra 25 na V20, junto com a velocidade: carro que anda quase
## junto com a moto demora a ficar para tras, e o video mostra 8 a 15 na tela
## e 2 a 4 nos primeiros 20 m.
@export_range(0, 120, 1) var traffic_count: int = 25

## Espacamento minimo entre carros na largada, em metros.
@export_range(3.0, 60.0, 0.5) var traffic_gap_min: float = 5.0
## Espacamento maximo entre carros na largada, em metros.
##
## So vale na largada e no R. Depois disso quem manda na densidade e o
## traffic_count com a janela - por isso mexer so aqui parece nao fazer nada
## depois dos primeiros segundos.
@export_range(4.0, 90.0, 0.5) var traffic_gap_max: float = 16.0

## Quao a frente do jogador um carro reciclado reaparece, em metros.
## Aumentar isto sem mexer no count espalha a mesma frota num trecho maior.
@export_range(80.0, 800.0, 10.0) var traffic_ahead: float = 420.0
## Quantos metros atras do jogador o carro e recolhido pra reciclagem.
@export_range(20.0, 200.0, 5.0) var traffic_behind: float = 30.0

## Velocidade de cruzeiro mais alta que um carro do fluxo assume, em m/s.
##
## E o numero que decide se o corredor e um tunel que anda ou uma parede que
## voce ultrapassa - alto demais e os carros somem no retrovisor, zero e a
## avenida vira estacionamento permanente. Era 7 m/s (25 km/h), transito de
## marginal em hora de pico, e o corredor durava um piscar. No video (V20) o
## transito anda quase na velocidade da moto: o taxi fica emparelhado quase
## 2 s e o corredor dura um segundo. 26 m/s sao 94 km/h; a 128 km/h a moto
## ganha de 10 a 18 m/s, e um carro de 4,4 m passa do lado em meio segundo.
@export_range(0.0, 45.0, 0.5) var traffic_speed: float = 26.0
## A mais baixa: cada carro sorteia entre esta e a de cima. Era zero, e metade
## do transito andava quase parada - obstaculo, e nao fluxo. 18 m/s sao
## 65 km/h.
@export_range(0.0, 45.0, 0.5) var traffic_speed_min: float = 18.0

## Aceleracao do carro do transito, em m/s^2.
@export_range(0.5, 12.0, 0.1) var traffic_accel: float = 2.2
## Frenagem do carro do transito, em m/s^2.
##
## Maior que a aceleracao de proposito: carro que reage devagar a fila entra
## dentro do carro da frente, e duas caixas se atravessando em pixel grosso le
## como bug, nao como transito. Era 4,5, freio de quem anda a 25 km/h; com o
## transito a 90 km/h (V20) o carro mais rapido nao parava atras do mais
## lento e entrava nele. 7 e freada forte de carro de rua.
@export_range(1.0, 25.0, 0.1) var traffic_brake: float = 7.0
## Distancia centro a centro que o carro guarda do carro da frente, em metros.
##
## O carro tem 4,4 m, entao abaixo de 5 eles se encavalam. E este numero que
## decide o comprimento da fila do semaforo.
@export_range(5.0, 24.0, 0.1) var traffic_follow_gap: float = 6.2

## Fracao dos carros que entra encostada no meio-fio, parada.
##
## Encostado quer dizer parado numa das faixas da ponta - a da esquerda ou a
## da direita, sorteada. So carro encostado pode abrir porta: carro andando no
## meio da pista abrindo porta e bug com cara de recurso.
##
## Tambem e o numero que decide se as faixas da ponta valem a pena. Alto
## demais e elas viram parede, e o jogo perde duas das quatro faixas.
@export_range(0.0, 1.0, 0.05) var parked_chance: float = 0.3

## Fracao dos carros encostados que ja esta de porta aberta quando aparece, e
## fica assim.
##
## E o obstaculo que se le de longe: meia faixa fechada, parada. Rara porque
## e ela que soma a parede - com 0.3 de encostados, 0.2 aqui da um carro em
## cada dezessete.
@export_range(0.0, 1.0, 0.05) var door_open_chance: float = 0.2

## Fracao dos carros encostados que abre a porta em cima do jogador, uma vez.
##
## O susto, e por isso a menor das duas: susto frequente vira regra decorada,
## e o jogador aprende a nunca chegar perto da ponta em vez de calcular o
## risco. Somada com `door_open_chance`, nao passa de 1. O lado e sempre o do
## jogador.
@export_range(0.0, 1.0, 0.01) var door_ambush_chance: float = 0.08

## A quantos segundos de distancia o jogador esta quando a porta na cara abre.
##
## A porta leva uns 0,15 s para virar obstaculo (`Carro.PORTA_BATE`), e
## reacao humana e uns 0,25 s: abaixo de 0.5 ela e inevitavel, e porta
## inevitavel e tiro, nao susto. Acima de 1.5 e porta aberta de longe com
## outro nome.
@export_range(0.3, 2.0, 0.05) var door_ambush_time: float = 0.8

@export_group("Rivais")

## Quantos rivais correm junto. Muda na proxima corrida (R), nao ao vivo:
## rival tem estado de IA e trocar no meio faria o placar mentir.
##
## Cinco e o pelotao do GDD - seis na pista contando o jogador. E tambem o
## numero que decide quanto a colocacao significa: com um rival so, "segundo
## lugar" e outra palavra pra "perdeu".
@export_range(0, 12, 1) var rival_count: int = 5

## Ritmo mais lento e mais rapido que um rival busca sozinho, em fracao do teto
## de velocidade da moto.
##
## Este par e o coracao da corrida. O teto de 52 m/s e velocidade de pista
## limpa; no transito ninguem sustenta isso, e o piloto automatico do banco de
## provas faz uns 27 m/s de media. 0.55 a 0.72 poe o pelotao entre 29 e 37 m/s
## nominais, que com carro na frente e queda no meio vira uma corrida disputada
## em vez de uma fuga. Espalhar o intervalo espalha o pelotao: min = max faz
## cinco rivais que chegam juntos.
@export_range(0.3, 1.0, 0.01) var rival_pace_min: float = 0.55
@export_range(0.3, 1.1, 0.01) var rival_pace_max: float = 0.72

## Quao briguento e o rival mais manso e o mais barraqueiro do pelotao, 0..1.
##
## Sorteado por rival na largada. Um numero so decide tres coisas: se ele larga
## a corrida pra ir CACAR o jogador, quanto tempo ele mede antes do primeiro
## soco, e quanto respiro da entre um soco e o proximo.
##
## Era 0.35..0.95 e o combate virou pedagio: mais da metade do pelotao
## abandonava a corrida pra emparelhar, e chegar perto de um rival era sinonimo
## de apanhar. O combate lateral e um pilar, mas pilar de jogo e coisa que o
## jogador ESCOLHE - se ele acontece sozinho toda vez que duas motos se
## encostam, o jogador aprende a nao encostar, e o pilar morre de tanto ser
## usado. Aqui o teto fica logo acima do gatilho de cacada (0.5), entao poucos
## rivais vem atras de voce, e nenhum e implacavel.
@export_range(0.0, 1.0, 0.05) var rival_aggression_min: float = 0.1
@export_range(0.0, 1.0, 0.05) var rival_aggression_max: float = 0.55

## Distancia em que um rival briguento larga a corrida pra ir atras do jogador,
## em metros.
##
## Eram 12 m fixos, ou seja meia dezena de comprimentos de moto: o rival mudava
## de faixa pra cima de voce antes mesmo de voce ver que ele existia. Em 5 m ele
## precisa ja estar praticamente do seu lado.
@export_range(0.0, 30.0, 0.5) var rival_hunt_range: float = 5.0

## Segundos que o rival passa colado antes de tentar o primeiro soco, no rival
## mais manso; o mais briguento espera a metade.
##
## E o aviso que nao existia. A decisao de socar era um sorteio POR FRAME
## (`randf() < agressividade`), e a 60 Hz isso nao e "as vezes": com 0.5 de
## agressividade o soco saia no segundo frame dentro do alcance. Emparelhar era
## apanhar, sem janela pra sair, socar primeiro ou aceitar a briga.
@export_range(0.0, 3.0, 0.1) var rival_punch_delay: float = 0.9

## Respiro entre dois socos do mesmo rival, em segundos, no rival mais manso;
## o mais briguento espera a metade.
##
## Somado ao cooldown do soco. Antes o cooldown era DIVIDIDO pela agressividade,
## o que deixava o rival briguento socando a cada 0,47 s - metralhadora, nao
## briga.
@export_range(0.0, 6.0, 0.1) var rival_punch_rest: float = 2.6

## Empurrao lateral do soco do rival no jogador, em m/s.
##
## Separado do `punch_shove` do jogador porque os dois lados nao pesam igual. O
## do jogador subiu para 15 pra jogar rival na faixa do lado; no jogador, esse
## mesmo numero vira velocidade lateral numa moto que ele esta tentando
## controlar, e apanhar com o dobro tira o corredor da mao dele. 7,5 e o que o
## soco do rival sempre deu.
@export_range(1.0, 20.0, 0.25) var rival_punch_shove: float = 7.5

## Quanto da distancia pro jogador vira velocidade do rival, em (m/s) por metro.
##
## E o slider de "quanto de corrida, quanto de briga". Zero e corrida honesta:
## o rival ignora onde voce esta e o pelotao se espalha ate sumir. Alto demais
## e o pelotao gruda em voce e a colocacao deixa de significar - voce sente que
## a corrida esta encenada, porque esta.
@export_range(0.0, 0.6, 0.01) var rival_rubber_band: float = 0.15

@export_group("Ceu")

## Os sliders da nuvem (`scripts/ceu.gdshader`), ao vivo. Nao mexem em fisica:
## o banco de provas ignora todos. A camera de perseguicao ve do horizonte ate
## ~20 graus, e a garupa um pouco mais.

## Onde o banco do horizonte comeca, em graus; abaixo disso a ultima fresta
## rareia e a neblina engole.
@export_range(0.0, 20.0, 0.5) var ceu_altura_min: float = 2.0
## Quanto a nuvem fecha perto do horizonte: 0 e o ceu igual de cima a baixo,
## alto e um banco cinza de nuvem empilhada.
@export_range(0.0, 0.6, 0.01) var ceu_banco: float = 0.35
## Quanto do ceu e nuvem: 0 e limpo, 1 e quase fechado.
@export_range(0.0, 1.0, 0.01) var ceu_cobertura: float = 0.5
## Tamanho de um tufo a 15 graus de altura, em graus. Mais baixo ele encolhe.
@export_range(0.5, 12.0, 0.1) var ceu_tufo: float = 4.0
## Tamanho de um grupo de tufos, em tufos: pequeno espalha pipoca, grande
## junta em massas com muito azul entre elas.
@export_range(1.0, 20.0, 0.5) var ceu_grupo: float = 6.0
## Quanto o tufo encolhe e achata perto do horizonte: 0 e igual em todo o
## ceu, 1 e a perspectiva de um teto plano de verdade.
@export_range(0.0, 1.0, 0.01) var ceu_perspectiva: float = 0.35
## Tufos miudos entre os grandes: e o que deixa o alto em calombo.
@export_range(0.0, 1.0, 0.01) var ceu_detalhe: float = 0.6
## Largura da borda macia, de um a quatro pixels: a paleta da tela a
## transforma em pixel solto. Menos que um pixel nao existe: borda seca treme.
@export_range(0.0, 1.0, 0.01) var ceu_trama: float = 0.5
## Quanto o cinza mais escuro puxa para o azul-acinzentado escuro.
@export_range(0.0, 1.0, 0.01) var ceu_sombra: float = 0.5
## Quanto a nuvem empilhada escurece: 0 e tudo branco; alto, o meio das massas
## e o banco do horizonte ficam cinza.
@export_range(0.0, 1.5, 0.01) var ceu_cinza: float = 1.0
## Brilho do topo: 1 e branco; acima, o tonemap estoura.
@export_range(0.5, 2.0, 0.05) var ceu_brilho: float = 1.1
## Tons do baixo ao topo: 0 e degrade continuo, 2-6 e banda chapada.
@export_range(0.0, 6.0, 1.0) var ceu_faixas_de_tom: float = 5.0
## Velocidade com que o ceu gira, em graus por segundo.
@export_range(0.0, 3.0, 0.05) var ceu_vento: float = 0.15

@export_group("Ator")

## 1 desenha cada corredor em sprite, recortado das folhas do Google Flow
## (`AtorSprite`), em vez do modelo 3D. E o experimento de comparar os dois na
## pista: ao vivo, sem reiniciar, para alternar e olhar o mesmo trecho. Um
## slider de 0 a 1, e nao uma caixa de marcar, porque o painel so sabe
## desenhar slider.
@export_range(0, 1, 1) var ator_sprite: int = 0
## Poses do ator por segundo; 0 e liso, uma por passo de fisica (`Cadencia`).
## Travado e o ator "digitalizado" do `DIRECAO_VISUAL.md`: a moto anda liso
## pela pista, e tudo o que ela mostra - inclinacao, virada, roda, guidao,
## joelho, soco, tombo - pula de pose em pose. 12 foi decidido jogando, na V22:
## o liso era o que os videos de referencia tem, e o travado foi o que leu
## melhor na tela de pixel.
@export_range(0, 30, 1) var ator_cadencia: int = 12


static func load_or_default() -> WorldTuning:
	if ResourceLoader.exists(SAVE_PATH):
		var res: Resource = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is WorldTuning:
			return res as WorldTuning
	return WorldTuning.new()


func save() -> void:
	ResourceSaver.save(self, SAVE_PATH)


func reset_to_default() -> void:
	var fresh := WorldTuning.new()
	for prop: Dictionary in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(prop["name"], fresh.get(prop["name"]))
