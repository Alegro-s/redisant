import React from 'react';
import { Button, MenuItem, Stack, TextField, Typography } from '@mui/material';
import { useBaasConsole } from './BaasConsoleContext';

export const BaasStoragePage: React.FC = () => {
  const {
    activeEnvironment,
    buckets,
    newBucket,
    setNewBucket,
    uploadBucket,
    setUploadBucket,
    objectKey,
    setObjectKey,
    onCreateBucket,
    onUpload,
    onDownload,
  } = useBaasConsole();

  return (
    <Stack spacing={2}>
      <Typography variant="h6">S3-совместимое хранилище</Typography>
      {activeEnvironment ? (
        <Typography variant="body2" color="text.secondary">
          Buckets и объекты изолированы в подпроекте «{activeEnvironment.name}». Другой подпроект — отдельный набор
          bucket’ов с теми же именами.
        </Typography>
      ) : null}
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
        <TextField label="Новый bucket" value={newBucket} onChange={(e) => setNewBucket(e.target.value)} />
        <Button variant="outlined" onClick={() => void onCreateBucket()}>
          Создать bucket
        </Button>
      </Stack>

      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
        <TextField select label="Bucket" value={uploadBucket} onChange={(e) => setUploadBucket(e.target.value)} sx={{ minWidth: 220 }}>
          {buckets.map((b) => (
            <MenuItem key={b.id} value={b.name}>
              {b.name}
            </MenuItem>
          ))}
        </TextField>
        <TextField label="Object key" value={objectKey} onChange={(e) => setObjectKey(e.target.value)} sx={{ minWidth: 240 }} />
        <Button variant="contained" component="label">
          Загрузить файл
          <input hidden type="file" onChange={(e) => void onUpload(e)} />
        </Button>
        <Button variant="outlined" onClick={() => void onDownload()}>
          Скачать
        </Button>
      </Stack>
    </Stack>
  );
};
