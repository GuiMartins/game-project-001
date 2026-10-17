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


## Um quadro: confere todos os pares da frota.
func conta(carros: Array[TrafficCar]) -> void:
	for i in carros.size():
		for j in range(i + 1, carros.size()):
			var chave := "%d-%d" % [i, j]
			if not carros[i].sobrepoe(carros[j]):
				_sobrepostos.erase(chave)
			elif not _sobrepostos.has(chave):
				_sobrepostos[chave] = true
				total += 1
