import api from './api';

export interface AnalyzeRequest {
  code: string;
  language: string;
  test_mode?: boolean;
}

export interface PerformancePrediction {
  cpu_usage: number;
  memory_usage: number;
  execution_time: number;
  iops: number;
  network_bandwidth?: number;
}

export interface AnalysisResult {
  errors: Array<{ line: number; message: string; severity: string }>;
  warnings: Array<{ message: string; suggestion: string }>;
  suggestions: Array<{ title: string; description: string; impact: string }>;
  performance_prediction: PerformancePrediction;
  security_issues: Array<{ pattern: string; message: string; severity: string }>;
  complexity_score: number;
  maintainability_index: number;
  ai_suggestions: string;
}

class AIService {
  private baseURL: string;

  constructor() {
    this.baseURL = import.meta.env.VITE_AI_SERVICE_URL || 'http://localhost:8001';
  }

  async analyzeCode(request: AnalyzeRequest): Promise<AnalysisResult> {
    const response = await fetch(`${this.baseURL}/analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error('AI analysis failed');
    }

    return response.json();
  }

  async getSuggestions(context: string): Promise<string> {
    const response = await fetch(`${this.baseURL}/suggest`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ context }),
    });

    if (!response.ok) {
      throw new Error('Failed to get suggestions');
    }

    const data = await response.json();
    return data.suggestions;
  }
}

export const aiService = new AIService();