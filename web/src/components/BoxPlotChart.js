import React, { useRef, useState } from 'react';
import Plot from 'react-plotly.js';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';
import './Components.css';

function BoxPlotChart({ summary, measurement, disease }) {
  const chartRef = useRef(null);
  const [zoomLevel, setZoomLevel] = useState(1);

  // Prepare box plot data
  const traces = summary.map((cohort) => ({
    type: 'box',
    name: cohort.cohort === 'CASE' ? `Disease (${disease.name})` : 'Non-disease',
    y: [cohort.min, cohort.p25, cohort.median, cohort.p75, cohort.max],
    marker: {
      color: cohort.cohort === 'CASE' ? '#fc8181' : '#68d391'
    },
    boxmean: 'sd',
    hovertemplate: 
      '<b>%{fullData.name}</b><br>' +
      'Median: %{median}<br>' +
      'P25: %{q1}<br>' +
      'P75: %{q3}<br>' +
      'Min: %{lowerfence}<br>' +
      'Max: %{upperfence}<br>' +
      '<extra></extra>',
    // Custom quartile values
    q1: [cohort.p25],
    median: [cohort.median],
    q3: [cohort.p75],
    lowerfence: [cohort.min],
    upperfence: [cohort.max]
  }));

  const layout = {
    title: {
      text: `${measurement.name} Distribution: Disease vs Non-disease`,
      font: { size: 18, family: 'Arial, sans-serif' }
    },
    yaxis: {
      title: `${measurement.name} (${measurement.unit || ''})`,
      zeroline: false
    },
    xaxis: {
      title: 'Cohort'
    },
    plot_bgcolor: '#ffffff',
    paper_bgcolor: '#ffffff',
    showlegend: false,
    hovermode: 'closest',
    margin: { l: 60, r: 40, t: 80, b: 60 }
  };

  const config = {
    responsive: true,
    displayModeBar: true,
    modeBarButtonsToAdd: ['hoverclosest', 'hovercompare'],
    modeBarButtonsToRemove: ['toImage'], // We'll use custom export buttons
    displaylogo: false,
    toImageButtonOptions: {
      format: 'png',
      filename: 'box-plot',
      scale: 2
    }
  };

  const handleZoomIn = () => {
    setZoomLevel(prev => Math.min(prev + 0.2, 2));
  };

  const handleZoomOut = () => {
    setZoomLevel(prev => Math.max(prev - 0.2, 0.5));
  };

  const handleResetZoom = () => {
    setZoomLevel(1);
  };

  const exportToPNG = async () => {
    if (!chartRef.current) return;
    
    try {
      const plotElement = chartRef.current.querySelector('.js-plotly-plot');
      if (!plotElement) {
        alert('Chart not ready for export');
        return;
      }

      const canvas = await html2canvas(plotElement, {
        backgroundColor: '#ffffff',
        scale: 2
      });
      
      const link = document.createElement('a');
      link.download = 'box-plot.png';
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
      const plotElement = chartRef.current.querySelector('.js-plotly-plot');
      if (!plotElement) {
        alert('Chart not ready for export');
        return;
      }

      const canvas = await html2canvas(plotElement, {
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
      pdf.save('box-plot.pdf');
    } catch (err) {
      console.error('Export to PDF failed:', err);
      alert('Failed to export chart as PDF');
    }
  };

  return (
    <div className="card">
      <div className="card-header">
        <h2>Box Plot Comparison</h2>
        <p className="card-description">
          {measurement.name} distribution with median, quartiles, and range
        </p>
      </div>

      <div className="chart-controls">
        <button onClick={handleZoomIn} className="btn btn-secondary">
          Zoom In (+)
        </button>
        <button onClick={handleZoomOut} className="btn btn-secondary">
          Zoom Out (−)
        </button>
        <button onClick={handleResetZoom} className="btn btn-secondary">
          Reset Zoom
        </button>
        <button onClick={exportToPNG} className="btn btn-secondary">
          Export as PNG
        </button>
        <button onClick={exportToPDF} className="btn btn-secondary">
          Export as PDF
        </button>
      </div>

      <div className="chart-wrapper" ref={chartRef}>
        <div style={{ transform: `scale(${zoomLevel})`, transformOrigin: 'top center', transition: 'transform 0.2s' }}>
          <Plot
            data={traces}
            layout={layout}
            config={config}
            style={{ width: '100%', height: '500px' }}
            useResizeHandler={true}
          />
        </div>
      </div>

      <div className="chart-legend" style={{ marginTop: '20px', padding: '16px', backgroundColor: '#f8f9fa', borderRadius: '6px' }}>
        <h4 style={{ margin: '0 0 12px 0', fontSize: '14px', fontWeight: '600' }}>Box Plot Guide:</h4>
        <ul style={{ margin: 0, paddingLeft: '20px', fontSize: '13px', color: '#666' }}>
          <li>Box shows the interquartile range (P25 to P75)</li>
          <li>Line inside box represents the median</li>
          <li>Whiskers extend to minimum and maximum values</li>
          <li>Hover over boxes to see detailed statistics</li>
        </ul>
      </div>
    </div>
  );
}

export default BoxPlotChart;

