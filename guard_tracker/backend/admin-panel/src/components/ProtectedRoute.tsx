import { useContext } from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { AuthContext } from '../context/AuthContext';

export default function ProtectedRoute() {
  const { token, isLoading } = useContext(AuthContext);

  if (isLoading) {
    return <div style={{ padding: '2rem', textAlign: 'center' }}>Loading...</div>;
  }

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
}
