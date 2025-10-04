# OMOP Cohort App - Quick Start Guide

## TL;DR

```bash
# 1. Download data
aws s3 sync --no-sign-request s3://synpuf-omop/cmsdesynpuf1k/ data/synpuf_1k/
bunzip2 data/synpuf_1k/*.bz2

# 2. Build cohorts
duckdb data/omop.duckdb ".read scripts/load_data.sql" ".read scripts/create_concept.sql" ".read scripts/setup_cohorts.sql" ".read scripts/demographics.sql" ".read scripts/generate_synthetic_measurements.sql"

# 3. Run app
docker compose up --build

# 4. Open browser
http://localhost
```

---

## Step-by-Step

### 1. Prerequisites
- Docker & Docker Compose
- AWS CLI (optional, for data download)
- DuckDB CLI

### 2. Download SYNPUF Data

```bash
cd omop-cohort-app

# Download 1K patient dataset
aws s3 sync --no-sign-request \
  s3://synpuf-omop/cmsdesynpuf1k/ \
  data/synpuf_1k/

# Decompress files
bunzip2 data/synpuf_1k/*.bz2
```

### 3. Build Cohorts & Generate Data

```bash
duckdb data/omop.duckdb <<EOF
.read scripts/load_data.sql
.read scripts/create_concept.sql
.read scripts/setup_cohorts.sql
.read scripts/demographics.sql
.read scripts/generate_synthetic_measurements.sql
EOF
```

**What this does:**
- Loads person, condition_occurrence, and measurement tables
- Creates concept mapping (disease & gender codes)
- Builds diabetes CASE (672 patients) & CONTROL (328 patients) cohorts
- Calculates demographics (age, gender)
- Generates synthetic glucose measurements (SYNPUF has no real values)

### 4. Start Application

```bash
docker compose up --build
```

**Services started:**
- **API** (FastAPI): http://localhost:8000
- **Web** (React + Nginx): http://localhost

### 5. Use the App

1. **Create Account**: http://localhost → Click "Create account"
   - Name: John Doe
   - Email: john@example.com
   - Password: password123

2. **Login** with your credentials

3. **Select Disease**: Choose "Type 2 diabetes mellitus" from dropdown

4. **View Cohorts**:
   - CASE: 672 patients
   - CONTROL: 328 patients

5. **Select Measurement**: Choose "Glucose [Mass/volume]..."

6. **View Charts**:
   - Age/Sex comparison bar chart
   - Box plot with median, quartiles
   - Summary statistics

7. **Export**: Click "Export as PNG" or "Export as PDF" on any chart

---

## Troubleshooting

### Port conflicts
```bash
# Change ports in docker-compose.yml:
ports:
  - "8080:80"    # Web on port 8080
  - "8001:8000"  # API on port 8001
```

### Database locked
```bash
# Close any open DuckDB connections
pkill duckdb
```

### Missing data
```bash
# Verify data loaded
duckdb data/omop.duckdb "SELECT COUNT(*) FROM person;"
# Should return: 1000

duckdb data/omop.duckdb "SELECT COUNT(*) FROM cohort_case;"
# Should return: 672
```

### API not responding
```bash
# Check API logs
docker logs omop-api

# Test API directly
curl http://localhost:8000/health
```

---

## File Structure

```
omop-cohort-app/
├── api/
│   ├── main.py              ← FastAPI application
│   ├── requirements.txt
│   └── Dockerfile
├── web/
│   ├── src/
│   │   ├── App.js
│   │   ├── pages/
│   │   │   ├── Login.js
│   │   │   ├── Signup.js
│   │   │   ├── PasswordReset.js
│   │   │   └── Dashboard.js
│   │   └── components/
│   │       ├── DiseaseSelector.js
│   │       ├── CohortBuilder.js
│   │       ├── MeasurementPicker.js
│   │       ├── AgeSexChart.js     ← Recharts bar chart
│   │       ├── BoxPlotChart.js    ← Plotly box plot
│   │       └── SummaryStats.js
│   ├── package.json
│   ├── Dockerfile
│   └── nginx.conf
├── data/
│   ├── synpuf_1k/           ← CSV files
│   └── omop.duckdb          ← Generated database
├── scripts/
│   ├── load_data.sql
│   ├── create_concept.sql
│   ├── setup_cohorts.sql
│   ├── demographics.sql
│   └── generate_synthetic_measurements.sql
├── docker-compose.yml
└── README.md
```

---

## Key Features Checklist

- [x] **Auth**: Signup, login, password reset (mock)
- [x] **Disease Selector**: Dropdown with patient counts
- [x] **Cohort Builder**: CASE/CONTROL counts
- [x] **Measurement Picker**: Glucose selection
- [x] **Age/Sex Chart**: Grouped bars by age group (<20, 20-40, 40-60, 60+) and sex
- [x] **Box Plot**: Median, P25, P75 with hover tooltips
- [x] **Zoom**: Zoom in/out buttons
- [x] **Export**: PNG and PDF export for both charts
- [x] **Summary Stats**: n, median, P25, P75, mean for both cohorts
- [x] **Error Handling**: Empty state messages and error alerts
- [x] **Docker**: Full stack containerized
- [x] **OMOP Tables Used**: person, condition_occurrence, measurement, concept

---

## Next Steps

- Push to GitHub: `git push origin main`
- Build & push Docker images to Docker Hub
- Add screenshots to README
- Test on clean machine with `docker compose up --build`

