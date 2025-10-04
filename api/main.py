from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
import duckdb
import os
from pathlib import Path

app = FastAPI(title="OMOP Cohort Analysis API")

# CORS middleware for React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://localhost:80", "http://localhost:3000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection
DB_PATH = os.getenv("DB_PATH", "/app/data/omop.duckdb")

def get_db():
    """Get DuckDB connection"""
    conn = duckdb.connect(DB_PATH, read_only=True)
    try:
        yield conn
    finally:
        conn.close()

# ==================== Models ====================

class UserSignup(BaseModel):
    email: EmailStr
    password: str
    name: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class PasswordReset(BaseModel):
    email: EmailStr

class CohortRequest(BaseModel):
    disease_concept_id: int

class MeasurementRequest(BaseModel):
    disease_concept_id: int
    measurement_concept_id: Optional[int] = 3034639  # Default: Glucose

# ==================== Mock Auth (Simple) ====================

# In-memory user store (mock)
users_db = {}

@app.post("/api/auth/signup")
async def signup(user: UserSignup):
    """Mock user signup"""
    if user.email in users_db:
        raise HTTPException(status_code=400, detail="User already exists")
    
    users_db[user.email] = {
        "email": user.email,
        "name": user.name,
        "password": user.password  # NOTE: In production, hash this!
    }
    
    return {
        "success": True,
        "message": "Account created successfully",
        "user": {"email": user.email, "name": user.name}
    }

@app.post("/api/auth/login")
async def login(credentials: UserLogin):
    """Mock user login"""
    user = users_db.get(credentials.email)
    
    if not user or user["password"] != credentials.password:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    return {
        "success": True,
        "message": "Login successful",
        "user": {"email": user["email"], "name": user["name"]},
        "token": f"mock_token_{user['email']}"  # Mock JWT token
    }

@app.post("/api/auth/reset-password")
async def reset_password(reset: PasswordReset):
    """Mock password reset"""
    if reset.email not in users_db:
        # Don't reveal if user exists (security best practice)
        pass
    
    return {
        "success": True,
        "message": f"Password reset email sent to {reset.email}"
    }

# ==================== Disease Selection ====================

@app.get("/api/diseases")
async def get_diseases(db: duckdb.DuckDBPyConnection = Depends(get_db)):
    """Get available diseases from concept table"""
    try:
        result = db.execute("""
            SELECT DISTINCT 
                co.CONDITION_CONCEPT_ID as concept_id,
                c.concept_name as name,
                COUNT(DISTINCT co.PERSON_ID) as patient_count
            FROM condition_occurrence co
            LEFT JOIN concept c ON co.CONDITION_CONCEPT_ID = c.concept_id
            WHERE co.CONDITION_CONCEPT_ID IN (201826, 320128, 312648, 432867)
            GROUP BY co.CONDITION_CONCEPT_ID, c.concept_name
            ORDER BY patient_count DESC
        """).fetchall()
        
        diseases = [
            {
                "concept_id": row[0],
                "name": row[1] or f"Condition {row[0]}",
                "patient_count": row[2]
            }
            for row in result
        ]
        
        return {"diseases": diseases}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ==================== Cohort Builder ====================

