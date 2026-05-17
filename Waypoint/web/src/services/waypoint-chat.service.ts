import api from './api';

export interface ChatMessage {
  role: string;
  content: string;
}

export type AiPersona = 'business' | 'developer';

export type DeepseekChatOptions = {
  model?: string;
  persona?: AiPersona;
};


export async function deepseekChat(
  messages: ChatMessage[],
  modelOrOpts?: string | DeepseekChatOptions,
): Promise<unknown> {
  let model: string | undefined;
  let persona: AiPersona | undefined;
  if (typeof modelOrOpts === 'string') {
    model = modelOrOpts;
  } else if (modelOrOpts && typeof modelOrOpts === 'object') {
    model = modelOrOpts.model;
    persona = modelOrOpts.persona;
  }
  try {
    const { data } = await api.post<unknown>('/me/ai/chat', { messages, model, persona });
    return data;
  } catch (e: unknown) {
    const err = e as { response?: { status?: number; data?: { error?: string; limit?: number; persona?: string } } };
    if (err.response?.status === 429) {
      const msg =
        err.response.data?.error === 'ai_daily_quota_exceeded'
          ? `Дневной лимит AI исчерпан (${err.response.data?.persona ?? persona ?? '—'}: лимит ${err.response.data?.limit ?? '?'})`
          : 'Слишком много запросов к AI';
      throw new Error(msg);
    }
    throw e;
  }
}
