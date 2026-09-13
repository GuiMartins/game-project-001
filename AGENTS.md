# AGENTS.md

O contrato de operação deste repositório está em **[CLAUDE.md](CLAUDE.md)** —
um arquivo só, válido para qualquer agente ou pessoa. Leia antes de mexer em
qualquer coisa.

Este arquivo existe porque diferentes ferramentas procuram nomes diferentes.
O conteúdo não é duplicado aqui de propósito: contrato em dois lugares vira
contrato em zero, no dia em que um dos dois for atualizado sozinho.

O resumo mínimo, se você só vai ler isto:

```bash
python tools/dev.py setup      # primeira vez: baixa a engine fixada
python tools/dev.py test       # unitários, ~4 s
python tools/dev.py selftest   # banco de provas, ~110 s — o portão
python tools/dev.py lint
```

Os três últimos precisam passar antes de qualquer entrega. Não invoque `godot`
direto. Não crie tags nem publique releases. E se notar algo que deveria estar
na estrutura e não está, pergunte ao usuário antes de adicionar.
