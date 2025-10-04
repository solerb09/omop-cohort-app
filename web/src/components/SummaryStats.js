import React from 'react';
import './Components.css';

function SummaryStats({ summary, measurement }) {
  return (
    <div className="card">
      <div className="card-header">
        <h2>Summary Statistics</h2>
        <p className="card-description">
          Descriptive statistics for {measurement.name}
        </p>
      </div>

      <div className="stats-grid">
        {summary.map((cohort) => (
          <div key={cohort.cohort} className={`stats-card stats-${cohort.cohort.toLowerCase()}`}>
            <div className="stats-cohort-label">{cohort.cohort}</div>
            
            <div className="stats-row">
              <span className="stats-label">n (patients)</span>
              <span className="stats-value">{cohort.n_patients.toLocaleString()}</span>
            </div>

            <div className="stats-row">
              <span className="stats-label">n (measurements)</span>
              <span className="stats-value">{cohort.n_measurements.toLocaleString()}</span>
            </div>

            <div className="stats-row">
              <span className="stats-label">Median</span>
              <span className="stats-value">{cohort.median} {measurement.unit}</span>
            </div>

            <div className="stats-row">
              <span className="stats-label">P25</span>
              <span className="stats-value">{cohort.p25} {measurement.unit}</span>
            </div>

            <div className="stats-row">
              <span className="stats-label">P75</span>
              <span className="stats-value">{cohort.p75} {measurement.unit}</span>
            </div>

            <div className="stats-row">
              <span className="stats-label">Mean</span>
              <span className="stats-value">{cohort.mean} {measurement.unit}</span>
            </div>

            <div className="stats-row">
              <span className="stats-label">Range</span>
              <span className="stats-value">{cohort.min} - {cohort.max} {measurement.unit}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default SummaryStats;

