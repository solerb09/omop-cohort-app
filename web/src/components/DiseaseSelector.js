import React from 'react';
import './Components.css';

function DiseaseSelector({ diseases, selectedDisease, onSelect, loading }) {
  return (
    <div className="card">
      <div className="card-header">
        <h2>Step 1: Select Disease</h2>
        <p className="card-description">
          Choose a disease to build case (disease) and control (non-disease) cohorts
        </p>
      </div>

      <div className="form-group">
        <label htmlFor="disease-select">Disease / Non-disease</label>
        <select
          id="disease-select"
          value={selectedDisease?.concept_id || ''}
          onChange={(e) => {
            const disease = diseases.find(d => d.concept_id === parseInt(e.target.value));
            if (disease) onSelect(disease);
          }}
          disabled={loading}
        >
          <option value="">-- Select a disease --</option>
          {diseases.map(disease => (
            <option key={disease.concept_id} value={disease.concept_id}>
              {disease.name} ({disease.patient_count} patients)
            </option>
          ))}
        </select>
      </div>

      {selectedDisease && (
        <div className="selected-info">
          <strong>Selected:</strong> {selectedDisease.name}
        </div>
      )}
    </div>
  );
}

export default DiseaseSelector;

