import axios from 'axios';

// In production (Docker), use relative path through nginx proxy
// In development, use direct API URL
const API_BASE_URL = process.env.NODE_ENV === 'production' 
  ? '' 
  : (process.env.REACT_APP_API_URL || 'http://localhost:8000');

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token to requests if available
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Auth API
export const authAPI = {
  signup: (data) => api.post('/api/auth/signup', data),
  login: (data) => api.post('/api/auth/login', data),
  resetPassword: (data) => api.post('/api/auth/reset-password', data),
};

// Disease API
export const diseaseAPI = {
  getAvailable: () => api.get('/api/diseases'),
};

// Cohort API
export const cohortAPI = {
  build: (diseaseConceptId) => api.post('/api/cohorts/build', { disease_concept_id: diseaseConceptId }),
};

// Measurement API
export const measurementAPI = {
  getAvailable: () => api.get('/api/measurements/available'),
  getSummary: (diseaseConceptId, measurementConceptId) => 
    api.post('/api/measurements/summary', { 
      disease_concept_id: diseaseConceptId,
      measurement_concept_id: measurementConceptId 
    }),
  getByAgeSex: (diseaseConceptId, measurementConceptId) =>
    api.post('/api/measurements/by-age-sex', {
      disease_concept_id: diseaseConceptId,
      measurement_concept_id: measurementConceptId
    }),
};

// Demographics API
export const demographicsAPI = {
  get: () => api.get('/api/demographics'),
};

export default api;

