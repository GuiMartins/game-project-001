extends RefCounted
class_name Layers
## Camadas de fisica do prototipo, nomeadas.

const PLAYER: int = 1 << 0
const WORLD: int = 1 << 1   ## Carros parados, postes, guard-rail.
const RIVAL: int = 1 << 2
const PLAYER_HIT: int = 1 << 3
const RIVAL_HIT: int = 1 << 4
