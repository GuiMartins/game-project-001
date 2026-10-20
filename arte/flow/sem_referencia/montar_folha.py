"""Monta a folha de andar (8 linhas x 8 quadros: 5 angulos e o lado esquerdo desenhado de verdade) a partir dos videos do Flow.

Uso: python montar_folha.py <pasta de trabalho> <saida.png>
Precisa de Pillow, numpy e ffmpeg. Cada video e a mesma pessoa andando no lugar,
camera fixa, fundo verde. Por video: tira o verde, acha o ciclo (o trecho em que
a pose se repete), pega 8 quadros igualmente espacados dentro dele e alinha pelo
pe e pelo centro do tronco. A ordem das linhas e a do `PedestreSprite`.
"""
import subprocess, sys, pathlib
import numpy as np
from PIL import Image

AQUI = pathlib.Path(__file__).parent
# linha -> video. A ordem e a das linhas da ficha (frente ... costas).
LINHAS = [
    "frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas",
    "tres_quartos_costas_esq", "lado_esq", "tres_quartos_frente_esq",
]
CW, CH, PE, ALT = 160, 200, (80, 196), 175  # celula, ponto do pe, altura em pixels
N = 8


def extrai(video: pathlib.Path, pasta: pathlib.Path) -> list[pathlib.Path]:
    pasta.mkdir(parents=True, exist_ok=True)
    if not list(pasta.glob("f*.png")):
        subprocess.run(["ffmpeg", "-v", "error", "-i", str(video), str(pasta / "f%03d.png")], check=True)
    return sorted(pasta.glob("f*.png"))


def alfa(a: np.ndarray) -> np.ndarray:
    d = a[..., 1] - np.maximum(a[..., 0], a[..., 2])  # quanto o verde domina
    return np.clip(1 - (d - 30) / 50, 0, 1)


def caixa(al: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(al > 0.5)
    return xs.min(), ys.min(), xs.max(), ys.max()


def linha(video: pathlib.Path, trabalho: pathlib.Path) -> list[Image.Image]:
    quadros = extrai(video, trabalho / video.stem)
    pequenos = [np.asarray(Image.open(p).convert("RGB").resize((160, 90))).astype(np.float32) for p in quadros]
    # laco: o par (s, s+P) mais parecido. P e o ciclo de dois passos, ~1,4 s a 24 fps.
    melhor = None
    for P in range(28, 41):
        for s in range(20, len(quadros) - P - 1):
            e = np.abs(pequenos[s] - pequenos[s + P]).mean()
            if melhor is None or e < melhor[0]:
                melhor = (e, s, P)
    _, s, P = melhor
    idx = [int(round(s + k * P / N)) for k in range(N)]
    if video.stem.endswith("_esq"):
        # O Flow desenha a perna dos videos virados para a esquerda com o sentido
        # do passo dos da direita: o pe de apoio desliza para a frente, e a pessoa
        # faz moonwalk. Medido pela assimetria da velocidade do pe (devagar para
        # tras, rapido para frente): os tres sairam com o sinal trocado. Tocar o
        # ciclo ao contrario conserta, e o ciclo e simetrico no tempo.
        idx = idx[::-1]
    print(f"{video.stem}: laco em {s}, periodo {P}, quadros {idx}")
    # escala e chao pela mediana do video inteiro, para o pe nao pular de quadro a quadro
    amostra = [caixa(alfa(np.asarray(Image.open(quadros[i]).convert("RGB")).astype(np.float32))) for i in range(0, len(quadros), 8)]
    H = float(np.median([b[3] - b[1] for b in amostra]))
    sc = ALT / H
    celulas = []
    for i in idx:
        a = np.asarray(Image.open(quadros[i]).convert("RGB")).astype(np.float32)
        al = alfa(a)
        g2 = np.minimum(a[..., 1], np.maximum(a[..., 0], a[..., 2]) + 8)  # despill
        a[..., 1] = np.where(al < 1, g2, a[..., 1])
        x0, y0, x1, y1 = caixa(al)
        ys, xs = np.where(al > 0.5)
        cx = xs[ys < y0 + 0.4 * H].mean()  # centro do tronco: estavel entre quadros
        im = Image.fromarray(np.dstack([a, al * 255]).astype(np.uint8), "RGBA")
        im = im.resize((round(im.width * sc), round(im.height * sc)), Image.LANCZOS)
        # o shader do jogo corta o alfa em 0.5: alfa duro aqui, sem franja meio transparente
        px = np.asarray(im).copy()
        px[..., 3] = np.where(px[..., 3] > 128, 255, 0)
        im = Image.fromarray(px, "RGBA")
        cel = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        # um pe esta sempre no chao: o ponto mais baixo de cada quadro cai na linha do pe,
        # em vez de seguir a camera do video (que deriva alguns pixels)
        cel.paste(im, (round(PE[0] - cx * sc), round(PE[1] - y1 * sc)), im)
        celulas.append(cel)
    return celulas


def main() -> None:
    trabalho, saida = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    folha = Image.new("RGBA", (CW * N, CH * len(LINHAS)), (0, 0, 0, 0))
    for r, nome in enumerate(LINHAS):
        for c, cel in enumerate(linha(AQUI / f"{nome}.mp4", trabalho)):
            folha.paste(cel, (c * CW, r * CH))
    folha.save(saida)


main()
