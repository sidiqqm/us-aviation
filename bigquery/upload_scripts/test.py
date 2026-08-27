import pandas as pd
import os
import glob

RAW_PATH = "data/raw/on_time/"

print(f"{'Filename':<30} {'Shape':<20} {'Actual Months'}")
print("-" * 80)

for year in range(2019, 2024):
    for month in range(1, 13):
        filepath = os.path.join(RAW_PATH, f"ontime_{year}_{month:02d}.csv")
        
        if not os.path.exists(filepath):
            print(f"ontime_{year}_{month:02d}.csv{'':10} FILE NOT FOUND")
            continue
        
        df = pd.read_csv(filepath, usecols=['FL_DATE'], low_memory=False)
        
        # Parse bulan aktual dari isi file
        df['FL_DATE'] = pd.to_datetime(df['FL_DATE'], format='mixed', dayfirst=False)
        actual_months = df['FL_DATE'].dt.to_period('M').unique()
        actual_months_str = ", ".join(str(m) for m in sorted(actual_months))
        
        expected = f"{year}-{month:02d}"
        match = "" if actual_months_str == expected else "WRONG"
        
        print(f"ontime_{year}_{month:02d}.csv{'':<10} {str(df.shape):<20} {actual_months_str} {match}")