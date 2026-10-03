"""Giro e deslocamento da imagem entre quadros, medidos pelo fundo.

Rastreia pontos (Lucas-Kanade) so nas bordas laterais e no topo, onde o piloto
quase nunca esta, e ajusta uma similaridade com RANSAC. O giro por quadro e o
quanto a camera rolou; o desvio-padrao do deslocamento e o tremor. Translacao
inclui a paralaxe do movimento para a frente: serve para tremor, nao para
trajetoria.

Uso: python fluxo.py <pasta_de_quadros> > fluxo.csv
"""

import glob
import math
import sys

import cv2
import numpy as np

arquivos = sorted(glob.glob(sys.argv[1] + "/*.png"))
anterior = None
mascara = None
print("t,giro,dx,dy,inliers")
for i, arq in enumerate(arquivos):
    g = cv2.cvtColor(cv2.imread(arq), cv2.COLOR_BGR2GRAY)
    h, w = g.shape
    if mascara is None:
        mascara = np.zeros_like(g)
        mascara[: int(h * 0.6), : int(w * 0.28)] = 255
        mascara[: int(h * 0.6), int(w * 0.72) :] = 255
        mascara[: int(h * 0.18), :] = 255
    if anterior is not None:
        p0 = cv2.goodFeaturesToTrack(anterior, 300, 0.01, 6, mask=mascara)
        if p0 is not None and len(p0) > 10:
            p1, ok, _ = cv2.calcOpticalFlowPyrLK(anterior, g, p0, None, winSize=(21, 21), maxLevel=3)
            ok = ok.ravel() == 1
            m, inl = cv2.estimateAffinePartial2D(p0[ok], p1[ok], method=cv2.RANSAC, ransacReprojThreshold=2.0)
            if m is not None:
                giro = math.degrees(math.atan2(m[1, 0], m[0, 0]))
                print(f"{i / 30:.3f},{giro:.3f},{m[0, 2]:.2f},{m[1, 2]:.2f},{int(inl.sum())}")
    anterior = g
