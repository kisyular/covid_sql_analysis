/*
DATA SOURCE
https://ourworldindata.org/covid-deaths
*/


-- QUESTION: What is the datatype of each column in the 'CovidDeaths' table?
-- Get datatype of each column
SELECT data_type, column_name
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'CovidDeaths';

-- QUESTION: Convert the 'date' column in 'CovidDeaths' and 'CovidVaccinations' tables to datetime?
-- Convert the column 'date' to datetime
ALTER TABLE CovidDeaths
    ALTER COLUMN date datetime;
ALTER TABLE CovidVaccinations
    ALTER COLUMN date datetime;

-- QUESTION: Why is it important to ensure the 'date' column is in datetime format?
/*
Using datetime format for the 'date' column enhances data integrity, simplifies date-related operations, and ensures
compatibility with standard practices and tools for working with temporal data
*/

-- QUESTION: Calculate the death percentage from the 'CovidDeaths' table?
-- Find the total cases vs total deaths as a percentage
-- Select rows where total_deaths is not null and total_cases is not null
SELECT location,
       date,
       total_cases,
       total_deaths,
       (CONVERT(DECIMAL(10, 2), total_deaths) / total_cases) * 100 AS DeathPercentage
FROM CovidDeaths
WHERE total_deaths IS NOT NULL
  AND total_cases IS NOT NULL
  AND continent IS NOT NULL
ORDER BY location, date;

-- QUESTION: Find the death percentage for a specific country, e.g., 'Kenya'?
-- Shows the likelihood of dying if you contract covid in your country
-- Select rows where total_deaths is not null and total_cases is not null and location = 'Kenya'
SELECT location,
       date,
       total_cases,
       total_deaths,
       (CONVERT(DECIMAL(10, 2), total_deaths) / total_cases) * 100 AS DeathPercentage
FROM CovidDeaths
WHERE total_deaths IS NOT NULL
  AND total_cases IS NOT NULL
  AND location = 'Kenya'
ORDER BY location, date;


-- QUESTION: Calculate the percentage of the population infected for a specific country, e.g., 'Kenya'?
-- Total cases vs population - Percentage of the population which got covid
-- Select rows where total_deaths is not null and total_cases is not null and location = 'Kenya'
SELECT location,
       date,
       total_cases,
       population,
       (CONVERT(DECIMAL(10, 2), total_cases) / population) * 100 AS PercentPopulationInfected
FROM CovidDeaths
WHERE total_cases IS NOT NULL
  AND population IS NOT NULL
  AND location = 'Kenya'
  AND continent IS NOT NULL
ORDER BY location, date;


-- QUESTION: Identify countries with the highest infection rate relative to their population?
-- Countries with the highest infection rate compared to population
SELECT location,
       population,
       MAX(total_cases)                                               AS HighestInfectionCount,
       MAX((CONVERT(DECIMAL(18, 4), total_cases) / population)) * 100 AS PercentPopulationInfected
FROM CovidDeaths
WHERE total_cases IS NOT NULL
  AND population IS NOT NULL
  AND continent IS NOT NULL
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC;


-- QUESTION: Find countries with the highest death count per population?
-- Countries with the highest death count per population
SELECT location,
       MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths
WHERE total_deaths IS NOT NULL
  AND continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC;


-- QUESTION: Determine the continent with the highest death count per population?
-- Breaking down by continent - continent with the highest death count per population
SELECT continent,
       MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths
WHERE total_deaths IS NOT NULL
  AND continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC;


-- QUESTION: Calculate the total cases, total deaths, and death percentage for each date?
-- Find total cases, total deaths, and death percentage for each date - use partition over
SELECT date,
       SUM(new_cases)                                                  AS TotalCases,
       SUM(CAST(new_deaths AS INT))                                    AS TotalDeaths,
       SUM(CONVERT(DECIMAL(18, 4), new_deaths)) / SUM(new_cases) * 100 AS DeathPercentage
FROM CovidDeaths
WHERE continent IS NOT NULL
  AND new_cases IS NOT NULL
  AND new_deaths IS NOT NULL
GROUP BY date
ORDER BY date;



SELECT *
FROM CovidVaccinations
WHERE total_tests  IS NOT NULL AND new_tests IS NOT NULL;


-- QUESTION: Calculate the rolling total of new vaccinations for each location over time?
/*
SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated:
Calculates the rolling total of new vaccinations for each location over time. The PARTITION BY clause divides the
result set into partitions to which the SUM function is applied independently. The ORDER BY clause inside the SUM
function determines the order in which the summation is performed.
*/
SELECT dea.continent,
       dea.location,
       dea.date,
       dea.population,
       vac.new_vaccinations,
       SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY  dea.date) AS
           RollingPeopleVaccinated
FROM CovidDeaths dea
         JOIN
     CovidVaccinations vac
     ON
         dea.location = vac.location
             AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
  AND vac.new_vaccinations IS NOT NULL
ORDER BY dea.location, dea.date;


-- QUESTION: Use a Common Table Expression (CTE) to calculate the rolling total of new vaccinations?
-- Using CTE to perform Calculation on Partition By in the previous query
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
    SELECT dea.continent,
           dea.location,
           dea.date,
           dea.population,
           vac.new_vaccinations,
           SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS
               RollingPeopleVaccinated
    FROM CovidDeaths dea
             JOIN
         CovidVaccinations vac
         ON
             dea.location = vac.location
                 AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
      AND vac.new_vaccinations IS NOT NULL
)
SELECT *,
       (CONVERT(DECIMAL, RollingPeopleVaccinated) / Population) * 100 AS PercentageVaccinated
FROM PopvsVac
ORDER BY 2, 3;


-- QUESTION: How can you use a temporary table to store and analyze data for later visualizations?
-- Temp Table to store data for later visualizations
DROP TABLE IF EXISTS #PercentPopulationVaccinated;

CREATE TABLE #PercentPopulationVaccinated
(
    Continent         NVARCHAR(255),
    Location          NVARCHAR(255),
    Date              DATETIME,
    Population        NUMERIC,
    New_Vaccinations  NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent,
       dea.location,
       dea.date,
       dea.population,
       vac.new_vaccinations,
       SUM(CONVERT(NUMERIC, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS
           RollingPeopleVaccinated
FROM CovidDeaths dea
         JOIN
     CovidVaccinations vac
     ON
         dea.location = vac.location
             AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
  AND vac.new_vaccinations IS NOT NULL
ORDER BY dea.location, dea.date;

SELECT *,
       (CONVERT(DECIMAL, RollingPeopleVaccinated) / Population) * 100 AS PercentageVaccinated
FROM #PercentPopulationVaccinated
ORDER BY 2, 3;


-- QUESTION: How can you create a view to simplify data retrieval and analysis for visualizations?
-- Creating a view to store data for later visualizations
CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent,
       dea.location,
       dea.date,
       dea.population,
       vac.new_vaccinations,
       SUM(CONVERT(NUMERIC, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS
           RollingPeopleVaccinated
FROM CovidDeaths dea
         JOIN
     CovidVaccinations vac
     ON
         dea.location = vac.location
             AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
  AND vac.new_vaccinations IS NOT NULL;


-- Select * from PercentPopulationVaccinated;
SELECT *
FROM PercentPopulationVaccinated;
