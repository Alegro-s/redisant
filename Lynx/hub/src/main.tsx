import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { App } from './App';
import { HubAuthProvider } from './context/HubAuthContext';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <HubAuthProvider>
        <App />
      </HubAuthProvider>
    </BrowserRouter>
  </React.StrictMode>
);
