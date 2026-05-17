import React, { useState } from 'react';
import {
  Box,
  Typography,
  Paper,
  TextField,
  Button,
  MenuItem,
  Alert,
  CircularProgress,
  Card,
  CardContent,
  Grid,
  LinearProgress,
  Chip,
  Divider,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  useTheme,
  alpha,
} from '@mui/material';
import {
  Send as SendIcon,
  ExpandMore as ExpandMoreIcon,
  Warning as WarningIcon,
  Error as ErrorIcon,
  CheckCircle as CheckCircleIcon,
  Speed as SpeedIcon,
  Security as SecurityIcon,
  Code as CodeIcon,
} from '@mui/icons-material';
import { aiService, AnalysisResult } from '../../services/ai.service';
import { useNotification } from '../../app/hooks/useNotification';

export const AIAnalysis: React.FC = () => {
  const [code, setCode] = useState('');
  const [language, setLanguage] = useState('python');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState('');
  const theme = useTheme();
  const { showError } = useNotification();

  const handleAnalyze = async () => {
    if (!code.trim()) {
      setError('Please enter code to analyze');
      return;
    }

    setLoading(true);
    setError('');
    setResult(null);

    try {
      const response = await aiService.analyzeCode({
        code,
        language,
        test_mode: true,
      });
      setResult(response);
    } catch (err: any) {
      setError(err.message || 'Analysis failed');
      showError('Failed to analyze code');
    } finally {
      setLoading(false);
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'error': return theme.palette.error.main;
      case 'high': return theme.palette.error.main;
      case 'warning': return theme.palette.warning.main;
      case 'medium': return theme.palette.warning.main;
      default: return theme.palette.info.main;
    }
  };

  const getComplexityLabel = (score: number) => {
    if (score < 3) return { label: 'Low', color: theme.palette.success.main };
    if (score < 6) return { label: 'Medium', color: theme.palette.warning.main };
    return { label: 'High', color: theme.palette.error.main };
  };

  const complexity = result ? getComplexityLabel(result.complexity_score) : null;

  return (
    <Box>
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
          AI Code Analysis
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Analyze your code for errors, performance issues, and security vulnerabilities
        </Typography>
      </Box>

      <Grid container spacing={3}>
        <Grid item xs={12} lg={6}>
          <Paper sx={{ p: 3, borderRadius: 3 }}>
            <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
              Code Input
            </Typography>
            
            <TextField
              select
              fullWidth
              label="Language"
              value={language}
              onChange={(e) => setLanguage(e.target.value)}
              sx={{ mb: 2 }}
            >
              <MenuItem value="python">Python</MenuItem>
              <MenuItem value="javascript">JavaScript</MenuItem>
              <MenuItem value="typescript">TypeScript</MenuItem>
              <MenuItem value="rust">Rust</MenuItem>
              <MenuItem value="go">Go</MenuItem>
            </TextField>

            <TextField
              fullWidth
              multiline
              rows={12}
              label="Paste your code here"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder={`def example_function():
    print("Hello, World!")
    return True`}
            />

            {error && (
              <Alert severity="error" sx={{ mt: 2 }}>
                {error}
              </Alert>
            )}

            <Button
              variant="contained"
              fullWidth
              onClick={handleAnalyze}
              disabled={loading}
              sx={{ mt: 2, py: 1.5 }}
              endIcon={!loading && <SendIcon />}
            >
              {loading ? <CircularProgress size={24} /> : 'Analyze Code'}
            </Button>
          </Paper>
        </Grid>

        <Grid item xs={12} lg={6}>
          {loading && (
            <Paper sx={{ p: 3, borderRadius: 3, textAlign: 'center' }}>
              <CircularProgress size={48} sx={{ mb: 2 }} />
              <Typography variant="body2" color="text.secondary">
                Analyzing your code with AI...
              </Typography>
              <LinearProgress sx={{ mt: 2 }} />
            </Paper>
          )}

          {result && !loading && (
            <Box>
              {}
              <Paper sx={{ p: 3, borderRadius: 3, mb: 2 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                  <SpeedIcon /> Performance Prediction
                </Typography>
                <Grid container spacing={2}>
                  <Grid item xs={6}>
                    <Typography variant="caption" color="text.secondary">CPU Usage</Typography>
                    <Typography variant="h6">{result.performance_prediction.cpu_usage}%</Typography>
                    <LinearProgress
                      variant="determinate"
                      value={result.performance_prediction.cpu_usage}
                      sx={{ mt: 1, height: 6, borderRadius: 3 }}
                    />
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="caption" color="text.secondary">Memory Usage</Typography>
                    <Typography variant="h6">{result.performance_prediction.memory_usage}%</Typography>
                    <LinearProgress
                      variant="determinate"
                      value={result.performance_prediction.memory_usage}
                      sx={{ mt: 1, height: 6, borderRadius: 3 }}
                    />
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="caption" color="text.secondary">Execution Time</Typography>
                    <Typography variant="h6">{result.performance_prediction.execution_time.toFixed(3)}s</Typography>
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="caption" color="text.secondary">IOPS</Typography>
                    <Typography variant="h6">{result.performance_prediction.iops}</Typography>
                  </Grid>
                </Grid>
              </Paper>

              {}
              <Paper sx={{ p: 3, borderRadius: 3, mb: 2 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
                  Code Metrics
                </Typography>
                <Grid container spacing={2}>
                  <Grid item xs={6}>
                    <Typography variant="caption" color="text.secondary">Cyclomatic Complexity</Typography>
                    <Typography variant="h6" sx={{ color: complexity?.color }}>
                      {result.complexity_score.toFixed(1)} / 10
                    </Typography>
                    <Typography variant="caption" color="text.secondary">{complexity?.label} Complexity</Typography>
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="caption" color="text.secondary">Maintainability Index</Typography>
                    <Typography variant="h6">
                      {result.maintainability_index.toFixed(0)} / 100
                    </Typography>
                  </Grid>
                </Grid>
              </Paper>

              {}
              {result.security_issues.length > 0 && (
                <Paper sx={{ p: 3, borderRadius: 3, mb: 2 }}>
                  <Typography variant="h6" sx={{ fontWeight: 600, mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                    <SecurityIcon /> Security Issues
                  </Typography>
                  {result.security_issues.map((issue, idx) => (
                    <Alert
                      key={idx}
                      severity={issue.severity === 'high' ? 'error' : 'warning'}
                      sx={{ mb: 1 }}
                    >
                      <Typography variant="body2">{issue.message}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        Pattern: {issue.pattern}
                      </Typography>
                    </Alert>
                  ))}
                </Paper>
              )}

              {}
              {result.errors.length > 0 && (
                <Paper sx={{ p: 3, borderRadius: 3, mb: 2 }}>
                  <Typography variant="h6" sx={{ fontWeight: 600, mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                    <ErrorIcon color="error" /> Syntax Errors
                  </Typography>
                  {result.errors.map((error, idx) => (
                    <Alert key={idx} severity="error" sx={{ mb: 1 }}>
                      <Typography variant="body2">Line {error.line}: {error.message}</Typography>
                    </Alert>
                  ))}
                </Paper>
              )}

              {}
              <Paper sx={{ p: 3, borderRadius: 3 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                  <CodeIcon /> AI Suggestions
                </Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                  {result.ai_suggestions}
                </Typography>
              </Paper>
            </Box>
          )}
        </Grid>
      </Grid>
    </Box>
  );
};