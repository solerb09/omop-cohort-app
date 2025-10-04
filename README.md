# OMOP Cohort Analysis Application

A full-stack web application for analyzing diabetes cohorts using OMOP Common Data Model (CDM) with interactive visualizations.

---

## **Project Overview**

This application builds and analyzes **case-control cohorts** from OMOP CDM data:
- **CASE cohort**: Patients with Type 2 diabetes mellitus
- **CONTROL cohort**: Patients without diabetes

### **Key Features**
- ✅ SQL-based cohort derivation using OMOP standard concept IDs
- ✅ Demographic stratification by age group and sex
- ✅ Glucose measurement analysis (box plots, summary statistics)
- ✅ Interactive visualizations with zoom, tooltips, and export (PNG/PDF)
- ✅ RESTful API for data access

---

## **Technology Stack**

- **Database**: DuckDB (embedded SQL analytics)
- **Backend API**: FastAPI (Python)
- **Frontend**: React + TypeScript
- **Charting**: Recharts / Plotly
- **Data Model**: OMOP CDM v5.x

---

## **OMOP Tables Used**

### **1. `person`**
- **Columns**: `PERSON_ID`, `GENDER_CONCEPT_ID`, `YEAR_OF_BIRTH`
- **Purpose**: Patient demographics (age, gender) for both cohorts

### **2. `condition_occurrence`** ✓ (Required)
- **Columns**: `PERSON_ID`, `CONDITION_CONCEPT_ID`, `CONDITION_START_DATE`
- **Purpose**: Identify diabetes patients using condition concept ID 201826

### **3. `concept`** ✓ (Required)
- **Columns**: `concept_id`, `concept_name`
- **Purpose**: Map concept IDs to human-readable names
  - 8507 → "Male"
  - 8532 → "Female"
  - 201826 → "Type 2 diabetes mellitus"

### **4. `measurement`** ✓ (Required)
- **Columns**: `PERSON_ID`, `MEASUREMENT_DATE`, `MEASUREMENT_CONCEPT_ID`
- **Purpose**: 
  - Assign index dates to control patients (first measurement date)
  - Generate synthetic glucose measurements for outcome analysis

---

## **Cohort Logic**

### **CASE Cohort (Disease Group) - Diabetes Patients**

**Definition**: Patients with at least one diagnosis of Type 2 diabetes mellitus (concept ID **201826**)

**SQL Logic** (`scripts/setup_cohorts.sql`):
```sql
SELECT
    PERSON_ID AS person_id,
    MIN(CONDITION_START_DATE) AS index_date
FROM condition_occurrence
WHERE CONDITION_CONCEPT_ID = 201826  -- Type 2 diabetes mellitus
GROUP BY PERSON_ID;
```

**Derivation Steps**:
1. Query `condition_occurrence` table for all diagnosis records
2. Filter to **concept ID 201826** (Type 2 diabetes mellitus)
3. Group by `PERSON_ID` to get unique patients
4. Use `MIN(CONDITION_START_DATE)` as the **index date** (first diabetes diagnosis)
5. **Result**: 672 diabetes patients with their diagnosis dates

---

### **CONTROL Cohort (Non-Disease Group) - Non-Diabetes Patients**

**Definition**: Patients with **no** diabetes diagnosis, assigned an index date from their first measurement or default date

**SQL Logic** (`scripts/setup_cohorts.sql`):
```sql
WITH first_measurement AS (
    SELECT 
        PERSON_ID AS person_id, 
        MIN(MEASUREMENT_DATE) AS index_date
    FROM measurement
    GROUP BY PERSON_ID
)
SELECT 
    p.PERSON_ID AS person_id, 
    COALESCE(fm.index_date, DATE '1970-01-01') AS index_date
FROM person p
LEFT JOIN cohort_case cc ON p.PERSON_ID = cc.person_id
LEFT JOIN first_measurement fm ON p.PERSON_ID = fm.person_id
WHERE cc.person_id IS NULL;  -- Exclude diabetes patients
```

**Derivation Steps**:
1. Start with all patients in the `person` table
2. **LEFT JOIN to `cohort_case`** and filter `WHERE cc.person_id IS NULL` (anti-join to exclude diabetes patients)
3. Assign **index date** using:
   - First measurement date from `measurement` table if available
   - Default to `1970-01-01` if no measurements exist
4. **Result**: 328 non-diabetes patients with index dates

---

## **Key Design Decisions**

### **1. Mutually Exclusive Cohorts**
Each patient appears in **exactly ONE cohort** (CASE or CONTROL, never both) via anti-join logic.

