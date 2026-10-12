class_name Acelerometro
extends RefCounted
## Aceleracao longitudinal, vertical e da inclinacao do ator, lidas do proprio
## movimento, em m/s2 e rad/s2, ja filtradas.
##
## Medir no ator, e nao receber do corpo, e o que deixa o jogador e o rival -
## um com fisica, o outro parametrico na curva - usarem o mesmo ator. Um por
## ator, com o estado dele: o `Entregador` so diz onde esta e a que velocidade.

var longitudinal: float = 0.0
var vertical: float = 0.0
var rolagem: float = 0.0

var _amostras: int = 0
var _pos_anterior := Vector3.ZERO
var _vy_anterior: float = 0.0
var _v_anterior: float = 0.0
var _incl_anterior: float = 0.0
var _giro_incl_anterior: float = 0.0


func medir(delta: float, pos: Vector3, velocidade: float, inclinacao: float, caido: bool) -> void:
	# Teleporte (largada, respawn, o salto do banco de provas) nao e movimento:
	# medido, ele seria um coice de mil g na suspensao.
	if caido or _amostras > 0 and pos.distance_to(_pos_anterior) > 6.0:
		_amostras = 0
	var vy := (pos.y - _pos_anterior.y) / delta
	var giro_incl := (inclinacao - _incl_anterior) / delta
	var a_long := 0.0
	var a_vert := 0.0
	var a_rol := 0.0
	if _amostras >= 1:
		a_long = clampf((velocidade - _v_anterior) / delta, -40.0, 40.0)
	if _amostras >= 2:
		a_vert = clampf((vy - _vy_anterior) / delta, -60.0, 60.0)
		a_rol = clampf((giro_incl - _giro_incl_anterior) / delta, -60.0, 60.0)
	_amostras = mini(_amostras + 1, 2)
	_pos_anterior = pos
	_vy_anterior = vy if _amostras >= 2 else 0.0
	_v_anterior = velocidade
	_incl_anterior = inclinacao
	_giro_incl_anterior = giro_incl if _amostras >= 2 else 0.0

	# Na curva a moto inclinada carrega 1/cos da inclinacao: a 38 graus, 27% a
	# mais de peso nas molas.
	a_vert += 9.8 * (1.0 / cos(clampf(inclinacao, -1.2, 1.2)) - 1.0)
	# 60 ms: o freio do jogador liga e desliga em degrau, e a mola leria cada
	# degrau como um coice.
	var filtro := 1.0 - exp(-delta / 0.06)
	longitudinal = lerpf(longitudinal, a_long, filtro)
	vertical = lerpf(vertical, a_vert, filtro)
	rolagem = lerpf(rolagem, a_rol, filtro)
