import { enqueueSnackbar } from 'notistack';


export function toastApiError(err: unknown, fallback: string): string {
  let message = fallback;
  const ax = err as {
    code?: string;
    message?: string;
    response?: { data?: { error?: string } };
  };
  if (ax.response?.data?.error) {
    message = String(ax.response.data.error);
  } else if (ax.code === 'ERR_NETWORK' || ax.message === 'Network Error') {
    message =
      'Нет связи с сервером. Откройте сайт по домену или IP сервера, а не через файл или localhost.';
  } else if (typeof ax.message === 'string' && ax.message.length > 0) {
    message = ax.message;
  }
  enqueueSnackbar(message, { variant: 'error', autoHideDuration: 10_000 });
  return message;
}
