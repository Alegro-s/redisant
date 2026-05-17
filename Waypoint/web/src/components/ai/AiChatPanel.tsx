import React, { useCallback, useEffect, useState } from 'react';
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Stack,
  TextField,
  Typography,
  CircularProgress,
  alpha,
  useTheme,
} from '@mui/material';
import { Send, AutoAwesome } from '@mui/icons-material';
import { deepseekChat, type ChatMessage } from '../../services/waypoint-chat.service';
import { WAYPOINT_LYNX_ASSISTANT_SYSTEM } from '../../waypoint/assistantSystemPrompt';
import { WAYPOINT_DEVELOPER_COPILOT_SYSTEM } from '../../waypoint/developerCopilotPrompt';
import { useNotification } from '../../app/hooks/useNotification';
import { WM_CLOUD } from '../layout/cloudShell';
import { fetchAiQuota } from '../../services/cabinet.service';

export type AiChatPersona = 'business' | 'developer';

export interface AiChatPanelProps {
  persona: AiChatPersona;
  title: string;
  subtitle: string;
  starters: string[];
  inputPlaceholder: string;
}

export const AiChatPanel: React.FC<AiChatPanelProps> = ({
  persona,
  title,
  subtitle,
  starters,
  inputPlaceholder,
}) => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const { showError } = useNotification();
  const system =
    persona === 'developer' ? WAYPOINT_DEVELOPER_COPILOT_SYSTEM : WAYPOINT_LYNX_ASSISTANT_SYSTEM;

  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([{ role: 'system', content: system }]);
  const [quotaUsed, setQuotaUsed] = useState(0);
  const [quotaLimit, setQuotaLimit] = useState(0);
  const [quotaDate, setQuotaDate] = useState<string>('');

  const refreshQuota = useCallback(async () => {
    try {
      const q = await fetchAiQuota();
      const slot = persona === 'developer' ? q.developer : q.business;
      setQuotaUsed(slot.used);
      setQuotaLimit(slot.limit);
      setQuotaDate(q.utc_date);
    } catch {
      setQuotaUsed(0);
      setQuotaLimit(0);
    }
  }, [persona]);

  useEffect(() => {
    void refreshQuota();
  }, [refreshQuota]);

  const send = useCallback(async () => {
    const t = input.trim();
    if (!t || loading) return;
    const nextUser: ChatMessage = { role: 'user', content: t };
    const toSend = [...messages, nextUser];
    setMessages(toSend);
    setInput('');
    setLoading(true);
    try {
      const data = await deepseekChat(toSend, { persona });
      let text: string;
      if (typeof data === 'string') {
        text = data;
      } else if (data && typeof data === 'object') {
        const o = data as {
          choices?: Array<{ message?: { content?: string } }>;
        };
        const c = o.choices?.[0]?.message?.content;
        text = typeof c === 'string' && c.trim() ? c : JSON.stringify(data, null, 2);
      } else {
        text = String(data);
      }
      setMessages((m) => [...m, { role: 'assistant', content: text }]);
      void refreshQuota();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : '';
      if (msg.includes('лимит') || msg.includes('лимит AI')) {
        showError(msg);
      } else if (msg) {
        showError(msg);
      } else {
        showError('Запрос к AI не удался. Проверьте DEEPSEEK_API_KEY на сервере.');
      }
      setMessages((m) => m.slice(0, -1));
    } finally {
      setLoading(false);
    }
  }, [input, loading, messages, persona, refreshQuota, showError]);

  const transcript = messages.filter((m) => m.role !== 'system');
  const atLimit = quotaLimit > 0 && quotaUsed >= quotaLimit;

  return (
    <Stack spacing={2}>
      <Card
        sx={{
          borderRadius: 3,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.4) : alpha(theme.palette.primary.main, 0.03),
        }}
      >
        <CardContent sx={{ p: 2.5 }}>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1, flexWrap: 'wrap' }}>
            <AutoAwesome sx={{ color: WM_CLOUD.accent }} />
            <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
              {title}
            </Typography>
            <Chip label={persona === 'developer' ? 'DeepSeek Coder' : 'DeepSeek Chat'} size="small" variant="outlined" />
            <Chip
              label={
                quotaLimit > 0
                  ? `Сообщений (UTC ${quotaDate}): ${quotaUsed}/${quotaLimit}`
                  : 'Квота: загрузка…'
              }
              size="small"
              color={atLimit ? 'warning' : 'default'}
              variant="outlined"
            />
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.6 }}>
            {subtitle} Лимит считает сервер по плану биллинга (UTC).
          </Typography>
        </CardContent>
      </Card>

      <Typography variant="caption" color="text.secondary">
        Быстрый старт:
      </Typography>
      <Stack direction="row" flexWrap="wrap" gap={1}>
        {starters.map((s) => (
          <Chip
            key={s}
            label={s.length > 72 ? `${s.slice(0, 70)}…` : s}
            onClick={() => setInput(s)}
            variant="outlined"
            sx={{ maxWidth: '100%', height: 'auto', py: 0.5, '& .MuiChip-label': { whiteSpace: 'normal' } }}
          />
        ))}
      </Stack>

      <Box
        sx={{
          borderRadius: 2,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          minHeight: 280,
          maxHeight: { xs: 360, sm: 420 },
          overflow: 'auto',
          p: 2,
          bgcolor: isDark ? alpha(WM_CLOUD.canvas, 0.35) : theme.palette.background.default,
        }}
      >
        {transcript.length === 0 && (
          <Typography color="text.secondary" variant="body2">
            {persona === 'developer'
              ? 'Опишите задачу по коду, архитектуре или алгоритмам.'
              : 'Опишите бизнес-задачу: метрики, логистика, отчёты, документы.'}
          </Typography>
        )}
        {transcript.map((m, i) => (
          <Box
            key={`${m.role}-${i}`}
            sx={{
              mb: 1.5,
              pl: m.role === 'user' ? 0 : 1,
              borderLeft: m.role === 'assistant' ? `3px solid ${WM_CLOUD.accent}` : 'none',
            }}
          >
            <Typography variant="caption" color="primary" sx={{ fontWeight: 700 }}>
              {m.role === 'user' ? 'Вы' : 'Ассистент'}
            </Typography>
            <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', mt: 0.25, wordBreak: 'break-word' }}>
              {m.content}
            </Typography>
          </Box>
        ))}
        {loading && (
          <Stack direction="row" alignItems="center" spacing={1} sx={{ py: 1 }}>
            <CircularProgress size={18} />
            <Typography variant="body2" color="text.secondary">
              Думаю…
            </Typography>
          </Stack>
        )}
      </Box>

      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
        <TextField
          fullWidth
          multiline
          minRows={2}
          placeholder={inputPlaceholder}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              void send();
            }
          }}
        />
        <Button
          variant="contained"
          sx={{ minWidth: 120, alignSelf: { sm: 'stretch' }, height: { sm: 'auto' } }}
          onClick={() => void send()}
          disabled={loading || !input.trim() || atLimit}
          startIcon={<Send />}
        >
          Отправить
        </Button>
      </Stack>
    </Stack>
  );
};
