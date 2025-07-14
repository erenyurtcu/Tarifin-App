import pandas as pd

# JSONL dosyasını oku
df = pd.read_json("data/all_data.jsonl", lines=True)

# Tüm örnek sayısı
total = len(df)

# 2000 karakterden uzun olanları filtrele
filtered_out = df[df["output"].str.len() >= 2000]
kept = df[df["output"].str.len() < 2000]

print("Toplam örnek:", total)
print("Kalan (output < 2000):", len(kept))
print("Filtrelenen (output ≥ 2000):", len(filtered_out))
