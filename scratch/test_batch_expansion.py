import re

def expand_batch_sections_old(clean):
    if clean.contains('&') or clean.contains(',') or clean.contains('/'):
        # Check compound batches: "FA25-BME/FA24-BME/FA22-BEE"
        if len(re.findall(r'(?:FA|SP)\d{2}', clean)) > 1:
            return [b.strip() for b in re.split(r'[/,]', clean) if b.strip()]

        parts = clean.split('-')
        if len(parts) >= 3:
            lastPart = parts[-1]
            sections = [s.strip() for s in re.split(r'[&,/]', lastPart) if s.strip()]
            if len(sections) > 1:
                prefix = '-'.join(parts[:-1])
                return [f"{prefix}-{sec}" for sec in sections]
    return [clean]

def expand_batch_sections_new(clean):
    clean = clean.strip().upper()
    if not clean:
        return []

    # 1. Comma / forward slash separated full or partial batches
    # e.g. "BCS-6A, BCS-6B" or "BCS-6A, 6B" or "BCS-6A / BCS-6B" or "FA21-BCS-6A, FA21-BCS-6B"
    chunks = [c.strip() for c in re.split(r'[,&]', clean) if c.strip()]
    if len(chunks) > 1:
        results = []
        for i, chunk in enumerate(chunks):
            if '-' in chunk:
                results.append(chunk)
            else:
                # Inherits prefix from previous chunk e.g. "BCS-6A" and "6B" or "B"
                if results and '-' in results[-1]:
                    prev = results[-1]
                    prev_parts = prev.split('-')
                    if re.match(r'^\d+[A-Z]?$', chunk):
                        # chunk is "6B"
                        prefix = '-'.join(prev_parts[:-1])
                        results.append(f"{prefix}-{chunk}")
                    elif re.match(r'^[A-Z]$', chunk):
                        # chunk is "B", prev last was "6A" -> replace section 'A' with 'B'
                        prev_last = prev_parts[-1]
                        m = re.match(r'^(\d+)?([A-Z]+)$', prev_last)
                        if m and m.group(1):
                            prefix = '-'.join(prev_parts[:-1])
                            results.append(f"{prefix}-{m.group(1)}{chunk}")
                        else:
                            prefix = '-'.join(prev_parts[:-1])
                            results.append(f"{prefix}-{chunk}")
                    else:
                        results.append(chunk)
                else:
                    results.append(chunk)
        return results

    # 2. Slash combined sections e.g. "BCS-6A/B" or "FA21-BCS-6A/B" or "BCS-6A/6B"
    if '/' in clean:
        parts = clean.split('/')
        base = parts[0].strip()
        results = [base]
        if '-' in base:
            base_parts = base.split('-')
            prefix = '-'.join(base_parts[:-1])
            base_last = base_parts[-1]
            for extra in parts[1:]:
                extra = extra.strip()
                if '-' in extra:
                    results.append(extra)
                elif re.match(r'^\d+[A-Z]?$', extra):
                    results.append(f"{prefix}-{extra}")
                elif re.match(r'^[A-Z]$', extra):
                    m = re.match(r'^(\d+)?([A-Z]+)$', base_last)
                    if m and m.group(1):
                        results.append(f"{prefix}-{m.group(1)}{extra}")
                    else:
                        results.append(f"{prefix}-{extra}")
        return results

    return [clean]

# Test cases
test_inputs = [
    "BCS-6A, BCS-6B",
    "BCS-6A, 6B",
    "BCS-6A, B",
    "BCS-6A/B",
    "BCS-6A/6B",
    "FA21-BCS-6A, FA21-BCS-6B",
    "FA21-BCS-6A/B",
    "BSE-4A & BSE-4B",
    "BSE-4A & 4B",
    "BBA-2A, 2B, 2C",
    "BCS-6A",
]

for t in test_inputs:
    print(f"INPUT: '{t}' -> EXPANDED: {expand_batch_sections_new(t)}")
