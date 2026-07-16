import { useContext } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { AuthContext } from '../context/AuthContext';

export default function Layout() {
  const { user, logout } = useContext(AuthContext);
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div>
      <nav className="sidebar">
        <h2>Guard Tracker</h2>
        <NavLink to="/" end>Dashboard</NavLink>
        <NavLink to="/users">Users</NavLink>
        <NavLink to="/live">Live Tracking</NavLink>
      </nav>
      <div className="main-content">
        <div className="topbar">
          <h1>Admin Panel</h1>
          <div className="topbar-right">
            <span className="text-sm text-muted">{user?.display_name}</span>
            <button className="btn btn-secondary btn-sm" onClick={handleLogout}>Logout</button>
          </div>
        </div>
        <Outlet />
      </div>
    </div>
  );
}
