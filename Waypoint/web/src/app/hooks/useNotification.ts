import { useSnackbar } from 'notistack';

export const useNotification = () => {
  const { enqueueSnackbar } = useSnackbar();

  const showSuccess = (message: string) => {
    enqueueSnackbar(message, { variant: 'success', autoHideDuration: 3000 });
  };

  const showError = (message: string) => {
    enqueueSnackbar(message, { variant: 'error', autoHideDuration: 5000 });
  };

  const showWarning = (message: string) => {
    enqueueSnackbar(message, { variant: 'warning', autoHideDuration: 4000 });
  };

  const showInfo = (message: string) => {
    enqueueSnackbar(message, { variant: 'info', autoHideDuration: 3000 });
  };

  return { showSuccess, showError, showWarning, showInfo };
};