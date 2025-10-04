import React, { useRef } from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';
import './Components.css';

function AgeSexChart({ data, measurement }) {
  const chartRef = useRef(null);

  // Transform data for recharts
  const chartData = [];
  const ageGroups = ['<20', '20-40', '40-60', '60+'];
  
  ageGroups.forEach(ageGroup => {
    const groupData = { age_group: ageGroup };
    
    // Case cohort - Male
    const caseMale = data.find(d => d.cohort === 'CASE' && d.age_group === ageGroup && d.gender === 'Male');
    groupData['Case - Male'] = caseMale ? caseMale.n_patients : 0;
    
    // Case cohort - Female
    const caseFemale = data.find(d => d.cohort === 'CASE' && d.age_group === ageGroup && d.gender === 'Female');
    groupData['Case - Female'] = caseFemale ? caseFemale.n_patients : 0;
    
    // Control cohort - Male
    const controlMale = data.find(d => d.cohort === 'CONTROL' && d.age_group === ageGroup && d.gender === 'Male');
    groupData['Control - Male'] = controlMale ? controlMale.n_patients : 0;
    
    // Control cohort - Female
    const controlFemale = data.find(d => d.cohort === 'CONTROL' && d.age_group === ageGroup && d.gender === 'Female');
    groupData['Control - Female'] = controlFemale ? controlFemale.n_patients : 0;
    
    chartData.push(groupData);
  });

  const CustomTooltip = ({ active, payload, label }) => {
    if (active && payload && payload.length) {
      return (
        <div style={{
          backgroundColor: 'white',
          padding: '12px',
          border: '1px solid #ccc',
          borderRadius: '4px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.15)'
        }}>
          <p style={{ fontWeight: 'bold', marginBottom: '8px' }}>{`Age Group: ${label}`}</p>
          {payload.map((entry, index) => (
            <p key={index} style={{ color: entry.color, margin: '4px 0' }}>
              {`${entry.name}: ${entry.value} patients`}
            </p>
          ))}
        </div>
      );
    }
    return null;
  };

  const exportToPNG = async () => {
    if (!chartRef.current) return;
    
    try {
      const canvas = await html2canvas(chartRef.current, {
        backgroundColor: '#ffffff',
        scale: 2
      });
      
      const link = document.createElement('a');
      link.download = 'age-sex-comparison.png';
      link.href = canvas.toDataURL();
      link.click();
    } catch (err) {
      console.error('Export to PNG failed:', err);
      alert('Failed to export chart as PNG');
    }
  };

  const exportToPDF = async () => {
    if (!chartRef.current) return;
    
    try {
      const canvas = await html2canvas(chartRef.current, {
        backgroundColor: '#ffffff',
        scale: 2
      });
      
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF({
        orientation: 'landscape',
        unit: 'mm',
        format: 'a4'
      });
      
      const imgWidth = 280;
      const imgHeight = (canvas.height * imgWidth) / canvas.width;
      
      pdf.addImage(imgData, 'PNG', 10, 10, imgWidth, imgHeight);
      pdf.save('age-sex-comparison.pdf');
    } catch (err) {
      console.error('Export to PDF failed:', err);
      alert('Failed to export chart as PDF');
    }
  };

  return (
    <div className="card">
      <div className="card-header">
        <h2>Age Group & Sex Comparison</h2>
        <p className="card-description">
          Patient distribution by age group and sex for {measurement.name}
        </p>
      </div>

      <div className="chart-controls">
        <button onClick={exportToPNG} className="btn btn-secondary">
          Export as PNG
        </button>
        <button onClick={exportToPDF} className="btn btn-secondary">
          Export as PDF
        </button>
      </div>

      <div className="chart-wrapper" ref={chartRef}>
        <ResponsiveContainer width="100%" height={400}>
          <BarChart
            data={chartData}
            margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
          >
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="age_group" label={{ value: 'Age Group', position: 'insideBottom', offset: -10 }} />
            <YAxis label={{ value: 'Number of Patients', angle: -90, position: 'insideLeft' }} />
            <Tooltip content={<CustomTooltip />} />
            <Legend wrapperStyle={{ paddingTop: '20px' }} />
            <Bar dataKey="Case - Male" fill="#fc8181" />
            <Bar dataKey="Case - Female" fill="#f56565" />
            <Bar dataKey="Control - Male" fill="#68d391" />
            <Bar dataKey="Control - Female" fill="#48bb78" />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

export default AgeSexChart;

