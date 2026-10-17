#!/usr/bin/env python3
"""Assemble license notices shipped with the iOS app from vendored sources."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
vendor = root / 'Vendor/KataGo'
output = root / 'Sources/Kifu/Resources/ThirdPartyNotices.txt'

sections = [
    ('KataGo engine', vendor / 'LICENSE'),
    ('Bundled KataGo network', root / 'Resources/KataGo/NOTICE.md'),
    ('ghc filesystem', vendor / 'cpp/external/filesystem-1.5.8/LICENSE'),
    ('TCLAP', vendor / 'cpp/external/tclap-1.2.5/COPYING'),
    ('katagocoreml interface', vendor / 'cpp/external/katagocoreml/LICENSE'),
    ('katagocoreml third-party notices', vendor / 'cpp/external/katagocoreml/NOTICE'),
]

parts = ['KIFU — THIRD-PARTY NOTICES\n\nThe following notices accompany third-party code and model data in the iOS app.\n']
for title, path in sections:
    parts.append(f'\n{"=" * 72}\n{title}\nSource: {path.relative_to(root)}\n{"=" * 72}\n\n')
    parts.append(path.read_text(encoding='utf-8').rstrip() + '\n')

sha = (vendor / 'cpp/core/sha2.cpp').read_text(encoding='utf-8')
sha_notice = sha.split('/*', 1)[1].split('*/', 1)[0]
parts.append('\n' + '=' * 72 + '\nSHA-2 implementation\nSource: Vendor/KataGo/cpp/core/sha2.cpp\n' + '=' * 72 + '\n\n' + sha_notice.strip() + '\n')

json = (vendor / 'cpp/external/nlohmann_json/json.hpp').read_text(encoding='utf-8')
json_notice = json.split('/*', 1)[1].split('*/', 1)[0]
parts.append('\n' + '=' * 72 + '\nnlohmann/json\nSource: Vendor/KataGo/cpp/external/nlohmann_json/json.hpp\n' + '=' * 72 + '\n\n' + json_notice.strip() + '\n')
parts.append('\nThis JSON implementation incorporates the Grisu2 algorithm, Copyright (c) 2009 Florian Loitsch, distributed under the MIT license, and a UTF-8 decoder, Copyright (c) 2008-2009 Bjoern Hoehrmann. See the vendored json.hpp for the original attributions.\n')

output.write_text(''.join(parts), encoding='utf-8')
print(output)
