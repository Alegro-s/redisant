import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

/** Раньше отдельная «главная бизнеса» с десятком карточек — ведём на рабочий стол. */
export const BusinessHomePage: React.FC = () => {
  const navigate = useNavigate();
  useEffect(() => {
    navigate('/dashboard', { replace: true });
  }, [navigate]);
  return null;
};
