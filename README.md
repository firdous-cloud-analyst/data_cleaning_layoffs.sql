# Tech Layoffs Data Cleaning & Exploratory Analysis (SQL)

> **Tools:** MySQL · SQL Window Functions · CTEs  
> **Dataset:** World Tech Layoffs 2020–2023 (Kaggle)  
> **Skills demonstrated:** Data cleaning, deduplication, standardization, NULL handling, EDA, rolling aggregations, ranking

---

## Business Problem

Global tech companies went through waves of mass layoffs between 2020 and 2023. A raw dataset of these layoffs contains duplicates, inconsistent category labels, malformed dates, and missing values — making it impossible to analyze trends reliably.

This project transforms that messy raw data into a clean, analysis-ready table, then extracts key business insights about which companies, industries, and countries were most affected.

---

## Key Findings

- **Amazon, Google, and Meta** were the top 3 companies by total employees laid off
- **Consumer and Retail** industries had the highest combined layoffs across all years
- **United States** accounted for over 65% of all recorded layoffs globally
- Rolling monthly totals revealed a sharp acceleration in layoffs from **Q4 2022 onward**
- **Post-IPO companies** had significantly higher layoff volumes than early-stage startups

---

## Data Cleaning Steps

### 1. Remove Duplicates
Created a staging table (`layoffs1`) and used `ROW_NUMBER()` with `PARTITION BY` across all key columns to identify exact duplicate records. Moved to a second staging table (`layoffs2`) and deleted rows where `row_num > 1`.

```sql
WITH duplicate_cte AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY location, industry, total_laid_off,
                   percentage_laid_off, date, stage, country, funds_raised_millions
    ) AS row_num
  FROM layoffs1
)
SELECT * FROM duplicate_cte WHERE row_num > 1;
```

### 2. Standardize Data
- Trimmed leading/trailing whitespace from `company` names using `TRIM()`
- Unified inconsistent `industry` labels (e.g., `Crypto`, `Crypto Currency`, `CryptoCurrency` → `crypto`)
- Removed trailing periods from `country` field (e.g., `United States.` → `United States`)

### 3. Fix Date Format
Converted `date` column from text format `MM/DD/YYYY` to proper SQL `DATE` type using `STR_TO_DATE()` and `ALTER TABLE ... MODIFY COLUMN`.

### 4. Handle NULL and Blank Values
- Converted empty strings to `NULL` for consistency
- Used a **self-join** to impute missing `industry` values from other records of the same company
- Deleted rows where both `total_laid_off` and `percentage_laid_off` were NULL (unusable records)
- Dropped the helper `row_num` column after deduplication

---

## Exploratory Data Analysis

After cleaning, performed EDA to answer business questions:

| Question | SQL Technique |
|---|---|
| Which companies laid off the most employees? | `GROUP BY company ORDER BY SUM DESC` |
| Which industries were hardest hit? | `GROUP BY industry` |
| Which countries had the most layoffs? | `GROUP BY country` |
| What was the monthly layoff trend? | `SUBSTRING(date,1,7)` + `GROUP BY month` |
| What is the cumulative running total over time? | `SUM() OVER (ORDER BY month)` — Rolling window |
| Which companies ranked top 5 per year? | `DENSE_RANK() OVER (PARTITION BY year)` in nested CTE |

---

## SQL Techniques Used

| Technique | Where Used |
|---|---|
| `ROW_NUMBER()` window function | Duplicate detection |
| CTE (`WITH` clause) | Duplicate staging, rolling totals, year ranking |
| Self-JOIN | NULL industry imputation |
| `STR_TO_DATE()` | Date format conversion |
| `TRIM()` / `LIKE` | String standardization |
| `DENSE_RANK()` | Top-5 companies per year ranking |
| Rolling `SUM() OVER()` | Cumulative monthly layoff trend |
| `ALTER TABLE` / `MODIFY COLUMN` | Schema changes post-cleaning |

---

## Project Structure

```
layoffs-data-cleaning/
├── README.md
├── data/
│   └── layoffs_raw.csv          # Original dataset (from Kaggle)
├── sql/
│   ├── 01_data_cleaning.sql     # All cleaning steps with comments
│   └── 02_exploratory_analysis.sql  # EDA queries
```

---

## Dataset Source

[World Layoffs Dataset — Kaggle](https://www.kaggle.com/datasets/swaptr/layoffs-2022)  
Contains records of tech company layoffs from March 2020 to 2023, including company, location, industry, total laid off, percentage laid off, date, funding stage, and funds raised.

---

## How to Run

1. Import `layoffs_raw.csv` into MySQL as table `layoffs`
2. Run `01_data_cleaning.sql` — creates `layoffs2` as the clean table
3. Run `02_exploratory_analysis.sql` — all EDA queries against `layoffs2`

---

## Connect

**LinkedIn:** [linkedin.com/in/firdous-abbasi-0080b1337](https://linkedin.com/in/firdous-abbasi-0080b1337)  
**GitHub:** [github.com/firdous-cloud-analyst](https://github.com/firdous-cloud-analyst)

