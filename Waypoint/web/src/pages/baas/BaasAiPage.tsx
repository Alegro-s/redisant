import React from 'react';
import { Button, Stack, TextField, Typography } from '@mui/material';
import { useBaasConsole } from './BaasConsoleContext';

export const BaasAiPage: React.FC = () => {
  const { chatIn, setChatIn, chatOut, onChat } = useBaasConsole();

  return (
    <Stack spacing={2}>
      <Typography variant="h6">AI (DeepSeek через Waypoint)</Typography>
      <TextField label="Сообщение" value={chatIn} onChange={(e) => setChatIn(e.target.value)} multiline minRows={3} fullWidth />
      <Button variant="contained" onClick={() => void onChat()}>
        Отправить
      </Button>
      <TextField label="Ответ" value={chatOut} multiline minRows={8} fullWidth InputProps={{ readOnly: true }} />
    </Stack>
  );
};
