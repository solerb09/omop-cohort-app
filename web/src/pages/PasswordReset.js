import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { authAPI } from '../api';
import './Auth.css';

function PasswordReset() {
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setLoading(true);

    try {
      const response = await authAPI.resetPassword({ email });
      setMessage(response.data.message);
      setEmail('');
    } catch (err) {
      setError('Failed to send reset email. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <h1>OMOP Cohort Analysis</h1>
        <h2>Reset Password</h2>
        
        <p className="auth-description">
          <strong>Demo Mode:</strong> This is a mock password reset flow for demonstration purposes. 
          In a production app, an email would be sent to reset your password.
        </p>

        {error && <div className="alert alert-error">{error}</div>}
        {message && (
          <div className="alert alert-success">
            <strong>✓ Password reset initiated!</strong><br />
            In a real application, you would receive an email at <strong>{email}</strong> with a reset link.
            <br /><br />
            <em>Note: This is a demo - no actual email was sent.</em>
          </div>
        )}
        
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              placeholder="your.email@example.com"
            />
          </div>

          <button type="submit" className="btn btn-primary" disabled={loading}>
            {loading ? 'Sending...' : 'Send Reset Link'}
          </button>
        </form>

        <div className="auth-links">
          <Link to="/login">Back to Login</Link>
        </div>
      </div>
    </div>
  );
}

export default PasswordReset;