### **2. Index Date Strategy**
- **CASE**: First diabetes diagnosis date (clinically meaningful anchor point)
- **CONTROL**: First measurement date or `1970-01-01` (proxy for healthcare system entry)

### **3. Concept-Driven Selection**
Used standardized OMOP concept IDs (201826) rather than free-text condition names to ensure reproducibility across OMOP-compliant databases.

### **4. Synthetic Measurements**
Since SYNPUF data lacks actual measurement values (privacy protection), we generate synthetic glucose values:
- **CASE (Diabetes)**: Mean ~150 mg/dL, range 80-400 mg/dL
- **CONTROL (Non-diabetes)**: Mean ~95 mg/dL, range 65-140 mg/dL

---

## **Concept IDs Used**

### **Disease Concepts** (from `condition_occurrence`):
- **201826**: Type 2 diabetes mellitus (CASE cohort definition)

### **Demographic Concepts** (from `person` via `concept` table):
- **8507**: Male
- **8532**: Female

### **Measurement Concepts** (synthetic data generation):
- **3034639**: Glucose [Mass/volume] in Serum or Plasma

---

## **Project Structure**

```
omop-cohort-app/
├── api/                          # FastAPI backend
│   ├── Dockerfile
│   └── requirements.txt
├── data/
│   ├── synpuf_1k/               # 1K patient OMOP SYNPUF dataset
│   │   ├── CDM_PERSON.csv
│   │   ├── CDM_CONDITION_OCCURRENCE.csv
│   │   └── CDM_MEASUREMENT.csv
│   └── omop.duckdb              # DuckDB database (generated)
├── scripts/                      # SQL cohort logic
│   ├── load_data.sql            # Load CSVs into DuckDB
│   ├── create_concept.sql       # Create concept mapping table
│   ├── setup_cohorts.sql        # Build CASE/CONTROL cohorts
│   ├── demographics.sql         # Calculate age/gender demographics
│   └── generate_all_measurements.sql  # Create synthetic measurement data (all 4 types)
├── web/                          # React frontend
│   └── Dockerfile
├── docker-compose.yml
└── README.md
```

---

## **Quick Start with Docker**

### **Prerequisites**
- Docker and Docker Compose installed
- 2GB free disk space
- Ports 80 and 8000 available

### **1. Clone & Setup**

```bash
git clone <your-repo-url> omop-cohort-app
cd omop-cohort-app

# Download 1K SYNPUF dataset
aws s3 sync --no-sign-request s3://synpuf-omop/cmsdesynpuf1k/ data/synpuf_1k/
bunzip2 data/synpuf_1k/*.bz2

# Build cohorts and generate data
duckdb data/omop.duckdb \
  ".read scripts/load_data.sql" \
  ".read scripts/create_concept.sql" \
  ".read scripts/setup_cohorts.sql" \
  ".read scripts/demographics.sql" \
  ".read scripts/generate_all_measurements.sql"
```

### **2. Run with Docker Compose**

```bash
docker compose up --build
```

### **3. Open Application**

Navigate to **http://localhost:80** in Chrome/Firefox

---

## **Usage Guide**

### **Step 1: Create Account & Login**

1. On first visit, click "Create account"
2. Enter your name, email, and password (min 6 characters)
3. Click "Sign Up" → You'll be redirected to login
4. Login with your credentials
5. To test password reset: Click "Forgot password?" and enter your email

### **Step 2: Select Disease**

1. On the dashboard, use the **Disease / Non-disease** dropdown
2. Select a disease (e.g., "Type 2 diabetes mellitus")
3. Cohorts will automatically build showing:
   - **CASE**: Patients with the disease
   - **CONTROL**: Patients without the disease

### **Step 3: Pick Measurement Variable**

1. Use the **Measurement** dropdown
2. Select an outcome variable (e.g., "Glucose [Mass/volume] in Serum or Plasma")
3. Charts and statistics will load automatically

### **Step 4: View & Export Plots**

#### **Age Group & Sex Comparison**
- View grouped bar chart showing patient distribution by age (<20, 20–40, 40–60, 60+) and sex
- Hover over bars to see patient counts
- Click "Export as PNG" or "Export as PDF" to download

#### **Box Plot Comparison**
- View disease vs. non-disease measurement distributions
- **Hover** over boxes to see median, P25, P75, min, max
- **Zoom In/Out** using the zoom buttons
- **Reset Zoom** to return to original view
- **Export as PNG/PDF** to download the chart

