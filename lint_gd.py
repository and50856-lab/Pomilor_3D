#!/usr/bin/env python3
"""Статическая проверка GDScript без Godot: отлавливает самые частые ошибки."""
import re, sys, os, glob

ROOT = os.path.dirname(os.path.abspath(__file__))
FILES = sorted(glob.glob(os.path.join(ROOT, "*.gd")))
AUTOLOADS = {"Game": "game.gd", "Settings": "settings.gd", "Sfx": "sfx.gd", "Ctl": "ctl.gd"}
NODE_OK = {"new", "get_tree", "process_mode", "add_child", "queue_free", "name", "is_inside_tree", "get_viewport",
           "set", "get", "call", "connect", "emit_signal", "get_children", "add_to_group", "is_node_ready"}
VIRTUALS = {"_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_draw", "_gui_input",
            "_enter_tree", "_exit_tree", "_init", "_notification", "_unhandled_key_input", "_initialize"}
VARIANT_FUNCS = ["max", "min", "abs", "clamp", "lerp", "sign", "floor", "ceil", "round", "snapped", "wrap",
                 "pick_random", "move_toward_v"]

errors, warns = [], []


def err(f, n, msg):
    errors.append(f"{os.path.relpath(f, ROOT)}:{n}: {msg}")


def warn(f, n, msg):
    warns.append(f"{os.path.relpath(f, ROOT)}:{n}: {msg}")


def strip_code(text):
    """Убирает комментарии и содержимое строк, оставляя структуру. Возвращает список строк."""
    out, i, n = [], 0, len(text)
    cur = []
    in_tri = False
    while i < n:
        c = text[i]
        if in_tri:
            if text.startswith('"""', i):
                in_tri = False
                i += 3
                cur.append('""')
            elif c == "\n":
                out.append("".join(cur)); cur = []; i += 1
            else:
                i += 1
            continue
        if text.startswith('"""', i):
            in_tri = True; i += 3; continue
        if c == "#":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == '"' or c == "'":
            q = c; i += 1
            while i < n and text[i] != q:
                if text[i] == "\\":
                    i += 1
                i += 1
            i += 1
            cur.append('""')
            continue
        if c == "\n":
            out.append("".join(cur)); cur = []
        else:
            cur.append(c)
        i += 1
    out.append("".join(cur))
    return out


members = {}      # class/autoload name -> set of member names
class_files = {}
all_funcs = set()
file_lines = {}

for f in FILES:
    raw = open(f, encoding="utf-8").read()
    lines = strip_code(raw)
    file_lines[f] = (raw.split("\n"), lines)
    base = os.path.basename(f)
    cname = None
    m = re.search(r"^class_name\s+(\w+)", raw, re.M)
    if m:
        cname = m.group(1)
        if cname in class_files:
            err(f, 1, f"class_name {cname} уже есть в {class_files[cname]}")
        class_files[cname] = base
    for aname, afile in AUTOLOADS.items():
        if afile == base:
            cname = aname
    mem = set()
    enums = set()
    for ln in lines:
        s = ln.strip()
        for pat in (r"^(?:static\s+)?func\s+(\w+)", r"^var\s+(\w+)", r"^const\s+(\w+)", r"^signal\s+(\w+)", r"^static var\s+(\w+)"):
            mm = re.match(pat, s)
            if mm:
                mem.add(mm.group(1))
        mm = re.match(r"^enum\s+(\w+)", s)
        if mm:
            enums.add(mm.group(1)); mem.add(mm.group(1))
    if cname:
        members[cname] = mem
    all_funcs |= mem

