# How Scintilla decides: a survey of its trackers, compared with our tickets

Survey of 2026-10-01. Question: how do Scintilla's maintainer (Neil Hodgson, `nyamatongwe`) and main contributor
(Zufu Liu, `zufuliu`) like changes to be proposed and written, and how do our three tickets (#2519, #2520, #1592)
compare?

**Data**: the 400 most recent tickets of each tracker on sourceforge.net/p/scintilla, with every post, via
SourceForge's REST API: 399 bugs (2019-07 to 2026-09) and 393 feature requests (2017-07 to 2026-09), 1,781
substantive posts by Neil. Plus `doc/SciCoding.html` (the code style), `doc/ScintillaHistory.html` (release notes)
and a full reading of every ticket's discussion, in six themed parts: Zufu Liu's tickets, other feature requests (two
parts), other bugs, and rendering/font/Win32 tickets. The data and scripts are in `survey/` (see the end).

## The numbers

| Measure | Value |
|---|---|
| Tickets with a post from Neil | 98% (395/399 bugs, 386/393 feature requests) |
| First reply from Neil | median same day (bugs) / next day (features); 90% within 10 days |
| Length of Neil's posts | median 207 characters |
| Description length, all tickets | median 530 characters; **ours for #1592: 4,419** |
| Largest patch per ticket (264 tickets with a .diff/.patch) | median 2.5 KB, 90% under 12 KB; **ours: #1592 38.6 KB (larger than 258/264), #2519 24.6 KB** |
| Requests implemented, with a patch vs without | about 60-72% vs about 12% |
| Zufu Liu's 172 tickets | roughly a third committed as proposed, a third after rework or rewritten by Neil, a quarter partly or declined |
| Tickets mentioning AI or LLMs, 2017-2026 | **only ours** (3, all 2026-09-30): the policy line on #1592 was a reaction to them |

Large patches that were accepted were almost all self-contained lexers (#1210, #1242, #1328, #1380) or Zufu Liu's
refactorings. Large patches changing core or UI behaviour were essentially never merged (#1196, #1225, #1249, #1307,
#1323, #1337, #1398).

## What the maintainer values (in Neil's own words)

**1. A bias for stability. Every change needs a reason.**
- "a bias for stability: changes are only made when there is clear benefit" (#1536); "Every feature costs
  maintenance effort." (#1526); "Feature requests should include a rationale for why they are wanted." (#1312)
- "If there is no strong motivation then its not worth the added complexity." (#2463)

**2. Evidence, measured, reproducible, ideally in SciTE.**
- "Every change for performance should make an attempt at quantifying the benefit." (#1442); "There are no
  measurements." (#1255)
- "Can you reproduce the ... in SciTE?" (#2342, #2473); bug reports "should include an example file as a text
  attachment" (#2247); "Tests are essential to prove that the feature works" (#1489).
- Neil tries patches personally, in SciTE, and posts screenshots (#2344: "the results with the patch appear quite poor
  at 200% and 125% to me"). Can't test it, won't commit it (#1405).

**3. One thing per change, minimal.**
- "A changeset should be about one thing" (#1274); "A fix should address exactly the problem with no additional
  optimizations or cleanups." (#1408); "Scope creep is the major cause of enhancement failure." (#1525)
- Neil often commits a smaller version of their own: "Committed minimal fix" (#2238); "Here is a minimal patch." (#1408).
  Unmentioned changes get the patch refused (#1319).

**4. Scintilla gives building blocks; the application decides policy.**
- "Scintilla commonly implements small features that can be combined into larger user-level features by the
  application." (#1577); "Functionality for a particular application should be implemented in that application."
  (#1203); "can be implemented by application code as it is in NotePad++" (#1527).
- Font naming: "The application can adjust these parameters itself using `IDWriteGdiInterop`" (#2356).

**5. Few choices, defaults unchanged.**
- "its simpler to support a limited set of choices." (#1307); "offering two additional modes makes it look like
  its not strongly motivated." (#1337); "Line background drawing is already complex and adding another option will
  make it worse." (#1436)
- "A new feature should duplicate current visuals unless an API is called" (#1398); new behaviour defaults off
  (#1225, #1530).
- Where a platform already has a setting, use it: "can commonly be altered with the platform's settings UI." (#1560);
  points users to existing options (#2305).

**6. API shape.**
- Set/Get pairs, names spelled out, British spelling, analogy with existing names (#1453, #1283, #1370).
- No magic values: "APIs that assign special meanings to some 'magic' values are more difficult than separate
  APIs." (#1419, also #1272).
- No structs or pointers in arguments, for binary compatibility and scripting (#1591, #1350). Extend existing
  mechanisms (bit flags, element colours) rather than invent new ones (#1322, #1525). First versions can be
  "provisional" (#1316).
- Platform interfaces (Surface, ListBox) are frozen between major versions (#2185, #1562, #1283).

**7. Platform code.**
- Platform decisions stay in the platform layer (#2315, #1332); cross-platform concepts preferred over Win32-only
  ones (#1292, #1452, #2356: "This isn't cross platform and I can't see how to reasonably implement it on macOS or
  GTK.").
- **DirectWrite first**: "DirectWrite should be treated as the default and GDI as a legacy API ... Eventually GDI
  will be deprecated." (#2519); "Win10 should be the focus" (#1284).
- Newer Windows APIs loaded at run time (#2344); feature detection rather than version checks (#1277).
- Root cause over masking: "The crash could be avoided by testing for validity but that would mean incorrect
  drawing." (#2138); "It's better to find the base cause of this bug" (#2504).
- Measures performance before and after, even for 0.5% (#2420).

**8. Code style** (`doc/SciCoding.html` and reviews): C++17, AStyle settings given in SciCoding, tabs, braces on the
same line, no C casts, `const`, initialise everything, minimal variable scope, no exceptions out of Scintilla;
standard algorithms over loops (#1416), rule of zero (#1485), `{}` rather than `std::nullopt` (#2260), constructors
that allocate aren't `noexcept` (#2295), no undefined behaviour (#1503), clarity over cleverness (#1392), no warnings
with MSVC, g++, clang and cppcheck, but correct code isn't bent for a linter (#2366). Documentation required: "The
feature is not useful unless it is documented." (#1497).

**9. Process.**
- Novel features: "better discussed on the mailing list" (#1233); "There wasn't any enthusiasm for this feature on
  the mailing list so it won't be merged." (#1196).
- Patches as .diff attachments against the Scintilla repository (not from divergent forks: #1474); "Committed as [hash]",
  often "with changes"; release freezes delay things.
- Downstream demand counts: Geany, Wing, Inno Setup maintainers' requests went in quickly (#1476, #1511, #1518);
  "no interest shown by the Notepad++ developers" closed #1553. Neil doesn't use Notepad++ (#1313) and leaves
  features Neil doesn't use to contributors (#1460, #1480).
- Tone: fast, courteous, terse, firm; persuaded by measurements (#2360 reversed after measuring); "You can, of
  course, implement whatever you want in your own fork." (#1542).

**10. Rendering specifically.** #1592 was the first request ever for DirectWrite rendering parameters, and no earlier
ticket complains of faint text. Blur complaints that were fixed were bugs with a cause (GDI scaling: #2344, #2382,
#2503, #2505). The per-monitor rendering parameters Scintilla uses today came from Zufu Liu's #1432, framed as a bug
("stale after Windows settings change"), with three designs and measured costs, and reviewed on lifetimes and on
keeping platform code out of shared code.

## Our three tickets against this

| | What works there | What we did | |
|---|---|---|---|
| Size | median patch 2.5 KB, one thing | #1592: 38.6 KB, six parameters + GDI-compatible measuring + autocompletion list; #2519: 24.6 KB | far too big, bundled |
| Choices | a limited set, defaults unchanged | defaults unchanged, but six parameters with ranges ("100 setting combinations") | the stated objection |
| Framing | problem and evidence first | API first ("Add SCI_SETFONTRENDERINGPARAMETER"), motivated by a Notepad++ reviewer's suggestion | an appeal to another project, not to evidence |
| Evidence | measured on Windows, reproducible in SciTE, screenshots | Wine only, our own 229-check harness; no Windows screenshots, no SciTE reproduction | weak where Neil looks |
| Platform direction | DirectWrite first, GDI legacy | "GDI classic"/"GDI natural" modes with GDI-compatible layouts; #2519 explained in GDI terms (`EnumFontFamiliesEx`) | against Neil's direction |
| API shape | no magic values | `SC_FONTRENDERING_DEFAULT` (-1) meaning "not set" (we offered a Reset message as an alternative) | half right |
| Process | novel features on the mailing list first | three tickets with patches on one day, straight to the tracker, from a new account | no discussion, no track record |
| Length and voice | posts of a few lines | descriptions 8x the median, structured like generated text | signals both "overwhelming" and "LLM" |
| Crash #2520 | root cause, no masking | clamp (Zufu Liu's suggestion, the root cause) + a null guard in `HFont` (masking) | clamp fits; the guard is the kind of change Neil tends to reject |
| Docs, iface, warnings | required | included, headers regenerated, warning-free, HeaderCheck/CheckMentioned clean | good |
| Honesty | (no precedent) | AI help disclosed | right, and why the policy was stated |
| Withdrawal of #2519 | application's job (#2080, #2356) | withdrawn, done in Notepad++ (`FontFamilyNames.cpp`) | right |

## What follows

1. **#1592**: a short closing reply in Pyre909's own words (accept both points, ask nothing).
2. **#2520**: a real crash with a reproduction, the kind of report Neil values; Zufu Liu engaged. Leave the fix to them.
   If asked: on Windows the clamp alone should be enough (Wine's 950 limit is a Wine quirk); the VM can confirm
   with `hfontcrash.cpp`. The `HFont` guard stays in the fork only.
3. **#2519**: nothing to do; withdrawn, Neil's note on documentation stands.
4. **Any future rendering idea** (the "sharpness" setting): mailing list first, a few lines, a problem shown in
   **SciTE** (`technology=1`, `font.quality=3`) with Windows screenshots and edge measurements; one setting, few
   values, default unchanged, DirectWrite terms only (natural vs natural symmetric, no GDI modes), no magic values,
   a thought about GTK/Cocoa equivalents; ideally implemented by Neil. Better still if the Notepad++ maintainers
   ask for it: downstream demand is what moves Neil.
5. **Notepad++ side**: keep doing it there (`FontFamilyNames.cpp` is the model); slim #18418 to what needs no
   Scintilla change.

## Survey data (`survey/`)

- `tickets.json.gz`: the 792 tickets with descriptions, attachments and posts (author, date, text).
- `analyze.py` (statistics, AI mentions), `themes.py` (the reading files), `patchsizes.py` (patch sizes).
- Download again: `curl https://sourceforge.net/rest/p/scintilla/<bugs|feature-requests>/<number>`.
