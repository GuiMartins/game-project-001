// O ator em sprite de quem a camera segue: o mesmo, gravando a marca do foco
// no stencil (ver `foco.gdshader`). O overlay do `Foco` nao serve aqui: ele
// redesenharia o quad sem o billboard nem o recorte do alfa, e marcaria um
// retangulo deitado no lugar do piloto.
shader_type spatial;
stencil_mode write, compare_always, 1;

#include "res://scripts/ator_sprite.gdshaderinc"
