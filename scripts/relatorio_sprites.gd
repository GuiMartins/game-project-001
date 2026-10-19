extends SceneTree
## O relatorio dos sprites, em texto e em imagem, sem abrir janela.
##
##     python tools/dev.py sprites-relatorio
##
## Faz o que o testador faz ao abrir (varre as folhas e analisa cada uma), mas
## escreve em `.dev/sprites_relatorio/`: um `relatorio.md` e, para cada folha com
## quadro marcado, a folha com os quadros em vermelho e a comparacao com a
## referencia 3D. Serve para rodar sem tela, e para colar num PR ou numa conversa
## com quem desenha.
##
## Sai com 1 se alguma folha tem defeito de borda (meio-tom, franja verde, pixel
## solto): ao contrario de pose e de movimento, que dependem de a referencia
## ter acertado, borda suja e defeito sem discussao e o shader do sprite nao
## perdoa. Os avisos de pose e movimento so informam.

const SAIDA: String = "res://.dev/sprites_relatorio"


func _initialize() -> void:
	var saida := SAIDA
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
	var pasta := ProjectSettings.globalize_path(saida)
	DirAccess.make_dir_recursive_absolute(pasta)
	var itens: Array[CatalogoSprites.Item] = CatalogoSprites.varrer()
	for item in itens:
		AnaliseSprites.analisar(item)
	var texto := _relatorio(itens)
	var arquivo := FileAccess.open(pasta.path_join("relatorio.md"), FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()
	for item in itens:
		_imagens(item, pasta)
	print(texto)
	print("\n+ %s" % pasta.path_join("relatorio.md"))
	var sujas := 0
	for item in itens:
		for aviso in item.todos_os_avisos():
			if aviso.begins_with("borda:"):
				sujas += 1
	quit(1 if sujas > 0 else 0)


func _relatorio(itens: Array[CatalogoSprites.Item]) -> String:
	var linhas: PackedStringArray = ["# Relatorio dos sprites", ""]
	var com_aviso := 0
	for item in itens:
		com_aviso += 1 if item.tem_aviso() else 0
	linhas.append("%d folhas, %d com aviso." % [itens.size(), com_aviso])
	linhas.append("")
	var recorrentes := CatalogoSprites.recorrentes(itens)
	linhas.append("## Suspeitas da referencia")
	linhas.append("")
	linhas.append(
		"O mesmo quadro marcado em varias pessoas: as cinco partem da mesma referencia 3D."
	)
	linhas.append("")
	if recorrentes.is_empty():
		linhas.append("- nenhuma")
	for suspeita in recorrentes:
		linhas.append("- %s" % suspeita)
	linhas.append("")
	linhas.append("## Defeitos da propria referencia")
	linhas.append("")
	var vistas: Dictionary = {}
	for item in itens:
		if item.referencia == null or vistas.has(item.animacao):
			continue
		vistas[item.animacao] = true
		if item.referencia.avisos.is_empty():
			linhas.append("- **%s**: sem defeito que se meca" % item.animacao)
		for aviso in item.referencia.avisos:
			linhas.append("- **%s**: %s" % [item.animacao, aviso])
	linhas.append("")
	linhas.append("## Folhas")
	for item in itens:
		linhas.append("")
		var avisos := item.todos_os_avisos()
		linhas.append(
			(
				"### %s  (%s)"
				% [item.id, "sem avisos" if avisos.is_empty() else "%d avisos" % avisos.size()]
			)
		)
		for aviso in avisos:
			linhas.append("- %s" % aviso)
		if not item.notas_quadro.is_empty():
			linhas.append("- ver `%s_marcada.png`" % item.id)
			if item.referencia != null:
				linhas.append("- ver `%s_comparacao.png`" % item.id)
	linhas.append("")
	return "\n".join(linhas)


func _imagens(item: CatalogoSprites.Item, pasta: String) -> void:
	if item.notas_quadro.is_empty():
		return
	var marcada := ExportaSprites.folha_marcada(item)
	if marcada != null:
		marcada.save_png(pasta.path_join("%s_marcada.png" % item.id))
	var comparacao := ExportaSprites.comparacao(item)
	if comparacao != null:
		comparacao.save_png(pasta.path_join("%s_comparacao.png" % item.id))
