import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

import pandas as pd
import numpy as np
from app.modules.factcheck.checker import factchecker

CSV_PATH = '/Users/artemijsmykov/Desktop/fakescope-dataset/dataset_final.csv'

factchecker.load()
print(f'Текущих записей в базе: {len(factchecker.facts)}')

df = pd.read_csv(CSV_PATH).dropna(subset=['text'])
df = df[df['source'] == 'Лапша']
print(f'Записей Лапша Медиа: {len(df)}')

existing_texts = set(f['text'] for f in factchecker.facts)

new_texts = []
new_facts = []

for _, row in df.iterrows():
    text = str(row['text']).strip()
    if text in existing_texts:
        continue
    new_texts.append(text)
    new_facts.append({
        'text': text[:500],
        'verdict': 'fake',
        'source_url': 'https://lapsha.media',
        'title': text[:100],
    })
    existing_texts.add(text)

print(f'Новых записей для добавления: {len(new_texts)}')

if new_texts:
    print('Кодируем векторы...')
    batch_size = 256
    all_vectors = []
    for i in range(0, len(new_texts), batch_size):
        batch = new_texts[i:i+batch_size]
        vecs = factchecker.model.encode(batch, normalize_embeddings=True, show_progress_bar=False)
        all_vectors.append(vecs)
        print(f'  {min(i+batch_size, len(new_texts))}/{len(new_texts)}')

    new_vectors = np.vstack(all_vectors)

    if len(factchecker.vectors) > 0:
        factchecker.vectors = np.vstack([factchecker.vectors, new_vectors])
    else:
        factchecker.vectors = new_vectors

    factchecker.facts.extend(new_facts)
    factchecker._save()
    print(f'Готово. Всего в базе: {len(factchecker.facts)}')
else:
    print('Новых записей нет.')
