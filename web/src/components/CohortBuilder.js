import React from 'react';
import './Components.css';

function CohortBuilder({ disease, cohorts }) {
  return (
    <div className="card">
      <div className="card-header">
        <h2>Step 2: Cohort Summary</h2>
        <p className="card-description">
          Case and control cohorts for {disease.name}
        </p>
      </div>

      <div className="cohort-grid">
        <div className="cohort-card cohort-case">
          <div className="cohort-label">CASE (Disease)</div>
          <div className="cohort-count">{cohorts.case.count.toLocaleString()}</div>
          <div className="cohort-description">Patients with {disease.name}</div>
        </div>

        <div className="cohort-card cohort-control">
          <div className="cohort-label">CONTROL (Non-disease)</div>
          <div className="cohort-count">{cohorts.control.count.toLocaleString()}</div>
          <div className="cohort-description">Patients without {disease.name}</div>
        </div>
      </div>
    </div>
  );
}

export default CohortBuilder;