@app.post("/api/cohorts/build")
async def build_cohorts(request: CohortRequest, db: duckdb.DuckDBPyConnection = Depends(get_db)):
    """Build case and control cohorts for a given disease"""
    try:
        # Get case count (disease)
        case_result = db.execute("""
            SELECT COUNT(DISTINCT PERSON_ID) as n
            FROM condition_occurrence
            WHERE CONDITION_CONCEPT_ID = ?
        """, [request.disease_concept_id]).fetchone()
        
        # Get control count (no disease)
        control_result = db.execute("""
            SELECT COUNT(DISTINCT p.PERSON_ID) as n
            FROM person p
            WHERE p.PERSON_ID NOT IN (
                SELECT DISTINCT PERSON_ID 
                FROM condition_occurrence 
                WHERE CONDITION_CONCEPT_ID = ?
            )
        """, [request.disease_concept_id]).fetchone()
        
        return {
            "success": True,
            "disease_concept_id": request.disease_concept_id,
            "cohorts": {
                "case": {"count": case_result[0], "label": "Disease"},
                "control": {"count": control_result[0], "label": "Non-disease"}
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ==================== Measurements ====================

@app.get("/api/measurements/available")
async def get_available_measurements():
    """Get available measurement types"""
    # Common OMOP measurement concepts
    return {
        "measurements": [
            {
                "concept_id": 3034639,
                "name": "Glucose [Mass/volume] in Serum or Plasma",
                "unit": "mg/dL"
            },
            {
                "concept_id": 3004410,
                "name": "Hemoglobin A1c/Hemoglobin.total in Blood",
                "unit": "%"
            },
            {
                "concept_id": 3004249,
                "name": "Systolic Blood Pressure (SBP)",
                "unit": "mmHg"
            },
            {
                "concept_id": 3012888,
                "name": "Diastolic Blood Pressure (DBP)",
                "unit": "mmHg"
            }
        ]
    }

@app.post("/api/measurements/summary")
async def get_measurement_summary(request: MeasurementRequest, db: duckdb.DuckDBPyConnection = Depends(get_db)):
    """Get measurement summary statistics for box plot"""
    try:
        # Check if measurement tables exist
        tables_check = db.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='measurement_summary'
        """).fetchall()
        
        if not tables_check:
            raise HTTPException(
                status_code=404, 
                detail="Measurement data not found. Please run generate_synthetic_measurements.sql first."
            )
        
        result = db.execute("""
            SELECT 
                cohort,
                n_measurements,
                n_patients,
                mean_value,
                median_value,
                p25,
                p75,
                min_value,
                max_value,
                std_dev
            FROM measurement_summary
            ORDER BY cohort
        """).fetchall()
        
        summary = [
            {
                "cohort": row[0],
                "n_measurements": row[1],
                "n_patients": row[2],
                "mean": row[3],
                "median": row[4],
                "p25": row[5],
                "p75": row[6],
                "min": row[7],
                "max": row[8],
                "std_dev": row[9]
            }
            for row in result
        ]
        
        return {"summary": summary}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/api/measurements/by-age-sex")
async def get_measurements_by_age_sex(request: MeasurementRequest, db: duckdb.DuckDBPyConnection = Depends(get_db)):
    """Get measurements stratified by age group and sex"""
    try:
        result = db.execute("""
            SELECT 
                cohort,
                age_group,
                gender,
                n_patients,
                n_measurements,
                mean_value,
                median_value
            FROM measurement_by_age_sex
            ORDER BY 
                cohort, 
                CASE age_group
                    WHEN '<20' THEN 1
                    WHEN '20-40' THEN 2
                    WHEN '40-60' THEN 3
                    WHEN '60+' THEN 4
                END,
                gender
        """).fetchall()
        
        data = [
            {
                "cohort": row[0],
                "age_group": row[1],
                "gender": row[2],
                "n_patients": row[3],
                "n_measurements": row[4],
                "mean_value": row[5],
                "median_value": row[6]
            }
            for row in result
        ]
        
        return {"data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ==================== Demographics ====================

@app.get("/api/demographics")
async def get_demographics(db: duckdb.DuckDBPyConnection = Depends(get_db)):
    """Get demographic summary for all cohorts"""
    try:
        # Check if demographics tables exist
        case_check = db.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='demographics_case'
        """).fetchall()
        
        if not case_check:
            raise HTTPException(
                status_code=404,
                detail="Demographics data not found. Please run demographics.sql first."
            )
        
        result = db.execute("""
            SELECT 
                'CASE' as cohort,
                COUNT(*) as n_patients,
                ROUND(AVG(age_at_index), 1) as mean_age,
                COUNT(CASE WHEN gender = 'Male' THEN 1 END) as n_male,
                COUNT(CASE WHEN gender = 'Female' THEN 1 END) as n_female
            FROM demographics_case
            UNION ALL
            SELECT 
                'CONTROL' as cohort,
                COUNT(*) as n_patients,
                ROUND(AVG(age_at_index), 1) as mean_age,
                COUNT(CASE WHEN gender = 'Male' THEN 1 END) as n_male,
                COUNT(CASE WHEN gender = 'Female' THEN 1 END) as n_female
            FROM demographics_control
        """).fetchall()
        
        demographics = [
            {
                "cohort": row[0],
                "n_patients": row[1],
                "mean_age": row[2],
                "n_male": row[3],
                "n_female": row[4],
                "pct_male": round(100 * row[3] / row[1], 1) if row[1] > 0 else 0
            }
            for row in result
        ]
        
        return {"demographics": demographics}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ==================== Health Check ====================

@app.get("/")
async def root():
    """API health check"""
    return {
        "status": "healthy",
        "message": "OMOP Cohort Analysis API",
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check(db: duckdb.DuckDBPyConnection = Depends(get_db)):
    """Check database connectivity"""
    try:
        result = db.execute("SELECT 1").fetchone()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database unavailable: {str(e)}")

