import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';
import DiseaseSelector from '../components/DiseaseSelector';
import CohortBuilder from '../components/CohortBuilder';
import MeasurementPicker from '../components/MeasurementPicker';
import AgeSexChart from '../components/AgeSexChart';
import BoxPlotChart from '../components/BoxPlotChart';
import SummaryStats from '../components/SummaryStats';
import { diseaseAPI, cohortAPI, measurementAPI } from '../api';
import './Dashboard.css';

function Dashboard() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  
  // State
  const [diseases, setDiseases] = useState([]);
  const [selectedDisease, setSelectedDisease] = useState(null);
  const [cohorts, setCohorts] = useState(null);
  const [measurements, setMeasurements] = useState([]);
  const [selectedMeasurement, setSelectedMeasurement] = useState(null);
  const [measurementSummary, setMeasurementSummary] = useState(null);
  const [ageSexData, setAgeSexData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Load diseases on mount
  useEffect(() => {
    loadDiseases();
    loadMeasurements();
  }, []);

  const loadDiseases = async () => {
    try {
      const response = await diseaseAPI.getAvailable();
      setDiseases(response.data.diseases);
    } catch (err) {
      setError('Failed to load diseases');
    }
  };

  const loadMeasurements = async () => {
    try {
      const response = await measurementAPI.getAvailable();
      setMeasurements(response.data.measurements);
      // Default to first measurement (Glucose)
      if (response.data.measurements.length > 0) {
        setSelectedMeasurement(response.data.measurements[0]);
      }
    } catch (err) {
      setError('Failed to load measurements');
    }
  };

  const handleDiseaseSelect = async (disease) => {
    setSelectedDisease(disease);
    setError('');
    setLoading(true);

    try {
      // Build cohorts
      const cohortResponse = await cohortAPI.build(disease.concept_id);
      setCohorts(cohortResponse.data.cohorts);

      // Load measurement data if measurement is selected
      if (selectedMeasurement) {
        await loadMeasurementData(disease.concept_id, selectedMeasurement.concept_id);
      }
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to build cohorts');
      setCohorts(null);
    } finally {
      setLoading(false);
    }
  };

  const handleMeasurementSelect = async (measurement) => {
    setSelectedMeasurement(measurement);
    
    if (selectedDisease) {
      await loadMeasurementData(selectedDisease.concept_id, measurement.concept_id);
    }
  };

  const loadMeasurementData = async (diseaseId, measurementId) => {
    setLoading(true);
    setError('');

    try {
      // Load summary stats
      const summaryResponse = await measurementAPI.getSummary(diseaseId, measurementId);
      setMeasurementSummary(summaryResponse.data.summary);

      // Load age/sex data
      const ageSexResponse = await measurementAPI.getByAgeSex(diseaseId, measurementId);
      setAgeSexData(ageSexResponse.data.data);
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to load measurement data');
      setMeasurementSummary(null);
      setAgeSexData(null);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="dashboard">
      {/* Header */}
      <header className="dashboard-header">
        <div className="header-content">
          <h1>OMOP Cohort Analysis</h1>
          <div className="header-right">
            <span className="user-name">Welcome, {user?.name}</span>
            <button onClick={handleLogout} className="btn btn-secondary">
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="dashboard-main">
        {error && (
          <div className="alert alert-error">
            {error}
          </div>
        )}

        {/* Step 1: Disease Selection */}
        <section className="dashboard-section">
          <DiseaseSelector
            diseases={diseases}
            selectedDisease={selectedDisease}
            onSelect={handleDiseaseSelect}
            loading={loading}
          />
        </section>

        {/* Step 2: Cohort Builder */}
        {selectedDisease && cohorts && (
          <section className="dashboard-section">
            <CohortBuilder
              disease={selectedDisease}
              cohorts={cohorts}
            />
          </section>
        )}

        {/* Step 3: Measurement Selection */}
        {selectedDisease && cohorts && (
          <section className="dashboard-section">
            <MeasurementPicker
              measurements={measurements}
              selectedMeasurement={selectedMeasurement}
              onSelect={handleMeasurementSelect}
              loading={loading}
            />
          </section>
        )}

        {/* Step 4: Visualizations */}
        {selectedDisease && cohorts && selectedMeasurement && measurementSummary && (
          <>
            {/* Summary Statistics */}
            <section className="dashboard-section">
              <SummaryStats
                summary={measurementSummary}
                measurement={selectedMeasurement}
              />
            </section>

            {/* Age/Sex Comparison Chart */}
            {ageSexData && ageSexData.length > 0 ? (
              <section className="dashboard-section">
                <AgeSexChart
                  data={ageSexData}
                  measurement={selectedMeasurement}
                />
              </section>
            ) : (
              <section className="dashboard-section">
                <div className="card">
                  <div className="alert alert-info">
                    No age/sex data available for this cohort.
                  </div>
                </div>
              </section>
            )}

            {/* Box Plot */}
            <section className="dashboard-section">
              <BoxPlotChart
                summary={measurementSummary}
                measurement={selectedMeasurement}
                disease={selectedDisease}
              />
            </section>
          </>
        )}

        {/* Loading State */}
        {loading && <div className="spinner" />}

        {/* Empty State */}
        {!selectedDisease && !loading && (
          <div className="empty-state">
            <h2>Get Started</h2>
            <p>Select a disease above to begin building your cohorts and analyzing measurements.</p>
          </div>
        )}
      </main>
    </div>
  );
}

export default Dashboard;