#### **Summary Statistics**
- View detailed stats: n (patients), n (measurements), median, P25, P75, mean, range
- Separate stats for CASE and CONTROL cohorts

---

## **Manual Setup (Without Docker)**

### **Backend API**

```bash
cd api
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### **Frontend**

```bash
cd web
npm install
npm start
```

Then open http://localhost:3000

---

## **Cohort Summary Statistics**

| Cohort | Patients | Mean Age | Male | Female | % Male |
|--------|----------|----------|------|--------|--------|
| **CASE (Diabetes)** | 672 | 72.4 | 323 | 349 | 48.1% |
| **CONTROL (Non-diabetes)** | 328 | 40.0 | 179 | 149 | 54.6% |

**Measurements Generated** (Synthetic Glucose):
| Cohort | Measurements | Median | P25 | P75 | Range |
|--------|--------------|--------|-----|-----|-------|
| **CASE** | 4,340 | ~150 mg/dL | ~135 | ~165 | 91.6–208 |
| **CONTROL** | 334 | ~95 mg/dL | ~85 | ~105 | 65.8–121.8 |

---

## **API Endpoints**

- `GET /api/cohorts/summary` — Cohort counts and demographics
- `GET /api/measurements/summary` — Box plot data (median, p25, p75)
- `GET /api/measurements/by-age-sex` — Age/sex stratified measurements
- `GET /api/demographics` — Full demographic breakdown

---

## **Visualizations**

1. **Age Group & Sex Comparison**: Grouped/stacked bar charts showing cohort distributions by age (<20, 20–40, 40–60, 60+) and sex
2. **Glucose Measurement Box Plot**: Interactive comparison of disease vs. non-disease with:
   - Tooltips on hover (group label, median, quartiles)
   - Zoom in/out controls
   - Export as PNG/PDF

---

## **Data Sources**

- **Dataset**: CMS DE-SynPUF 1K (1,000 synthetic patients)
- **Source**: AWS Public Dataset Registry
- **OMOP Version**: CDM v5.x
- **Bucket**: `s3://synpuf-omop/cmsdesynpuf1k/`

---

## **License**

MIT License - See LICENSE file for details

---

## **Docker Hub**

Pre-built images are available on Docker Hub:

```bash
# Pull images
docker pull <your-dockerhub-username>/omop-api:latest
docker pull <your-dockerhub-username>/omop-web:latest

# Run with Docker Hub images
docker compose -f docker-compose.hub.yml up
```

### **Building & Pushing to Docker Hub**

```bash
# Build images
docker build -t <your-username>/omop-api:latest ./api
docker build -t <your-username>/omop-web:latest ./web

# Push to Docker Hub
docker push <your-username>/omop-api:latest
docker push <your-username>/omop-web:latest
```

---

## **AI Assistance Disclosure**

This project was developed with assistance from **Claude (Anthropic)** and **Cursor AI**.

### **AI Platforms Used:**
1. **Claude Sonnet 4.5** (via Cursor IDE)
   - Code generation and architecture design
   - React component development
   - FastAPI endpoint implementation
   - SQL query optimization
   - Documentation writing

### **Key Prompts Used:**

1. **Initial Setup:**
   - "Build a full-stack OMOP cohort analysis app with React, FastAPI, and DuckDB"
   - "Create SQL scripts to load SYNPUF data and build diabetes cohorts"

2. **Backend Development:**
   - "Create FastAPI endpoints for disease selection, cohort building, and measurement analysis"
   - "Add mock authentication with signup, login, and password reset"

3. **Frontend Development:**
   - "Build React components for disease selector, cohort builder, and measurement picker"
   - "Create an age/sex comparison bar chart with Recharts and export functionality"
   - "Build a box plot with Plotly that supports hover tooltips, zoom, and PNG/PDF export"

4. **Docker & Deployment:**
   - "Create Dockerfiles for FastAPI and React with nginx"
   - "Write a docker-compose.yml for full-stack deployment"

5. **Documentation:**
   - "Update README with usage guide, OMOP table explanations, and cohort logic"

### **Development Workflow:**
- AI assisted with ~80% of code generation
- Human review, testing, and refinement of all generated code
- Custom modifications for SYNPUF-specific data handling
- Manual integration and debugging

---

## **Screenshots**

*(Add screenshots here showing:)*
1. Login page
2. Disease selection dropdown
3. Cohort builder with counts
4. Age/sex comparison chart
5. Box plot with export options
6. Summary statistics display

---

## **Contact**

For questions or issues, please open a GitHub issue.

---

## **License**

MIT License - See LICENSE file for details

