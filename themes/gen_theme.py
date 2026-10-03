"""Writes Lucid Light.xml and Lucid Dark.xml from Notepad++'s stylers.model.xml.

Every lexer style gets a role (text, keyword, type, string, number, special, function, comment, error) from its
name, or, when the name says nothing, from the hue of its colour in the model. The model's layout, order and
comments are kept: only fgColor, bgColor and fontStyle change, so the themes have every lexer and style the model
has. Usage: python3 gen_theme.py <stylers.model.xml> <DarkModeDefault.xml> <output folder>"""
import os, re, sys
from colormath import oklch, wcag_worst
from palette import build, blend, ALPHA

OVERRIDES = {
    ('javascript', 'TEMPLATE LIT. (CLIENT)'): 'string', ('javascript', 'TEMPLATE LIT. (SERVER)'): 'string',
    ('mssql', 'COL NAME'): 'text', ('mssql', 'SYSTEM STORED PROC'): 'function', ('raku', 'MU'): 'text',
    ('tcl', 'SUB BRACE'): 'text', ('gdscript', 'NODEPATH'): 'special', ('nsis', 'USER DEFINED'): 'keyword',
    ('objc', 'QUALIFIER'): 'keyword', ('registry', 'REMOVED KEY'): 'error-fg', ('registry', 'ADDED KEY'): 'function',
    ('smalltalk', 'ASSIGN'): 'text', ('postscript', 'DSC VALUE'): 'string', ('postscript', 'PAREN ARRAY'): 'text',
    ('baanc', 'USER DEFINED'): 'keyword', ('cmake', 'FOREACHDEF'): 'keyword', ('cmake', 'WHILEDEF'): 'keyword',
    ('cmake', 'IFDEF'): 'keyword', ('cmake', 'MACRODEF'): 'keyword', ('cmake', 'USER DEFINED'): 'function',
    ('batch', 'HIDE SYMBOL'): 'special', ('ruby', 'INSTANCE VAR'): 'special',
    ('forth', 'DEFWORDS'): 'keyword', ('forth', 'PREWORD1'): 'keyword', ('ihex', 'RECSTART'): 'special',
    ('srec', 'RECSTART'): 'special', ('tehex', 'RECSTART'): 'special',
}
for _h in ('H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'STRONG', 'STRONG 2 (NOT USED)'):
    OVERRIDES[('txt2tags', _h)] = 'keyword'
for _n, _r in (('CODE', 'string'), ('CODE2', 'string'), ('CODEBLOCK', 'string'), ('BLOCKQUOTE', 'comment'),
               ('EM1 (ITALIC)', 'text'), ('EM2 (UNDERLINE)', 'text'), ('OPTION', 'special'), ('POSTPROC', 'special'),
               ('PRECHAR (NOT USED)', 'special'), ('OLIST', 'special'), ('ULIST', 'special'), ('HRULE', 'comment'),
               ('STRIKEOUT', 'comment'), ('LINK', 'keyword')):
    OVERRIDES[('txt2tags', _n)] = _r

def role_by_name(lexer, name):
    n = name.upper()
    if (lexer, n) in OVERRIDES:
        return OVERRIDES[(lexer, n)]
    if lexer == 'escseq':
        return 'escseq'
    if lexer == 'diff':
        return {'COMMAND': 'keyword', 'HEADER': 'special', 'POSITION': 'type', 'DELETED': 'deleted',
                'ADDED': 'added', 'COMMENT': 'comment'}.get(n, 'text')
    if lexer == 'errorlist':
        ansi = {'BLACK': 'text', 'RED': 'ansi-red', 'GREEN': 'ansi-green', 'BROWN': 'ansi-yellow',
                'YELLOW': 'ansi-yellow', 'BLUE': 'ansi-blue', 'MAGENTA': 'ansi-magenta', 'CYAN': 'ansi-cyan',
                'GRAY': 'comment', 'WHITE': 'text'}
        m = re.match(r'ANSI COLOR (?:BRIGHT |DARK )?(\w+)', n)
        if m:
            return 'comment' if n == 'ANSI COLOR DARK GRAY' else ansi.get(m.group(1), 'text')
        return {'DIFF CHANGED': 'string', 'DIFF ADDITION': 'ansi-green', 'DIFF DELETION': 'error-fg',
                'DIFF MESSAGE': 'keyword', 'ESCAPE SEQUENCE': 'comment', 'UNKNOWN ESCAPE SEQUENCE': 'special',
                'DEFAULT STYLE': 'text'}.get(n, 'error-fg' if 'ERROR' in n else None)
    if lexer == 'searchResult':
        return {'SEARCH HEADER': 'search-header', 'FILE HEADER': 'file-header', 'LINE NUMBER': 'linenum',
                'HIT WORD': 'hit', 'CURRENT LINE BACKGROUND COLOUR': 'current-line'}.get(n)
    rules = [
        (r'COMMENT DOC KEYWORD ERROR', 'comment'),
        (r'COMMENT DOC KEYWORD|HELPER IN COMMENT|MACRO IN COMMENT', 'comment-bold'),
        (r'COMMENT|^POD\b|DOCSTRING', 'comment'),
        (r'ERROR|ILLEGAL|WRONG|GARBAGE|NOT CLOSED|UNCLOSED|STRING ?EOL|INFIXEOL', 'error'),
        (r'^(DEFAULT|DEFAULT STYLE|WHITE ?SPACE|IDENTIFIERS?|IDEOL|TEXT|TAGNAME)$', 'text'),
        (r'OPERATOR|DELIMITER|PUNCTUATION|^SYMBOL$|^ASSIGNMENT$', 'text'),
        (r'^VAR IN|STRING VAR|COMPLEX VARIABLE|ESCAPE|INTERPOL', 'special'),
        (r'STRING|CHARACTER|^CHAR|VERBATIM|TRIPLE|BACKTICK|HEREDOC|^HERE |CDATA|REGEX|TRANSLATION|LITERAL|'
         r'QUOTED|RAW|^F |URI$|IRI$|^VALUE$|^DEFVAL$', 'string'),
        (r'NUMBER|NUMERIC|HEX|OCTAL|FLOAT|INTEGER|DIGIT|^CONSTANT|ENTITY|BOOLEAN|^DATE|^LIFETIME$', 'number'),
        (r'PREPROC|MACRO|PRAGMA|LABEL|VARIABLE|SCALAR|^ARRAY$|^HASH$|SYMBOL TABLE|SPECIAL|DECORATOR|ANNOTATION|'
         r'REGISTER|^GLOBAL$|PREDEFINED|SUBSTITUTION|^PARAM|^VAR\b|REFERENCE|XML START|XML END|^SGML|QUESTION MARK|'
         r'ADVERB|^INFIX$|POSITIONAL|ASSOCIATIVE|^TARGET$|DIRECTIVE|IMPORTANT|^MEDIA$|PSEUDO|^RECORD|^ATOM|GUID', 'special'),
        (r'FUNCTION|FUNC|DEF NAME|CLASS NAME|METHOD|PROCEDURE|SUBROUTINE|BUILTIN|BUILT-IN|BUILIN|CMDLET|ALIAS|'
         r'CALLABLE|PROTOTYPE|DEFINITION|NODE NAME|CORE API|PLUGIN', 'function'),
        (r'^USER ATTRIBUTES', 'type'),
        (r'^USER KEYWORDS|^USER TAGS|^USER\d', 'keyword'),
        (r'KEYWORDS? ?[2]$|WORD ?2$', 'type'),
        (r'KEYWORDS? ?[3-9]$|WORD ?[3-9]$', 'function'),
        (r'TYPE|\bCLASS|\bSTRUCT|INTERFACE|ATTRIBUTE|PROPERT|^KEY$|VALUE NAME|FIELD|MEMBER|NAMESPACE|MODULE|PACKAGE|'
         r'^ID$|BASE WORD|PREDECLARED|GRAMMAR|DESCRIPTOR|\bENUM|DOMAIN', 'type'),
        (r'KEYWORD|INSTRUCTION|^WORD$|STATEMENT|COMMAND|RESERVED|TAG|OPCODE|SECTION|HEADER|SELECTOR|CONTROL|'
         r'TABLE|DOCUMENT|GROUP', 'keyword'),
    ]
    for pattern, role in rules:
        if re.search(pattern, n):
            return role
    return None

def role_by_colour(hexcol):
    """The model's own colour coding (black text, blue keywords, green comments, ...) for unnamed roles."""
    L, C, h = oklch(hexcol)
    if C < 0.04:
        return 'text'
    if 230 <= h < 285: return 'keyword'
    if 285 <= h < 310: return 'type'
    if 310 <= h < 350: return 'string'
    if h >= 350 or h < 50: return 'number'
    if 50 <= h < 130: return 'special'
    if 130 <= h < 165: return 'comment'
    return 'number'

ANSI_FG = {'RED': 'ansi_red', 'GREEN': 'ansi_green', 'YELLOW': 'ansi_yellow', 'BLUE': 'ansi_blue',
           'MAGENTA': 'ansi_magenta', 'CYAN': 'ansi_cyan'}
ANSI_BG = {'RED': 'find', 'GREEN': 'smart', 'YELLOW': 'tagattr', 'BLUE': 'incremental', 'MAGENTA': 'tagmatch',
           'CYAN': 'mark1'}

def escseq_style(name, p, mode):
    """'BOLD RED on BLUE': the colour names mapped to the palette, backgrounds as tints so every pair stays legible."""
    m = re.match(r'(BOLD )?(\w+) ON (\w+)', name.upper())
    if not m:
        return p['comment'], p['bg'], False
    bold, fg, bg = bool(m.group(1)), m.group(2), m.group(3)
    dim, bright = (p['linenum'], p['text']) if mode == 'dark' else (p['text'], p['linenum'])
    fgc = {'DEFAULT': p['text'], 'BLACK': dim, 'WHITE': bright}.get(fg) or p[ANSI_FG[fg]]
    if bg == 'DEFAULT':
        bgc = p['bg']
    elif bg in ('BLACK', 'WHITE'):
        dark_end = (bg == 'BLACK') == (mode == 'dark')
        bgc = p['margin_bg'] if dark_end else blend(p['text'], p['bg'], 0.22)
    else:
        bgc = blend(p[ANSI_BG[bg]], p['bg'], ALPHA)
    if wcag_worst(fgc, bgc) < 4.5:  # e.g. WHITE on BLACK in the light theme: keep it readable
        fgc = p['text']
    return fgc, bgc, bold

def attrs(line):
    return dict(re.findall(r'(\w+)="([^"]*)"', line))

def set_attr(line, key, value):
    return re.sub(rf'\b{key}="[^"]*"', f'{key}="{value}"', line, count=1)

def style_for(role, p, model_bold):
    """(fg, bg, bold) for a lexer style."""
    bg = p['bg']
    table = {
        'text': (p['text'], bg, False),
        'comment': (p['comment'], bg, False),
        'comment-bold': (p['comment'], bg, True),
        'error': (p['error'], p['error_bg'], False),
        'error-fg': (p['error'], bg, False),
        'deleted': (p['error'], p['error_bg'], False),
        'added': (p['ansi_green'], p['added_bg'], False),
        'string': (p['string'], bg, False),
        'number': (p['number'], bg, False),
        'keyword': (p['keyword'], bg, model_bold),
        'type': (p['type'], bg, model_bold),
        'function': (p['function'], bg, model_bold),
        'special': (p['special'], bg, model_bold),
        'search-header': (p['text'], p['sel_bg'], True),
        'file-header': (p['ansi_green'], p['added_bg'], True),
        'linenum': (p['comment'], bg, False),
        'hit': (p['text'], blend(p['tagattr'], bg, ALPHA), True),
        'current-line': (None, p['line_bg'], False),
    }
    if role.startswith('ansi-'):
        return p['ansi_' + role[5:]], bg, False
    return table[role]

def global_style(name, p, mode, dark_default):
    """(fg, bg, fontStyle) for a GlobalStyles entry; None keeps the attribute's value."""
    bg = p['bg']
    copy = dark_default.get(name) if mode == 'dark' else None
    m = {
        'Default Style': (p['text'], bg, '0'),
        'Global override': (p['text'], bg, '0'),
        'Indent guideline style': (p['guide'], bg, '0'),
        'Brace highlight style': (p['brace'], bg, '1'),
        'Bad brace colour': (p['error'], p['error_bg'], '1'),
        'Current line background colour': (None, p['line_bg'], None),
        'Selected text colour': (p['text'], p['sel_bg'], None),
        'Multi-selected text color': (None, p['multisel_bg'], None),
        'Caret colour': (p['caret'], None, None),
        'Multi-edit carets color': (p['keyword'], None, None),
        'Edge colour': (p['guide'], None, None),
        'Line number margin': (p['linenum'], p['margin_bg'], '0'),
        'Bookmark margin': (None, p['margin_bg'], None),
        'Change History margin': (None, p['margin_bg'], None),
        'Change History modified': (p['mark2'], p['mark2'], None),
        'Change History revert modified': (p['mark5'], p['mark5'], None),
        'Change History revert origin': (p['mark1'], p['mark1'], None),
        'Change History saved': (p['smart'], p['smart'], None),
        'Fold': (p['linenum'], p['margin_bg'], None),
        'Fold active': (p['caret'], None, None),
        'Fold margin': (p['margin_bg'], p['margin_bg'], None),
        'White space symbol': (p['whitespace'], None, None),
        'Smart Highlighting': (None, p['smart'], None),
        'Find Mark Style': (None, p['find'], None),
        'Find status: Not found': (p['error'], None, None),
        'Find status: Message': (p['keyword'], None, None),
        'Find status: Search end reached': (p['ansi_green'], None, None),
        'Mark Style 1': (None, p['mark1'], None),
        'Mark Style 2': (None, p['mark2'], None),
        'Mark Style 3': (None, p['mark3'], None),
        'Mark Style 4': (None, p['mark4'], None),
        'Mark Style 5': (None, p['mark5'], None),
        'Incremental highlight all': (None, p['incremental'], None),
        'Tags match highlighting': (None, p['tagmatch'], None),
        'Tags attribute': (None, p['tagattr'], None),
        'Active tab focused indicator': (p['keyword'], None, None),
        'Active tab unfocused indicator': (p['linenum'], None, None),
        'URL hovered': (p['keyword'], None, None),
        'EOL custom color': (p['whitespace'], None, None),
        'Non-printing characters custom color': (p['mark2'], None, None),
    }
    if name in m:
        return m[name]
    if copy:  # tab colours and the document map: as DarkModeDefault has them in dark mode, the model's otherwise
        return copy.get('fgColor'), copy.get('bgColor'), None
    return None, None, None

TITLE = {'dark': 'Lucid Dark', 'light': 'Lucid Light'}

def header(mode, p):
    other = 'Lucid Light' if mode == 'dark' else 'Lucid Dark'
    syntax = ('keyword', 'function', 'type', 'string', 'number', 'special', 'error')
    ratios = [wcag_worst(p[r], p['bg']) for r in syntax]
    return f'''<!--
{TITLE[mode]} (version 2): a Notepad++ theme for legible code; "{other}" is its other half.
Background #{p["bg"]}, text #{p["text"]} ({wcag_worst(p["text"], p["bg"]):.1f}:1), comments #{p["comment"]} ({wcag_worst(p["comment"], p["bg"]):.1f}:1).
The syntax colours share one lightness and stay inside the screen's colour range, and each role keeps its hue
in both themes: keywords violet, functions blue, types teal, strings green, numbers orange, macros and
variables magenta, errors red. Their contrast is {min(ratios):.1f}:1 to {max(ratios):.1f}:1 (WCAG 2), also for a 70-year-old
reader; checked for colour blindness.
Generated from stylers.model.xml: regenerate rather than edit by hand, to keep the measured contrast.
License: GPL2
-->
'''

def generate(model_path, dark_default_path, mode):
    p = build(mode)
    dark_default = {}
    for line in open(dark_default_path, encoding='utf-8'):
        if '<WidgetStyle' in line:
            a = attrs(line)
            dark_default[a['name']] = a
    out, lexer, log = [], None, []
    for line in open(model_path, encoding='utf-8'):
        if '<LexerType' in line:
            lexer = attrs(line)['name']
        if '<NotepadPlus' in line:
            out.append(header(mode, p))
        if '<WordsStyle' in line:
            a = attrs(line)
            role = role_by_name(lexer, a['name'])
            how = 'name'
            if role is None:
                role = role_by_colour(a.get('fgColor', '000000'))
                how = 'colour'
            log.append((lexer, a['name'], a.get('fgColor'), role, how))
            bold = a.get('fontStyle', '0') not in ('', '0') and int(a['fontStyle']) & 1
            if role == 'escseq':
                fg, bgc, b = escseq_style(a['name'], p, mode)
            else:
                fg, bgc, b = style_for(role, p, bool(bold))
            if fg and 'fgColor' in a: line = set_attr(line, 'fgColor', fg)
            if 'bgColor' in a: line = set_attr(line, 'bgColor', bgc)
            if 'fontStyle' in a: line = set_attr(line, 'fontStyle', '1' if b else '0')
        elif '<WidgetStyle' in line:
            a = attrs(line)
            fg, bgc, fs = global_style(a['name'], p, mode, dark_default)
            if fg and 'fgColor' in a: line = set_attr(line, 'fgColor', fg)
            if bgc and 'bgColor' in a: line = set_attr(line, 'bgColor', bgc)
            if fs is not None and 'fontStyle' in a: line = set_attr(line, 'fontStyle', fs)
            if a['name'] in ('Default Style', 'Global override') and 'fontName' in a:
                line = set_attr(line, 'fontName', 'Consolas')
        out.append(line)
    return ''.join(out), log

if __name__ == '__main__':
    model, dark_default, outdir = sys.argv[1:4]
    os.makedirs(outdir, exist_ok=True)
    for mode in ('light', 'dark'):
        xml, log = generate(model, dark_default, mode)
        with open(f'{outdir}/{TITLE[mode]}.xml', 'w', encoding='utf-8', newline='') as f:
            f.write(xml)
    with open(f'{outdir}/roles.tsv', 'w') as f:
        f.write('lexer\tstyle\tmodel colour\trole\tdecided by\n')
        for row in log:
            f.write('\t'.join(str(x) for x in row) + '\n')
