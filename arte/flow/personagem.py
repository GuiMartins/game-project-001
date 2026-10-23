"""Prepara e monta personagens por video, preservando fontes e escolhas de quadros."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import re
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parents[2]
CINCO = ['frente', 'tres_quartos_frente', 'lado', 'tres_quartos_costas', 'costas']
VOO = ['lado', 'tres_quartos_costas', 'costas', 'tres_quartos_frente']
# O shader e o ator ja usam estas dimensoes, ordens e ancoras.
ANIMACOES = {
    'andando': dict(vistas=CINCO, colunas=8, celula=[160, 200], pe=[80, 196], ancora='pes'),
    'susto': dict(vistas=CINCO[:3], colunas=6, celula=[224, 224], pe=[112, 220], ancora='chao'),
    'desembarcando': dict(vistas=['carro_de_lado', 'carro_tres_quartos_frente', 'carro_tres_quartos_costas', 'carro_de_frente'], colunas=8, celula=[256, 208], pe=[128, 204], ancora='chao'),
    'voando': dict(vistas=VOO, colunas=8, celula=[240, 240], pe=[120, 120], ancora='centro'),
    'caida': dict(vistas=VOO, colunas=3, celula=[224, 112], pe=[112, 108], ancora='pes'),
}
VISTAS = {
    'frente': 'FRONT view, facing the camera directly',
    'tres_quartos_frente': 'THREE-QUARTER FRONT view, facing the camera and the RIGHT of the frame at 45 degrees',
    'lado': 'RIGHT-facing SIDE PROFILE',
    'tres_quartos_costas': 'THREE-QUARTER BACK view, facing away and to the RIGHT of the frame at 45 degrees; never show the face',
    'costas': 'REAR view, facing directly away from the camera; never show the face',
    'carro_de_lado': 'SIDE view of the seated person, facing RIGHT',
    'carro_tres_quartos_frente': 'THREE-QUARTER FRONT view of the seated person, facing the camera and RIGHT',
    'carro_tres_quartos_costas': 'THREE-QUARTER BACK view of the seated person, facing away and RIGHT',
    'carro_de_frente': 'FRONT view of the seated person, facing the camera directly',
}
SIMETRIA = ('Design for horizontal mirroring. Matching sleeves and shoes, simple solid-color matte clothes, '
            'short or centrally tied hair. No side bags, crossbody straps, shoulder-draped clothes, handheld props, '
            'one-sided accessories or markings, text, numbers, logos, dangling parts or long loose hair. '
            'Any backpack must be centered with two matching straps. Natural asymmetric action poses are allowed.')
BASE_VIDEO = ('Use only the attached approved turnaround as the character identity reference. '
              'Keep exactly the same face, hair, skin, clothes, colors and body proportions throughout. '
              'Locked camera, full body including hands and shoes always visible with generous margins. '
              'Fixed scale and camera angle; no zoom, tracking, cuts or turns to another view. '
              'Plain solid pure green (#00FF00) background, no floor texture, props, cast shadows or text. '
              'Soft neutral frontal studio lighting. Photorealistic digitized arcade actor, hard clean edges, '
              'not pixel art. No sound. ')
ACOES = {
    'andando': 'Walk in place at a steady natural pace like on an invisible treadmill. Stay centered at the same size and ground line. Show multiple continuous complete two-step cycles, without pausing or changing direction.',
    'susto': 'Start standing still with feet on the ground for calibration. Then make ONE brief startled jump, feet visibly leaving the ground, raise the hands, land on the same ground line and look alarmed. Finish standing still. No repeated jumps. Keep visible green space above the head during the jump.',
    'desembarcando': 'Start sitting as if on an invisible car seat, feet and hands visible. Rise from the seat, step out sideways and finish fully upright and still. ONE continuous exit, no vehicle, door or seat drawn: the game supplies them. Keep the imaginary seat and ground fixed. End with a clearly visible standing pose for scale calibration.',
    'voando': 'Start fully upright for calibration, then depict ONE airborne ragdoll tumble after an impact: the body becomes horizontal, curls, turns upside down and continues the rotation. This is NOT a standing walk or jump loop. Keep the entire rotating body inside the frame. No impact object, floor or camera rotation.',
    'caida': 'Start fully upright for calibration, then fall forward, become completely prone face down on the ground, settle and remain lying still. Head points RIGHT in the side view. Do not stand up or roll onto the back. The final prone body must remain fully visible including head, hands and feet.',
}


def gravar(path: pathlib.Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def configuracao(nome: str, anim: dict) -> dict:
    cfg = dict(ANIMACOES[nome])
    largura = anim.get('largura_celula', cfg['celula'][0])
    # Acessorios pedidos podem ultrapassar a largura do corpo, sem diminuir
    # sua escala fisica nem cortar o saco nas bordas da caminhada.
    if (type(largura) is not int
            or (nome != 'andando' and largura != cfg['celula'][0])
            or not cfg['celula'][0] <= largura <= 320):
        raise ValueError('Largura de celula invalida para esta animacao.')
    cfg['celula'] = [largura, cfg['celula'][1]]
    cfg['pe'] = [largura // 2, cfg['pe'][1]]
    cfg['vistas'] = anim.get('vistas', cfg['vistas'])
    return cfg


def preparar(pasta: pathlib.Path, identificador: str, descricao: str, altura: float) -> pathlib.Path:
    if not re.fullmatch(r'[a-z][a-z0-9]*', identificador):
        raise ValueError('ID deve ter somente letras minusculas e numeros, iniciando com letra (sem sublinhado: o catalogo separa ID e animacao por ele).')
    if not math.isfinite(altura) or not 0.5 <= altura <= 1.9:
        raise ValueError('Altura deve estar entre 0,5 e 1,9 m para caber nas celulas atuais.')
    if not descricao.strip():
        raise ValueError('Descreva a identidade do personagem.')
    if pasta.exists():
        raise ValueError(f'A pasta ja existe; preserve o trabalho anterior: {pasta}')
    pasta.mkdir(parents=True)
    (pasta / 'originais').mkdir()
    (pasta / 'prompts').mkdir()
    turnaround = (f'Character turnaround for a Brazilian street pedestrian: {descricao.strip()}. '
                  'Show the same person in front, right side and back views, side by side, full body, neutral standing pose, same scale. '
                  + SIMETRIA + ' Photorealistic digitized 1990s arcade actor, not pixel art. '
                  'Plain pure green (#00FF00) background, soft even frontal lighting, hard clean edges, no shadows or labels.')
    (pasta / 'prompts/turnaround.txt').write_text(turnaround + '\n', encoding='utf-8')
    ficha = dict(versao=1, id=identificador, descricao=descricao, altura_m=altura,
                 geracao=dict(projeto_url='', modelo_imagem='', modelo_video=''),
                 turnaround=dict(arquivo='originais/turnaround.jpg', url='', sha256=''), animacoes={})
    for animacao, cfg in ANIMACOES.items():
        linhas = []
        for vista in cfg['vistas']:
            nome = f'{animacao}_{vista}'
            prompt = BASE_VIDEO + VISTAS[vista] + '. ' + ACOES[animacao] + ' ' + SIMETRIA
            (pasta / f'prompts/{nome}.txt').write_text(prompt + '\n', encoding='utf-8')
            linhas.append(dict(vista=vista, arquivo=f'originais/{nome}.mp4', prompt=f'prompts/{nome}.txt',
                               url='', modelo='', parametros={}, sha256='', quadros=[], quadro_escala=None,
                               aprovado=False))
        ficha['animacoes'][animacao] = dict(aprovada=False, linhas=linhas)
    gravar(pasta / 'personagem.json', ficha)
    return pasta / 'personagem.json'


def ler(path: pathlib.Path) -> dict:
    ficha = json.loads(path.read_text(encoding='utf-8'))
    if ficha.get('versao') != 1 or not re.fullmatch(r'[a-z][a-z0-9]*', ficha.get('id', '')):
        raise ValueError('Ficha de personagem invalida (versao ou ID).')
    altura = ficha.get('altura_m')
    if isinstance(altura, bool) or not isinstance(altura, (float, int)) or not math.isfinite(altura) or not 0.5 <= altura <= 1.9:
        raise ValueError('Altura invalida ou incompativel com as celulas atuais.')
    return ficha


def verificar_fonte(base: pathlib.Path, linha: dict) -> pathlib.Path:
    path = (base / linha['arquivo']).resolve()
    if not path.is_relative_to(base.resolve()):
        raise ValueError('A fonte precisa estar dentro da pasta do personagem.')
    if not path.is_file():
        raise ValueError(f'Fonte ausente: {path}')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if linha.get('sha256') != digest:
        raise ValueError(f'Hash ausente ou divergente: {path.name}. Registre o SHA-256 do original aprovado.')
    return path


def validar_ficha(path: pathlib.Path, animacoes: list[str]) -> dict:
    ficha = ler(path)
    base = path.parent
    geracao = ficha.get('geracao', {})
    if not all(str(geracao.get(k, '')).strip() for k in ['projeto_url', 'modelo_imagem', 'modelo_video']):
        raise ValueError('Registre projeto_url, modelo_imagem e modelo_video observados no Flow antes da montagem.')
    verificar_fonte(base, ficha['turnaround'])
    for nome in animacoes:
        anim = ficha.get('animacoes', {}).get(nome, {})
        cfg = configuracao(nome, anim)
        linhas = anim.get('linhas', [])
        vistas = anim.get('vistas', cfg['vistas'])
        quatro = ['frente', 'tres_quartos_frente', 'lado', 'costas']
        if vistas != ANIMACOES[nome]['vistas'] and not (nome == 'andando' and vistas == quatro):
            raise ValueError(f'{nome}: conjunto de vistas nao suportado pelo ator.')
        if anim.get('altura_estavel_px') is not None and (nome != 'andando' or anim['altura_estavel_px'] != round(ficha['altura_m'] * 100)):
            raise ValueError('Altura estavel so se aplica ao andar, na altura fisica da ficha.')
        if [l.get('vista') for l in linhas] != vistas:
            raise ValueError(f'{nome}: ordem ou quantidade de vistas incorreta.')
        for l in linhas:
            verificar_fonte(base, l)
            if not l.get('aprovado') or not l.get('url') or not l.get('modelo') or not l.get('parametros'):
                raise ValueError(f'{nome}/{l["vista"]}: registre aprovacao visual, URL, modelo e parametros reais.')
            prompt = (base / l['prompt']).resolve()
            if not prompt.is_relative_to(base.resolve()) or not prompt.is_file() or not prompt.read_text(encoding='utf-8').strip():
                raise ValueError(f'{nome}/{l["vista"]}: prompt original ausente.')
            q = l.get('quadros', [])
            if (len(q) != cfg['colunas'] or any(type(i) is not int or i < 0 for i in q)
                    or any(a >= b for a, b in zip(q, q[1:]))):
                raise ValueError(f'{nome}/{l["vista"]}: selecione {cfg["colunas"]} indices crescentes de quadros (base zero).')
            if type(l.get('quadro_escala')) is not int or l['quadro_escala'] < 0:
                raise ValueError(f'{nome}/{l["vista"]}: marque um quadro em pe para calibrar a escala.')
    return ficha


def extrair(video: pathlib.Path, cache: pathlib.Path) -> list[pathlib.Path]:
    # So reutiliza uma extracao concluida, nunca os primeiros PNG de um FFmpeg interrompido.
    pasta = cache / (video.stem + '-' + hashlib.sha256(video.read_bytes()).hexdigest())
    pasta.mkdir(parents=True, exist_ok=True)
    pronto = pasta / 'concluido.json'
    if not pronto.exists():
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(video), '-fps_mode', 'passthrough', str(pasta / 'f%06d.png')], check=True)
        gravar(pronto, {'quadros': len(list(pasta.glob('f*.png')))})
    quadros = sorted(pasta.glob('f*.png'))
    if len(quadros) != json.loads(pronto.read_text())['quadros'] or not quadros:
        raise ValueError(f'Cache incompleto: apague somente {pasta} e extraia novamente.')
    return quadros


def inspecionar(video: pathlib.Path, saida: pathlib.Path, cache: pathlib.Path) -> None:
    from PIL import Image, ImageDraw
    quadros = extrair(video, cache)
    colunas = 12
    folha = Image.new('RGB', (colunas * 160, math.ceil(len(quadros) / colunas) * 108), '#333333')
    desenho = ImageDraw.Draw(folha)
    for i, path in enumerate(quadros):
        with Image.open(path) as origem:
            im = origem.convert('RGB')
        im.thumbnail((160, 90))
        x, y = (i % colunas) * 160, (i // colunas) * 108
        folha.paste(im, (x, y))
        desenho.text((x + 2, y + 90), str(i), fill='white')
    saida.parent.mkdir(parents=True, exist_ok=True)
    folha.save(saida)
    info = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(video)
    ]))
    gravar(saida.with_suffix('.json'), dict(sha256=hashlib.sha256(video.read_bytes()).hexdigest(),
                                          quadros=len(quadros), midia=info))


def recortar(quadros: list[pathlib.Path], selecao: list[int], escala: int, cfg: dict, altura: float):
    import numpy as np
    from PIL import Image
    # Reutiliza os mesmos limiares de cor do experimento aprovado.
    sys.path.insert(0, str(pathlib.Path(__file__).parent / 'sem_referencia'))
    from montar_folha import alfa, caixa
    if max([escala, *selecao]) >= len(quadros):
        raise ValueError('Indice fora do video; confira a quantidade real de quadros.')
    def pixels(i):
        with Image.open(quadros[i]) as origem:
            a = np.asarray(origem.convert('RGB')).astype(np.float32)
        al = alfa(a)
        if not np.any(al > 0.5):
            raise ValueError(f'Quadro {i} vazio depois do chroma key.')
        box = caixa(al)
        if box[0] <= 1 or box[1] <= 1 or box[2] >= a.shape[1] - 2 or box[3] >= a.shape[0] - 2:
            raise ValueError(f'Quadro {i}: corpo cortado ou fundo diferente de verde.')
        return a, al, box
    _, _, ref = pixels(escala)
    altura_ref = float(ref[3] - ref[1])
    if altura_ref <= 0:
        raise ValueError('Referencia de escala sem altura.')
    sc = altura * 100.0 / altura_ref
    celulas = []
    for i in selecao:
        a, al, box = pixels(i)
        a[..., 1] = np.where(al < 1, np.minimum(a[..., 1], np.maximum(a[..., 0], a[..., 2]) + 8), a[..., 1])
        ys, xs = np.where(al > 0.5)
        if cfg['ancora'] == 'centro':
            cx, cy = (box[0] + box[2]) * 0.5, (box[1] + box[3]) * 0.5
        else:
            torso = ys < box[1] + 0.4 * altura_ref
            cx = float(xs[torso].mean()) if cfg['ancora'] != 'pes_caida' else (box[0] + box[2]) * 0.5
            cy = ref[3] if cfg['ancora'] == 'chao' else box[3]
        im = Image.fromarray(np.dstack([a, al * 255]).astype(np.uint8), 'RGBA')
        im = im.resize((round(im.width * sc), round(im.height * sc)), Image.Resampling.LANCZOS)
        px = np.asarray(im).copy()
        px[..., 3] = np.where(px[..., 3] > 128, 255, 0)
        im = Image.fromarray(px, 'RGBA')
        x, y = round(cfg['pe'][0] - cx * sc), round(cfg['pe'][1] - cy * sc)
        b = im.getbbox()
        w, h = cfg['celula']
        if b is None or b[0] + x < 0 or b[1] + y < 0 or b[2] + x > w or b[3] + y > h:
            raise ValueError(f'Quadro {i} nao cabe na celula {w}x{h}; corrija enquadramento/pose, nao corte membros.')
        cel = Image.new('RGBA', (w, h))
        cel.paste(im, (x, y), im)
        if cfg.get('altura_estavel_px'):
            # Correcao optativa aprovada para videos que respiram de escala;
            # conserva proporcoes e a ancora dos pes, sem esconder cortes.
            b = cel.getbbox()
            corpo = cel.crop(b)
            h = cfg['altura_estavel_px']
            largura = round(corpo.width * h / corpo.height)
            corpo = corpo.resize((largura, h), Image.Resampling.LANCZOS)
            x = round((b[0] + b[2]) * 0.5 - largura * 0.5)
            y = cfg['pe'][1] - h
            if x < 0 or x + largura > w or y < 0:
                raise ValueError('Corpo estabilizado nao cabe na celula; nao corte membros.')
            cel = Image.new('RGBA', (w, cfg['celula'][1]))
            cel.alpha_composite(corpo, (x, y))
        # O chroma deixa verde em pixels quase opacos e o resize mistura essa
        # cor na borda, mesmo sem estabilizacao de altura. Limpa toda celula
        # no formato de corte duro que o shader realmente desenha.
        px = np.asarray(cel).copy()
        mask = px[..., 3] > 128
        px[..., 3] = np.where(mask, 255, 0)
        pad = np.pad(mask, 1)
        interior = (pad[1:-1, :-2] & pad[1:-1, 2:]
                    & pad[:-2, 1:-1] & pad[2:, 1:-1])
        limite = np.maximum(px[..., 0].astype(int), px[..., 2].astype(int)) + 8
        px[..., 1] = np.where(mask & ~interior, np.minimum(px[..., 1], limite), px[..., 1])
        cel = Image.fromarray(px, 'RGBA')
        celulas.append(cel)
    return celulas


def montar(path: pathlib.Path, nomes: list[str], destino: pathlib.Path, cache: pathlib.Path) -> list[pathlib.Path]:
    from PIL import Image
    ficha = validar_ficha(path, nomes)
    produtos = []
    # Monta tudo antes de escrever para nao deixar metade de um lote que falhou.
    for nome in nomes:
        anim = ficha['animacoes'][nome]
        cfg = configuracao(nome, anim)
        if anim.get('altura_estavel_px'):
            cfg['altura_estavel_px'] = anim['altura_estavel_px']
        if nome == 'caida':
            cfg['ancora'] = 'pes_caida'
        atlas = Image.new('RGBA', (cfg['celula'][0] * cfg['colunas'], cfg['celula'][1] * len(cfg['vistas'])))
        for r, linha in enumerate(ficha['animacoes'][nome]['linhas']):
            video = verificar_fonte(path.parent, linha)
            quadros = extrair(video, cache)
            celulas = recortar(quadros, linha['quadros'], linha['quadro_escala'], cfg, ficha['altura_m'])
            for c, cel in enumerate(celulas):
                atlas.paste(cel, (c * cfg['celula'][0], r * cfg['celula'][1]))
        meta = dict(altura_m=ficha['altura_m'], animacao=nome, celula=cfg['celula'], colunas=cfg['colunas'],
                    espelha_o_lado_esquerdo=True, linhas=cfg['vistas'], pe=cfg['pe'], pixels_por_metro=100.0)
        produtos.append((nome, atlas, meta))
    destino.mkdir(parents=True, exist_ok=True)
    arquivos = []
    for nome, atlas, meta in produtos:
        png = destino / f'{ficha["id"]}_{nome}.png'
        atlas.save(png)
        gravar(png.with_suffix('.json'), meta)
        arquivos.append(png)
    return arquivos


def concluir(path: pathlib.Path, atlas: pathlib.Path) -> None:
    from PIL import Image
    dados = ler(path)
    nomes = dados.get('escopo', list(ANIMACOES))
    if nomes not in [list(ANIMACOES), ['andando'], ['andando', 'voando', 'caida']]:
        raise ValueError('Escopo deve ser completo, caminhada ou caminhada e atropelamento.')
    ficha = validar_ficha(path, nomes)
    for nome in nomes:
        anim = ficha['animacoes'][nome]
        cfg = configuracao(nome, anim)
        png = atlas / f'{ficha["id"]}_{nome}.png'
        if not anim.get('aprovada') or not png.is_file() or anim.get('atlas_sha256') != hashlib.sha256(png.read_bytes()).hexdigest():
            raise ValueError(f'{nome}: falta atlas aprovado e seu hash depois da conferencia visual.')
        meta = json.loads(png.with_suffix('.json').read_text(encoding='utf-8'))
        esperado = dict(altura_m=ficha['altura_m'], animacao=nome, celula=cfg['celula'], colunas=cfg['colunas'],
                        espelha_o_lado_esquerdo=True, linhas=cfg['vistas'], pe=cfg['pe'], pixels_por_metro=100.0)
        with Image.open(png) as im:
            tamanho = im.size
        if meta != esperado or tamanho != (cfg['celula'][0] * cfg['colunas'], cfg['celula'][1] * len(cfg['vistas'])):
            raise ValueError(f'{nome}: atlas/ficha divergem do contrato do ator.')


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='comando', required=True)
    novo = sub.add_parser('preparar', help='cria ficha e prompts, sem gerar ou gastar creditos')
    novo.add_argument('id')
    novo.add_argument('--descricao', required=True)
    novo.add_argument('--altura', type=float, default=1.75)
    novo.add_argument('--pasta', type=pathlib.Path)
    p = sub.add_parser('inspecionar', help='gera contato de todos os quadros numerados e metadados')
    p.add_argument('video', type=pathlib.Path)
    p.add_argument('--saida', type=pathlib.Path, required=True)
    p.add_argument('--cache', type=pathlib.Path, default=RAIZ / '.dev/personagens')
    p = sub.add_parser('concluir', help='exige cinco animacoes aprovadas e os hashes dos atlas')
    p.add_argument('ficha', type=pathlib.Path)
    p.add_argument('--atlas', type=pathlib.Path, required=True)
    for comando in ['validar', 'montar']:
        p = sub.add_parser(comando)
        p.add_argument('ficha', type=pathlib.Path)
        p.add_argument('--animacao', choices=list(ANIMACOES))
        if comando == 'montar':
            p.add_argument('--saida', type=pathlib.Path, required=True)
            p.add_argument('--cache', type=pathlib.Path, default=RAIZ / '.dev/personagens')
    args = parser.parse_args(argv)
    try:
        if args.comando == 'preparar':
            print(preparar(args.pasta or RAIZ / 'arte/flow/personagens' / args.id, args.id, args.descricao, args.altura))
        elif args.comando == 'inspecionar':
            inspecionar(args.video, args.saida, args.cache)
            print(args.saida)
        elif args.comando == 'concluir':
            concluir(args.ficha, args.atlas)
            print('Animacoes do escopo aprovadas, fontes e hashes conferidos. Confira tambem a integracao no jogo.')
        else:
            nomes = [args.animacao] if args.animacao else ler(args.ficha).get('escopo', list(ANIMACOES))
            if args.comando == 'validar':
                validar_ficha(args.ficha, nomes)
                print('Fontes, prompts, metadados e selecao de quadros conferidos. A aprovacao visual do atlas ainda e necessaria.')
            else:
                for path in montar(args.ficha, nomes, args.saida, args.cache):
                    print(path)
    except ImportError:
        parser.exit(1, 'Instale as dependencias com python3 tools/dev.py personagem setup.\n')
    except (ValueError, OSError, KeyError, TypeError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f'Erro: {exc}\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
