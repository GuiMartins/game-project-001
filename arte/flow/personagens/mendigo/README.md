# Mendigo — pedestre caricato

Homem magro de cerca de 55 anos, cabelão grisalho desgrenhado, barba cheia,
nariz grande, costas curvadas e roupa marrom encardida. Design espelhável,
sem acessórios laterais. Altura de referência: 1,75 m.

Tem arte própria nas cinco ações: andando (5 vistas × 8 quadros), susto
(3 × 6), desembarcando (4 × 8), voando (4 × 8) e caída de bruços (4 × 3).
São 134 quadros selecionados de 20 vídeos aprovados. Os cinco PNG/JSON em
`assets/sprites/pedestres/` entram no mesmo índice de `PedestreSprite`.
O shader fornece o lado esquerdo por espelho. Moletom e executivo conservam
seus comportamentos anteriores; o mendigo não empresta ações de outra pessoa.

## Fontes e reprodução

[Projeto no Flow](https://flow.google.com/project/3d1f31ea-14bd-4235-8e64-69a7d441fd4e).
`personagem.json` registra URLs individuais, modelos, parâmetros, referências,
SHA-256, quadros e calibração. `originais/` preserva os downloads sem
recompressão; `prompts/` contém os textos enviados, inclusive tentativas.

Turnaround e referências de ângulo: Nano Banana 2.1. Vídeos: Omni 1.1 Flash,
16:9, 4 s, x1, 24 fps. As caminhadas frontal e de perfil são 720p; as demais
fontes são 360p, examinadas na escala final de 100 px/m. Seeds não expostas.

O susto usa Frames com referência menor num canvas verde 1280×720, deixando
espaço real para o salto. As referências frontais vêm do turnaround e da
imagem diagonal; o perfil vem do quadro 0 da caminhada. A ficha registra
recorte, redução e posição no canvas. O desembarque traseiro usa referência
sentada derivada da mesma identidade: pose do vídeo frontal e câmera traseira
gerada no histórico. A referência que saiu para a esquerda foi espelhada
horizontalmente, conforme o design, antes de gerar o vídeo à direita.

```bash
python3 tools/dev.py personagem montar arte/flow/personagens/mendigo/personagem.json --saida assets/sprites/pedestres
python3 tools/dev.py personagem concluir arte/flow/personagens/mendigo/personagem.json --atlas assets/sprites/pedestres
python3 tools/dev.py sprites-ver --sprite mendigo_andando --cena
```

O montador limpa o verde residual na borda de toda célula, inclusive sem
estabilização de altura. A correção não muda as fontes, poses ou índices;
impede a franja verde que o teste de bordas encontrou nos atlas novos.

## Conferência e limites

Os GIFs `conferencia/*-espelho.gif` mostram cada vista normal e espelhada.
Foram conferidos identidade, orientação, pés, escala, sequência, salto,
corpo horizontal/invertido no voo e três poses de bruços na caída. Os índices
selecionados não incluem membros cortados. O desembarque traseiro foi refeito
porque a primeira tentativa começava em pé e apenas agachava.

O susto frontal e diagonal tem pequena deriva vertical da geração entre
preparação e recuperação (6–10 pixels nativos). A calibração usa a posição
final em pé, com escala e chão constantes no clipe; as poses não foram
redimensionadas nem alinhadas individualmente para esconder isso.

A caminhada caricata difere da passada do manequim: o diagnóstico de movimento
aponta abertura de pernas, fase e ângulo. Esses avisos não foram silenciados.
As cinco vistas reais foram conferidas à parte. O detalhe dos clipes 360p é
menor que o das duas caminhadas 720p.

## Créditos

Teto autorizado: 210. Foram submetidos 25 vídeos: dois de 7 créditos e 23 de
4, total de **106 créditos**; cinco vídeos substituídos ficaram preservados.
As cinco gerações/edições de imagem mostraram custo de zero créditos. Não houve
compra de créditos nem alteração de plano.

## Integração no jogo

Foram conferidas as cinco ações em cena nos dois sentidos, com dez capturas
`conferencia/integrado-*.png` e a comparação `integracao-comparacao.jpg`.
No playground interativo, com o Mac desbloqueado, foram conferidos a seleção
Mendigo e o atropelamento, incluindo corpo invertido em voo e caída de bruços,
sem troca de identidade. O desembarque foi conferido na cena de animação:
o botão de carro do playground cria outro passageiro sorteado e não serve
como evidência do desembarque da pessoa selecionada.

Validação: 378 testes unitários, 14 verificações do selftest, lint e os
12 testes Python do pipeline passaram. Os baselines permanecem intactos.

A regressão visual `dev.py shots` salvou 19 quadros, mas saiu com código 1:
o piloto automático percorreu 680 m em 45 s. A mesma prova foi repetida no
commit-base `be16b68`, sem esta alteração, e reproduziu exatamente os 680 m.
Portanto o comando visual permanece reprovado por falha preexistente; não
foi declarado verde nem teve baseline alterado. As capturas das cinco ações
foram examinadas separadamente.
