"""Regressoes do contrato entre fontes de video, ancoras e atlas do jogo."""
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

RAIZ = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('personagem', RAIZ / 'arte/flow/personagem.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class PersonagemTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = pathlib.Path(self.tmp.name)

    def preparar(self):
        return p.preparar(self.base / 'npc', 'teste', 'Cabelo curto, camiseta azul, calca cinza.', 1.75)

    def frames(self):
        paths = []
        for i in range(10):
            im = Image.new('RGB', (400, 300), '#00ff00')
            d = ImageDraw.Draw(im)
            # O quadro 0 calibra em pe; o seguinte esta 15 px acima do solo.
            subida = 15 if i == 1 else 0
            d.rectangle((180, 50 - subida, 220, 225 - subida), fill='#204090')
            path = self.base / f'quadro-{i}.png'
            im.save(path)
            paths.append(path)
        return paths

    def test_preparar_sem_sobrescrever_e_prompts_completos(self):
        path = self.preparar()
        ficha = p.ler(path)
        self.assertEqual(set(ficha['animacoes']), set(p.ANIMACOES))
        self.assertEqual(len(list((path.parent / 'prompts').glob('*.txt'))), 21)
        for nome, anim in ficha['animacoes'].items():
            self.assertEqual([l['vista'] for l in anim['linhas']], p.ANIMACOES[nome]['vistas'])
            self.assertTrue(all(not l['aprovado'] for l in anim['linhas']))
        with self.assertRaises(ValueError):
            self.preparar()
        with self.assertRaisesRegex(ValueError, 'ID'):
            p.preparar(self.base / 'outro', '../escape', 'descricao', 1.75)

    def test_ficha_vazia_nao_passa_por_aprovada(self):
        path = self.preparar()
        with self.assertRaisesRegex(ValueError, 'modelo'):
            p.validar_ficha(path, ['andando'])

    def test_hash_divergente_nao_usa_outra_tentativa(self):
        path = self.base / 'teste.mp4'
        path.write_bytes(b'video novo')
        with self.assertRaisesRegex(ValueError, 'Hash'):
            p.verificar_fonte(self.base, {'arquivo': path.name, 'sha256': 'hash antigo'})

    def test_formatos_coincidem_com_fichas_reais(self):
        for nome, cfg in p.ANIMACOES.items():
            ficha = json.loads((RAIZ / f'assets/sprites/pedestres/praia_{nome}.json').read_text())
            for campo in ['celula', 'pe', 'colunas']:
                self.assertEqual(cfg[campo], ficha[campo], (nome, campo))
            self.assertEqual(cfg['vistas'], ficha['linhas'])

    def test_susto_preserva_altura_do_salto(self):
        imgs = self.frames()
        cfg = p.ANIMACOES['susto']
        celulas = p.recortar(imgs, [0, 1, 2, 3, 4, 5], 0, cfg, 1.75)
        self.assertEqual(celulas[0].getbbox()[3] - celulas[1].getbbox()[3], 15)
        self.assertEqual(celulas[0].getbbox()[3] - celulas[0].getbbox()[1], celulas[1].getbbox()[3] - celulas[1].getbbox()[1])

    def test_andar_alinha_pes_sem_alterar_escala(self):
        imgs = self.frames()
        celulas = p.recortar(imgs, list(range(8)), 0, p.ANIMACOES['andando'], 1.75)
        self.assertEqual(len({im.getbbox()[3] for im in celulas}), 1)

    def test_altura_estavel_corrige_escala_e_preserva_pes(self):
        imgs = self.frames()
        im = Image.new('RGB', (400, 300), '#00ff00')
        ImageDraw.Draw(im).rectangle((175, 40, 225, 225), fill='#204090')
        im.save(imgs[2])
        cfg = dict(p.ANIMACOES['andando'], altura_estavel_px=175)
        cells = p.recortar(imgs, list(range(8)), 0, cfg, 1.75)
        self.assertEqual({im.getbbox()[3] - im.getbbox()[1] for im in cells}, {175})
        self.assertEqual({im.getbbox()[3] for im in cells}, {196})
        # Normalizacao nao transforma membros fora do enquadramento em fonte valida.
        im = Image.new('RGB', (400, 300), '#00ff00')
        ImageDraw.Draw(im).rectangle((175, 40, 225, 299), fill='#204090')
        im.save(imgs[2])
        with self.assertRaisesRegex(ValueError, 'cortado'):
            p.recortar(imgs, list(range(8)), 0, cfg, 1.75)

    def test_voo_centra_corpo_e_caida_cabe_deitada(self):
        imgs = self.frames()
        celulas = p.recortar(imgs, list(range(8)), 0, p.ANIMACOES['voando'], 1.75)
        for im in celulas:
            b = im.getbbox()
            self.assertAlmostEqual((b[1] + b[3]) / 2, 120, delta=1)
        for i in [1, 2, 3]:
            im = Image.new('RGB', (400, 300), '#00ff00')
            ImageDraw.Draw(im).rectangle((110, 200, 285, 230), fill='#204090')
            im.save(imgs[i])
        cfg = dict(p.ANIMACOES['caida'], ancora='pes_caida')
        caida = p.recortar(imgs, [1, 2, 3], 0, cfg, 1.75)
        self.assertTrue(all(im.getbbox()[2] - im.getbbox()[0] > 170 for im in caida))

    def test_corte_e_indice_invalido_sao_rejeitados(self):
        imgs = self.frames()
        with self.assertRaisesRegex(ValueError, 'Indice'):
            p.recortar(imgs, [99], 0, p.ANIMACOES['andando'], 1.75)
        im = Image.new('RGB', (400, 300), '#00ff00')
        ImageDraw.Draw(im).rectangle((0, 10, 40, 185), fill='red')
        im.save(imgs[1])
        with self.assertRaisesRegex(ValueError, 'cortado'):
            p.recortar(imgs, [1], 0, p.ANIMACOES['andando'], 1.75)

    def test_todas_animacoes_geram_atlas_e_ficha(self):
        path = self.preparar()
        ficha = p.ler(path)
        ficha['geracao'] = dict(projeto_url='https://flow.google.com/project/teste', modelo_imagem='fixture', modelo_video='fixture')
        turnaround = path.parent / ficha['turnaround']['arquivo']
        turnaround.write_bytes(b'fixture')
        ficha['turnaround']['sha256'] = hashlib.sha256(b'fixture').hexdigest()
        for nome, anim in ficha['animacoes'].items():
            for linha in anim['linhas']:
                fonte = path.parent / linha['arquivo']
                fonte.write_bytes(b'fixture')
                linha.update(sha256=hashlib.sha256(b'fixture').hexdigest(), modelo='fixture',
                             parametros={'fps': 24}, url='https://flow.google.com/fixture', aprovado=True,
                             quadro_escala=0, quadros=list(range(p.ANIMACOES[nome]['colunas'])))
        p.gravar(path, ficha)
        imgs = self.frames()
        # Na caida, use uma figura deitada em quadros proprios e a referencia em pe.
        deitadas = [imgs[0]]
        for i in range(8):
            im = Image.new('RGB', (400, 300), '#00ff00')
            ImageDraw.Draw(im).rectangle((110, 200, 285, 230), fill='#204090')
            q = self.base / f'deitado-{i}.png'
            im.save(q)
            deitadas.append(q)
        for linha in ficha['animacoes']['caida']['linhas']:
            linha['quadros'] = [1, 2, 3]
        p.gravar(path, ficha)
        with patch.object(p, 'extrair', side_effect=lambda video, _: deitadas if video.name.startswith('caida') else imgs):
            produtos = p.montar(path, list(p.ANIMACOES), self.base / 'atlas', self.base / 'cache')
        self.assertEqual(len(produtos), 5)
        for png in produtos:
            meta = json.loads(png.with_suffix('.json').read_text())
            self.assertTrue(meta['espelha_o_lado_esquerdo'])
            with Image.open(png) as im:
                self.assertEqual(im.size, (meta['celula'][0] * meta['colunas'], meta['celula'][1] * len(meta['linhas'])))
        with self.assertRaisesRegex(ValueError, 'aprovado'):
            p.concluir(path, self.base / 'atlas')
        for nome in p.ANIMACOES:
            png = self.base / 'atlas' / f'teste_{nome}.png'
            ficha['animacoes'][nome].update(aprovada=True, atlas_sha256=hashlib.sha256(png.read_bytes()).hexdigest())
        p.gravar(path, ficha)
        p.concluir(path, self.base / 'atlas')
        png.write_bytes(b'alteracao posterior a aprovacao')
        with self.assertRaisesRegex(ValueError, 'hash'):
            p.concluir(path, self.base / 'atlas')

    def test_ffmpeg_cache_e_contato_com_video_real(self):
        import shutil
        if not shutil.which('ffmpeg'):
            self.skipTest('FFmpeg ausente')
        imgs = self.frames()
        # Video sem perda permite conferir extracao sem depender de um modelo generativo.
        video = self.base / 'teste.mkv'
        subprocess.run(['ffmpeg', '-v', 'error', '-framerate', '24', '-i', str(self.base / 'quadro-%d.png'), '-c:v', 'ffv1', str(video)], check=True)
        a = p.extrair(video, self.base / 'cache')
        self.assertEqual(len(a), 10)
        self.assertEqual(p.extrair(video, self.base / 'cache'), a)
        contato = self.base / 'contato.png'
        p.inspecionar(video, contato, self.base / 'cache')
        self.assertEqual(json.loads(contato.with_suffix('.json').read_text())['quadros'], 10)
        self.assertTrue(contato.is_file())


if __name__ == '__main__':
    unittest.main()
