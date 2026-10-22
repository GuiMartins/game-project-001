class_name VigiaDeSobreposicao
extends RefCounted
## Conta quantas vezes um carro do transito entrou em outro.
##
## O transito e parametrico na curva e nao tem fisica entre si: um carro so
## enxerga o outro pelo `path_clearance` e pelas regras de quem troca de faixa
## e de quem nasce. Se uma delas falha, nada da erro no console - o onibus so
## fica com um carro dentro. O banco de provas usa isto na corrida solta.

## Quantas vezes um par entrou em sobreposicao. Um par que fica sobreposto
## por varios quadros conta uma vez.
var total: int = 0

var _sobrepostos: Dictionary[String, bool] = {}
var _hist: Array = []


## Um quadro: confere todos os pares da frota.
func conta(carros: Array[TrafficCar]) -> void:
	var snap: Array = []
	for c in carros:
		snap.append([c.offset, c.lateral, c.speed, c.destino(), c.cruise_speed, c.meio_comprimento()])
	_hist.append(snap)
	if _hist.size() > 240:
		_hist.pop_front()
	for i in carros.size():
		for j in range(i + 1, carros.size()):
			var chave := "%d-%d" % [i, j]
			if not carros[i].sobrepoe(carros[j]):
				_sobrepostos.erase(chave)
			elif not _sobrepostos.has(chave):
				_sobrepostos[chave] = true
				total += 1
				for k in range(0, _hist.size(), 8):
					var a: Array = _hist[k][i]
					var b: Array = _hist[k][j]
					print("DIAG t-%d A off %.1f lat %.2f v %.1f alvo %.2f cruz %.1f hl %.1f | B off %.1f lat %.2f v %.1f alvo %.2f cruz %.1f hl %.1f" % [_hist.size() - k, a[0], a[1], a[2], a[3], a[4], a[5], b[0], b[1], b[2], b[3], b[4], b[5]])
