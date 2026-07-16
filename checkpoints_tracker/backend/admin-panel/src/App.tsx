import { Navigate } from 'react-router-dom';
import { Routes, Route } from 'react-router-dom';
import ProtectedRoute from './components/ProtectedRoute';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import UsersPage from './pages/UsersPage';
import UserFormPage from './pages/UserFormPage';
import UserCheckpointsPage from './pages/UserCheckpointsPage';
import LiveTrackingPage from './pages/LiveTrackingPage';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<ProtectedRoute />}>
        <Route element={<Layout />}>
          <Route index element={<Navigate to="/users" replace />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="users/new" element={<UserFormPage />} />
          <Route path="users/:id/edit" element={<UserFormPage />} />
          <Route path="users/:userId/checkpoints" element={<UserCheckpointsPage />} />
          <Route path="live" element={<LiveTrackingPage />} />
        </Route>
      </Route>
    </Routes>
  );
}
