import axios from 'axios';
import { resolveAuthBase } from '../utils/authBase';

const authApi = axios.create({
  baseURL: resolveAuthBase(),
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
    'X-Client-Realm': 'metric',
  },
});

export default authApi;
