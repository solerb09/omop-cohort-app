import React from 'react';
import './Components.css';

function MeasurementPicker({ measurements, selectedMeasurement, onSelect, loading }) {
  return (
    <div className="card">
      <div className="card-header">
        <h2>Step 3: Select Measurement</h2>
        <p className="card-description">
          Choose an outcome variable to analyze
        </p>
      </div>

      <div className="form-group">
        <label htmlFor="measurement-select">Measurement</label>
        <select
          id="measurement-select"
          value={selectedMeasurement?.concept_id || ''}
          onChange={(e) => {
            const measurement = measurements.find(m => m.concept_id === parseInt(e.target.value));
            if (measurement) onSelect(measurement);
          }}
          disabled={loading}
        >
          <option value="">-- Select a measurement --</option>
          {measurements.map(measurement => (
            <option key={measurement.concept_id} value={measurement.concept_id}>
              {measurement.name}
            </option>
          ))}
        </select>
      </div>

      {selectedMeasurement && (
        <div className="selected-info">
          <strong>Selected:</strong> {selectedMeasurement.name}
          {selectedMeasurement.unit && ` (${selectedMeasurement.unit})`}
        </div>
      )}
    </div>
  );
}

export default MeasurementPicker;