# ---- проверки по файлам
for f, (rawlines, lines) in file_lines.items():
    base = os.path.basename(f)
    text = "\n".join(lines)
    # extends
    if not re.search(r"^extends\s+\w+", "\n".join(rawlines), re.M):
        err(f, 1, "нет строки extends")
    # отступы
    tabs = spaces = 0
    in_tri = False
    for i, ln in enumerate(rawlines, 1):
        if ln.count('"""') % 2 == 1:
            in_tri = not in_tri
            continue
        if in_tri:
            continue
        if ln.startswith("\t"):
            tabs += 1
        elif ln.startswith(" "):
            spaces += 1
        if re.match(r"^\t* +\t", ln) or re.match(r"^ +\t", ln):
            err(f, i, "смешанные отступы (пробелы и табы)")
    if tabs and spaces:
        err(f, 1, f"в файле вперемешку табы ({tabs}) и пробелы ({spaces})")
    # скобки
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for i, ln in enumerate(lines, 1):
        for ch in ln:
            if ch in "([{":
                stack.append((ch, i))
            elif ch in ")]}":
                if not stack or stack[-1][0] != pairs[ch]:
                    err(f, i, f"лишняя скобка {ch}")
                    stack = []
                    break
                stack.pop()
    if stack:
        err(f, stack[-1][1], f"не закрыта скобка {stack[-1][0]}")
    # дубли функций
    seen = {}
    for i, ln in enumerate(lines, 1):
        mm = re.match(r"^(?:static\s+)?func\s+(\w+)", ln)
        if mm:
            if mm.group(1) in seen:
                err(f, i, f"функция {mm.group(1)} объявлена повторно (первый раз строка {seen[mm.group(1)]})")
            seen[mm.group(1)] = i
    # := с Variant
    for i, ln in enumerate(lines, 1):
        mm = re.search(r":=\s*(\w+)\s*\(", ln)
        if mm and mm.group(1) in VARIANT_FUNCS:
            err(f, i, f":= с {mm.group(1)}() даёт Variant — укажи тип явно")
        if re.search(r":=.*\.(get|pop_front|pop_back|front|back|pick_random)\(", ln):
            err(f, i, ":= со значением типа Variant — укажи тип явно")
    # приватные методы
    defined = set(seen.keys())
    for i, ln in enumerate(lines, 1):
        for mm in re.finditer(r"(?<![\w.])(_\w+)\s*\(", ln):
            nm = mm.group(1)
            if nm in VIRTUALS or nm in defined or nm.startswith("__"):
                continue
            if re.match(r"^\s*(static\s+)?func\s", ln):
                continue
            err(f, i, f"вызов {nm}(), которого нет в файле")
    # подключения сигналов к методам
    for i, ln in enumerate(lines, 1):
        for mm in re.finditer(r"\.connect\((_\w+)\)", ln):
            if mm.group(1) not in defined:
                err(f, i, f"connect к несуществующему методу {mm.group(1)}")
    # preload / load
    for i, ln in enumerate(rawlines, 1):
        for mm in re.finditer(r'(?:preload|load)\("res://([^"]+)"\)', ln):
            p = mm.group(1)
            if p.startswith("assets/") or "%s" in p:
                continue
            if not os.path.exists(os.path.join(ROOT, p)):
                err(f, i, f"нет файла res://{p}")
    # call("name")
    for i, ln in enumerate(rawlines, 1):
        for mm in re.finditer(r'\.(?:call|call_deferred|has_method)\("(\w+)"', ln):
            if mm.group(1) not in all_funcs and mm.group(1) not in NODE_OK:
                err(f, i, f'динамический вызов "{mm.group(1)}" — такого метода нет ни в одном скрипте')
    # ссылки на члены автозагрузок и классов
    for i, ln in enumerate(lines, 1):
        for mm in re.finditer(r"\b([A-Z]\w*)\.(\w+)", ln):
            cls, mem = mm.group(1), mm.group(2)
            if cls in members and cls != os.path.splitext(base)[0]:
                if mem not in members[cls] and mem not in NODE_OK and not (cls in AUTOLOADS and mem in NODE_OK):
                    # enum-значения Vehicle.Mode.X и S.X проверяются отдельно
                    err(f, i, f"{cls}.{mem}: такого члена нет в {cls}")


# ---- структура блоков
for f, (rawlines, lines) in file_lines.items():
    def indent(l):
        m = re.match(r"^([ \t]*)", l)
        lead = m.group(1)
        return lead.count("\t") + len(lead.replace("\t", "")) // 4
    prev = None
    for i, ln in enumerate(lines, 1):
        if not ln.strip():
            continue
        if prev is not None:
            pi_, pl = prev
            opener = re.match(r"^\s*(func|static func|if|elif|else|for|while|match|class)\b.*:\s*$", pl) or re.match(r"^\s*(else|try)\s*:\s*$", pl)
            # лямбды и однострочные не считаем
            if opener and not re.search(r"\bfunc\s*\(", pl) and indent(ln) <= indent(pl) and not pl.rstrip().endswith(",") :
                err(f, i, f"после '{pl.strip()}' (строка {pi_}) ожидается вложенный блок")
        if re.match(r"^\s*(elif|else)\b", ln):
            # перед elif/else тот же отступ должен иметь if/elif
            j = i - 2
            ok = False
            while j >= 0:
                if lines[j].strip():
                    if indent(lines[j]) == indent(ln) and re.match(r"^\s*(if|elif)\b", lines[j]):
                        ok = True
                        break
                    if indent(lines[j]) < indent(ln):
                        break
                j -= 1
            if not ok and re.match(r"^\s*(elif|else)\b.*:\s*$", ln):
                # else в match/for/while тоже допустим — не ругаемся на else после for/while
                pass
        if re.search(r"\bif\b[^=<>!:\"]*[^=<>!:]=[^=]", ln) and ":=" not in ln and not re.search(r"\b(var|const)\b", ln) and "==" not in ln and ">=" not in ln and "<=" not in ln and "!=" not in ln and re.match(r"^\s*(if|elif)\b", ln):
            err(f, i, "присваивание внутри условия?")
        if "else if" in ln:
            err(f, i, "else if → в GDScript нужно elif")
        prev = (i, ln)

print(f"Проверено файлов: {len(FILES)}")
for w in warns:
    print("ПРЕДУПРЕЖДЕНИЕ:", w)
for e in errors:
    print("ОШИБКА:", e)
if errors:
    print(f"Найдено ошибок: {len(errors)}")
    sys.exit(1)
print("Линтер: ошибок не найдено")
