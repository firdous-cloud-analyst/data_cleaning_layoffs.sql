-- ============================================================
-- PROJECT  : Tech Layoffs Data Cleaning & Exploratory Analysis
-- Dataset  : World Tech Layoffs 2020–2023 (Kaggle)
-- Tool     : MySQL
-- Author   : Firdous A.
-- Steps    : 1) Remove Duplicates
--            2) Standardize Data
--            3) Handle NULL / Blank Values
--            4) Fix Date Format
--            5) Exploratory Data Analysis (EDA)
-- ============================================================


-- ============================================================
-- STEP 0: Preview raw data
-- ============================================================

SELECT *
FROM layoffs;


-- ============================================================
-- STEP 1: Remove Duplicates
-- ============================================================
-- Strategy: copy raw data into a staging table, use ROW_NUMBER()
-- to flag duplicates, then delete flagged rows from a second
-- staging table (MySQL does not support DELETE with CTE directly)

-- 1a. Create first staging table with same structure as source
CREATE TABLE layoffs1
LIKE layoffs;

-- 1b. Copy all raw data into staging table
INSERT INTO layoffs1
SELECT * FROM layoffs;

-- 1c. Identify duplicates using ROW_NUMBER window function
-- Any row with row_num > 1 is a duplicate
WITH duplicate_cte AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY
        location,
        industry,
        total_laid_off,
        percentage_laid_off,
        date,
        stage,
        country,
        funds_raised_millions
    ) AS row_num
  FROM layoffs1
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- 1d. Create second staging table with row_num column included
CREATE TABLE layoffs2 (
  company               TEXT,
  location              TEXT,
  industry              TEXT,
  total_laid_off        INT DEFAULT NULL,
  percentage_laid_off   TEXT,
  date                  TEXT,
  stage                 TEXT,
  country               TEXT,
  funds_raised_millions INT DEFAULT NULL,
  row_num               INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 1e. Insert data with row_num assigned
INSERT INTO layoffs2
SELECT *,
  ROW_NUMBER() OVER (
    PARTITION BY
      location,
      industry,
      total_laid_off,
      percentage_laid_off,
      date,
      stage,
      country,
      funds_raised_millions
  ) AS row_num
FROM layoffs1;

-- 1f. Verify duplicates exist
SELECT *
FROM layoffs2
WHERE row_num > 1;

-- 1g. Delete duplicate rows
DELETE
FROM layoffs2
WHERE row_num > 1;

-- 1h. Confirm duplicates removed
SELECT *
FROM layoffs2;


-- ============================================================
-- STEP 2: Standardize Data
-- ============================================================

-- 2a. Trim whitespace from company names
SELECT company, TRIM(company)
FROM layoffs2;

UPDATE layoffs2
SET company = TRIM(company);

-- 2b. Unify inconsistent industry labels
-- Found: 'Crypto', 'Crypto Currency', 'CryptoCurrency' → normalize to 'crypto'
SELECT DISTINCT industry
FROM layoffs2
ORDER BY 1;

UPDATE layoffs2
SET industry = 'crypto'
WHERE industry LIKE 'crypto%';

-- 2c. Remove trailing period from country names (e.g. 'United States.')
SELECT country, TRIM(TRAILING '.' FROM country)
FROM layoffs2
ORDER BY 1;

UPDATE layoffs2
SET country = TRIM(TRAILING '.' FROM country);

-- 2d. Verify fix for 'United States'
SELECT DISTINCT country
FROM layoffs2
WHERE country LIKE 'United States%';


-- ============================================================
-- STEP 3: Fix Date Format
-- ============================================================
-- date column is stored as TEXT in MM/DD/YYYY format
-- Convert to proper SQL DATE type for time-series analysis

-- 3a. Preview the conversion
SELECT
  `date`,
  STR_TO_DATE(`date`, '%m/%d/%Y') AS date_converted
FROM layoffs2;

-- 3b. Apply conversion
UPDATE layoffs2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- 3c. Change column data type from TEXT to DATE
ALTER TABLE layoffs2
MODIFY COLUMN `date` DATE;

-- 3d. Verify
SELECT `date`
FROM layoffs2
LIMIT 10;


-- ============================================================
-- STEP 4: Handle NULL and Blank Values
-- ============================================================

-- 4a. Find rows with blank or NULL industry
SELECT *
FROM layoffs2
WHERE industry IS NULL
   OR industry = '';

-- Example: Airbnb rows have missing industry
SELECT *
FROM layoffs2
WHERE company = 'Airbnb';

-- 4b. Convert blank strings to NULL for consistency
UPDATE layoffs2
SET industry = NULL
WHERE industry = '';

-- 4c. Impute NULL industry using a self-join
-- If the same company has another row with an industry filled in, use that value
SELECT
  t1.company,
  t1.industry AS null_industry,
  t2.industry AS filled_industry
FROM layoffs2 AS t1
JOIN layoffs2 AS t2
  ON  t1.company  = t2.company
  AND t1.location = t2.location
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

UPDATE layoffs2 AS t1
JOIN layoffs2 AS t2
  ON  t1.company  = t2.company
  AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- 4d. Delete rows where both key metrics are NULL (no analytical value)
SELECT *
FROM layoffs2
WHERE total_laid_off      IS NULL
  AND percentage_laid_off IS NULL;

DELETE
FROM layoffs2
WHERE total_laid_off      IS NULL
  AND percentage_laid_off IS NULL;

-- 4e. Drop the helper row_num column (no longer needed)
ALTER TABLE layoffs2
DROP COLUMN row_num;

-- 4f. Final clean table check
SELECT *
FROM layoffs2;


-- ============================================================
-- STEP 5: Exploratory Data Analysis (EDA)
-- ============================================================

-- 5a. Overall scale of layoffs
SELECT
  MAX(total_laid_off)        AS max_single_layoff,
  MAX(percentage_laid_off)   AS max_pct_laid_off,
  MAX(funds_raised_millions) AS max_funding
FROM layoffs2;

-- 5b. Companies with the most total layoffs
SELECT
  company,
  SUM(total_laid_off) AS total_layoffs
FROM layoffs2
GROUP BY company
ORDER BY total_layoffs DESC
LIMIT 10;

-- 5c. Industries hit hardest
SELECT
  industry,
  SUM(total_laid_off) AS total_layoffs
FROM layoffs2
GROUP BY industry
ORDER BY total_layoffs DESC;

-- 5d. Countries with the most layoffs
SELECT
  country,
  SUM(total_laid_off) AS total_layoffs
FROM layoffs2
GROUP BY country
ORDER BY total_layoffs DESC;

-- 5e. Company funding stage vs layoffs
SELECT
  stage,
  SUM(total_laid_off) AS total_layoffs
FROM layoffs2
GROUP BY stage
ORDER BY total_layoffs DESC;

-- 5f. Annual layoff totals
SELECT
  YEAR(`date`)        AS year,
  SUM(total_laid_off) AS total_layoffs
FROM layoffs2
GROUP BY YEAR(`date`)
ORDER BY year DESC;

-- 5g. Monthly layoff totals (for trend analysis)
SELECT
  SUBSTRING(`date`, 1, 7) AS month,
  SUM(total_laid_off)     AS monthly_layoffs
FROM layoffs2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY month
ORDER BY month ASC;

-- 5h. Rolling cumulative total (running sum of monthly layoffs)
WITH monthly_totals AS (
  SELECT
    SUBSTRING(`date`, 1, 7) AS month,
    SUM(total_laid_off)     AS monthly_layoffs
  FROM layoffs2
  WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
  GROUP BY month
  ORDER BY month ASC
)
SELECT
  month,
  monthly_layoffs,
  SUM(monthly_layoffs) OVER (ORDER BY month) AS rolling_total
FROM monthly_totals;

-- 5i. Top 5 companies by layoffs per year (using DENSE_RANK)
WITH company_year AS (
  SELECT
    company,
    YEAR(`date`)        AS year,
    SUM(total_laid_off) AS total_layoffs
  FROM layoffs2
  GROUP BY company, YEAR(`date`)
),
company_year_ranked AS (
  SELECT *,
    DENSE_RANK() OVER (
      PARTITION BY year
      ORDER BY total_layoffs DESC
    ) AS ranking
  FROM company_year
  WHERE company IS NOT NULL
    AND year    IS NOT NULL
)
SELECT *
FROM company_year_ranked
WHERE ranking <= 5
ORDER BY year, ranking;

