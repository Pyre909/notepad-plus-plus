# Size of the largest .diff/.patch attached to each ticket (from fetch.sh's downloads), and how often Neil's posts
# say it was committed/implemented/applied/added (a rough proxy for acceptance).
import json, glob, re, statistics
pat = re.compile(r'\.(patch|diff)$', re.I)
recs = []
for tracker in ('bugs', 'feature-requests'):
	for f in glob.glob(f'{tracker}/*.json'):
		try:
			t = json.load(open(f))['ticket']
		except Exception:
			continue	# deleted ticket
		atts = list(t['attachments']) + [a for p in t['discussion_thread']['posts'] for a in p.get('attachments', [])]
		sizes = [a['bytes'] for a in atts if pat.search(a['url'])]
		if sizes:
			committed = any(p['author'] == 'nyamatongwe' and re.search(r'\b(committed|implemented|applied|merged|included|added)\b', p['text'], re.I)
				for p in t['discussion_thread']['posts'])
			recs.append((tracker, t['ticket_num'], t['reported_by'], max(sizes), committed))
sizes = sorted(r[3] for r in recs)
print(f'{len(recs)} tickets with a patch; largest per ticket: median {statistics.median(sizes):.0f} B, 90% {sizes[int(.9 * len(sizes))]} B')
for r in sorted(recs, key=lambda r: -r[3])[:15]:
	print(r)
