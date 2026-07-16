import { useContext } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { AuthContext } from '../context/AuthContext';

export default function Layout() {
  const { user, logout } = useContext(AuthContext);
  const navigate = useNavigate();

  const handleLogout = () => { logout(); navigate('/login'); };

  return (
    <div>
      <nav className="sidebar">
        <div className="sidebar-brand">
          <h2>⛯ Checkpoints</h2>
          <span>Tracker Admin</span>
        </div>
        <div className="sidebar-nav">
          <NavLink to="/" end>
            <span className="sidebar-icon">◆</span> Dashboard
          </NavLink>
          <NavLink to="/users">
            <span className="sidebar-icon">●</span> Users
          </NavLink>
          <NavLink to="/live">
            <span className="sidebar-icon">◉</span> Live Tracking
          </NavLink>
        </div>
        <div className="sidebar-footer">
          {user?.display_name} · {user?.role}
        </div>
      </nav>
      <div className="main-content">
        <div className="topbar">
          <h1>{user?.display_name}</h1>
          <div className="topbar-right">
            <span className="text-sm text-muted">{user?.display_name}</span>
            <button className="btn btn-secondary btn-sm" onClick={handleLogout}>Logout</button>
          </div>
        </div>
        <div className="page-content">
          <Outlet />
        </div>
      </div>
    </div>
  );
}
