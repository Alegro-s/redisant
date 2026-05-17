import React from 'react';
import { Stack, Typography, Card, CardContent, List, ListItem, ListItemText, alpha, useTheme } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { WM_CLOUD } from '../../components/layout/cloudShell';
import { FeatureGate } from '../../components/common/FeatureGate';

export const BusinessLedgerPage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Stack spacing={2.5}>
      <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
        Учёт (лёгкий ERP)
      </Typography>
      <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 800, lineHeight: 1.65 }}>
        Не замена 1С: остатки, контрагенты и проводки вы строите на своих таблицах в PostgreSQL / BaaS. Консоль даёт
        точку входа и сценарии.
      </Typography>

      <Card
        sx={{
          borderRadius: 3,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.35) : theme.palette.background.paper,
        }}
      >
        <CardContent>
          <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 1 }}>
            Рекомендуемые сущности (SQL)
          </Typography>
          <List dense>
            <ListItem>
              <ListItemText primary="counterparties" secondary="Контрагенты, ИНН, адреса" />
            </ListItem>
            <ListItem>
              <ListItemText primary="stock_items / stock_moves" secondary="Номенклатура и движения" />
            </ListItem>
            <ListItem>
              <ListItemText primary="documents" secondary="Шапки документов, ссылки на PDF в storage" />
            </ListItem>
          </List>
          <Typography
            variant="body2"
            color="primary"
            sx={{ cursor: 'pointer', fontWeight: 600, mt: 1 }}
            onClick={() => navigate('/dashboard/database')}
          >
            Открыть SQL-консоль →
          </Typography>
        </CardContent>
      </Card>

      <FeatureGate
        feature="erp_multi_warehouse"
        title="Несколько складов и филиалов"
        description="Распределённые остатки, трансферы между складами, отчёты по точкам."
      >
        <Typography variant="body2" color="text.secondary">
          Режим мультисклада активен на Pro — добавьте колонку warehouse_id в движения и фильтры в дашбордах ingest.
        </Typography>
      </FeatureGate>
    </Stack>
  );
};
