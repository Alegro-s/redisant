import React from 'react';
import {
  Box,
  Button,
  MenuItem,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { useBaasConsole } from './BaasConsoleContext';

export const BaasRestPage: React.FC = () => {
  const {
    tables,
    restTable,
    setRestTable,
    restRows,
    restJson,
    setRestJson,
    onLoadRest,
    onInsertRest,
    onDeleteRow,
  } = useBaasConsole();

  return (
    <Stack spacing={2}>
      <Typography variant="h6">REST (jsonb rows)</Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
        <TextField select label="Таблица" value={restTable} onChange={(e) => setRestTable(e.target.value)} sx={{ minWidth: 220 }}>
          {tables.map((t) => (
            <MenuItem key={t} value={t}>
              {t}
            </MenuItem>
          ))}
        </TextField>
        <Button variant="outlined" onClick={() => void onLoadRest()}>
          Загрузить строки
        </Button>
      </Stack>

      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>id</TableCell>
            <TableCell>data</TableCell>
            <TableCell width={120} />
          </TableRow>
        </TableHead>
        <TableBody>
          {restRows.map((r) => (
            <TableRow key={String(r.id)}>
              <TableCell>{String(r.id)}</TableCell>
              <TableCell>
                <pre style={{ margin: 0, whiteSpace: 'pre-wrap' }}>{JSON.stringify(r.data, null, 2)}</pre>
              </TableCell>
              <TableCell>
                <Button size="small" color="error" onClick={() => void onDeleteRow(String(r.id))}>
                  Удалить
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>

      <Typography variant="subtitle1">Вставить JSON</Typography>
      <TextField value={restJson} onChange={(e) => setRestJson(e.target.value)} multiline minRows={4} fullWidth />
      <Button variant="contained" onClick={() => void onInsertRest()}>
        INSERT
      </Button>
      <Box sx={{ typography: 'caption', color: 'text.secondary' }}>
        Требует WM_BAAS_REST_WRITE=1 на сервере для insert/delete.
      </Box>
    </Stack>
  );
};
