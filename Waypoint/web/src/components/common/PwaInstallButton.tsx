import React from 'react';
import { Button, type ButtonProps, Dialog, DialogTitle, DialogContent, DialogActions, Typography } from '@mui/material';
import { DownloadForOffline } from '@mui/icons-material';
import { useSnackbar } from 'notistack';

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>;
};

const INSTALL_HINT =
  'Браузер не предложил установку автоматически. Откройте подсказку и установите вручную.';

export const PwaInstallButton: React.FC<ButtonProps> = ({
  variant = 'outlined',
  size = 'small',
  sx,
  children,
  onClick,
  ...rest
}) => {
  const [promptEvent, setPromptEvent] = React.useState<BeforeInstallPromptEvent | null>(null);
  const [helpOpen, setHelpOpen] = React.useState(false);
  const { enqueueSnackbar } = useSnackbar();

  const androidNativeUrl = (import.meta.env.VITE_ANDROID_APP_URL as string | undefined)?.trim();
  const iosNativeUrl = (import.meta.env.VITE_IOS_APP_URL as string | undefined)?.trim();

  React.useEffect(() => {
    const onBeforeInstallPrompt = (event: Event) => {
      event.preventDefault();
      setPromptEvent(event as BeforeInstallPromptEvent);
    };

    const onInstalled = () => {
      setPromptEvent(null);
      enqueueSnackbar('Приложение установлено.', { variant: 'success' });
    };

    window.addEventListener('beforeinstallprompt', onBeforeInstallPrompt as EventListener);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.removeEventListener('beforeinstallprompt', onBeforeInstallPrompt as EventListener);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, [enqueueSnackbar]);

  const handleClick = async (e: React.MouseEvent<HTMLButtonElement>) => {
    onClick?.(e);
    if (window.matchMedia('(display-mode: standalone)').matches) {
      enqueueSnackbar('Приложение уже установлено на устройстве.', { variant: 'success' });
      return;
    }
    if (promptEvent) {
      await promptEvent.prompt();
      await promptEvent.userChoice;
      setPromptEvent(null);
      return;
    }
    enqueueSnackbar(INSTALL_HINT, { variant: 'info', autoHideDuration: 9000 });
    setHelpOpen(true);
  };

  return (
    <>
      <Button
        variant={variant}
        size={size}
        startIcon={<DownloadForOffline fontSize={size === 'small' ? 'small' : 'medium'} />}
        onClick={(e) => void handleClick(e)}
        sx={sx}
        {...rest}
      >
        {children ?? 'Установить'}
      </Button>
      <Dialog open={helpOpen} onClose={() => setHelpOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Как установить приложение</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            Android / Chrome: меню браузера (⋮) → «Установить приложение» или «Добавить на главный экран».
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1.2 }}>
            iPhone / Safari: кнопка «Поделиться» → «На экран Домой».
          </Typography>
          {!androidNativeUrl && !iosNativeUrl && (
            <Typography variant="caption" color="text.secondary" sx={{ mt: 1.4, display: 'block' }}>
              Нативные ссылки не заданы. При необходимости добавьте `VITE_ANDROID_APP_URL` и `VITE_IOS_APP_URL`.
            </Typography>
          )}
        </DialogContent>
        <DialogActions>
          {androidNativeUrl && (
            <Button component="a" href={androidNativeUrl} target="_blank" rel="noreferrer" variant="outlined">
              Android (нативно)
            </Button>
          )}
          {iosNativeUrl && (
            <Button component="a" href={iosNativeUrl} target="_blank" rel="noreferrer" variant="outlined">
              iOS (нативно)
            </Button>
          )}
          <Button onClick={() => setHelpOpen(false)} variant="contained">
            Понятно
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
};

