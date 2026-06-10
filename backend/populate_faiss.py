import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

import pandas as pd
import psycopg2
from app.core.config import settings

CSV_PATH = '/Users/artemijsmykov/Desktop/fakescope-dataset/dataset_final.csv'

def get_db():
    url = settings.database_url.replace("postgresql+asyncpg://", "")
    user_pass, rest = url.split("@")
    user, password = user_pass.split(":")
    host_port, dbname = rest.split("/")
    host, port = host_port.split(":") if ":" in host_port else (host_port, "5432")
    return psycopg2.connect(host=host, port=int(port), user=user, password=password, dbname=dbname)

conn = get_db()
cur = conn.cursor()

cur.execute("SELECT COUNT(*) FROM factcheck_entries")
existing = cur.fetchone()[0]
print(f"Текущих записей в БД: {existing}")

df = pd.read_csv(CSV_PATH).dropna(subset=['text'])
df = df[df['source'] == 'Лапша']
print(f"Записей Лапша Медиа: {len(df)}")

added = 0
for _, row in df.iterrows():
    text = str(row['text']).strip()
    cur.execute(
        """INSERT INTO factcheck_entries (id, text, title, verdict, source_url, created_at)
           VALUES (gen_random_uuid(), %s, %s, %s, %s, NOW())
           ON CONFLICT (text) DO NOTHING""",
        (text[:500], text[:100], 'fake', 'https://lapsha.media')
    )
    if cur.rowcount > 0:
        added += 1

conn.commit()
cur.execute("SELECT COUNT(*) FROM factcheck_entries")
total = cur.fetchone()[0]
cur.close()
conn.close()

print(f"Добавлено: {added}")
print(f"Всего в БД: {total}")
