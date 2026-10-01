#!/usr/bin/python3
# TEST ONLY, applied to the throwaway COPY rv3/tv1src (never to the worktree): Wine 9 has no valid V2 context,
# fall back to per-monitor V1 so that the per-monitor code paths run (same as the earlier testv1 variant).
p = '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3/tv1src/PowerEditor/src/dpiManagerV2.cpp'
s = open(p, 'rb').read().decode('utf-8')
old = '\t\t_isPerMonitorV2Active = true;\n\t}\n\treturn _isPerMonitorV2Active;\n'
new = ('\t\t_isPerMonitorV2Active = true;\n\t}\n'
       '\telse if (::SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE) != nullptr) // TEST ONLY\n'
       '\t{\n\t\t_isPerMonitorV2Active = true;\n\t}\n\treturn _isPerMonitorV2Active;\n')
assert s.count(old) == 1
s = s.replace(old, new)
open(p, 'wb').write(s.encode('utf-8'))
print('patched')
