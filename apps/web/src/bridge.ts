import { VERSION, type Methods } from '../../../packages/contracts/bridge.ts';
declare global { interface Window { webkit?: { messageHandlers?: { journal?: { postMessage: (request: unknown) => Promise<unknown> } } } } }
export const isNative = () => Boolean(window.webkit?.messageHandlers?.journal);
export async function call<K extends keyof Methods>(method: K, params: Methods[K]['params']): Promise<Methods[K]['result']> {
  const native = window.webkit?.messageHandlers?.journal;
  if (!native) {
    if (method === 'system.capabilities') return { storage: 'browser-preview', contractVersion: VERSION, media: false, photos: false, calendar: false, weather: false, ai: false, crossDeviceSync: {provider:'CloudKit',state:'not-configured',message:'CloudKit sync is available only in a provisioned native app.'}, message: 'Browser preview only. Open the native app to save memories.' } as Methods[K]['result'];
    if (method === 'journal.listDays' || method === 'journal.getDay') return [] as unknown as Methods[K]['result'];
    if (method === 'draft.get') return { body: '' } as Methods[K]['result'];
    if (method === 'backup.status') return {available:false,restoredReady:false} as Methods[K]['result'];
    if (method === 'resources.status') return {photos:{enabled:false,access:'unavailable'},calendar:{enabled:false,access:'unavailable'}} as Methods[K]['result'];
    if (method === 'resources.day') return {photos:[],photoCount:0,events:[],photosAccess:'unavailable',calendarAccess:'unavailable',weatherHidden:false} as unknown as Methods[K]['result'];
    if (method === 'media.list') return [] as unknown as Methods[K]['result'];
    if (method === 'search.query') return {hits:[],semanticAvailable:false} as Methods[K]['result'];
    throw new Error('Saving requires the native Memory Catcher 3 app.');
  }
  const requestId = crypto.randomUUID();
  let timer: ReturnType<typeof setTimeout>;
  const deadline = method === 'backup.export' || method === 'backup.restore' || method === 'backup.openFolder' ? 3600000
    : method === 'dictation.start' ? 120000
    : (method === 'resources.sync' || method === 'resources.syncBatch') ? 300000
    : method === 'resources.day' ? 120000
    : 15000;
  const operation = method === 'resources.sync' ? 'Photos and calendar sync'
    : method === 'resources.day' ? 'Photos and calendar day load'
    : method === 'dictation.start' ? 'Dictation startup'
    : method;
  const timeout = new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error(operation + ' is taking longer than expected. It may still finish; check the current screen before retrying.')), deadline); });
  try {
    const raw = await Promise.race([native.postMessage({version: VERSION, requestId, method, params}), timeout]);
    if (!raw || typeof raw !== 'object') throw new Error('Invalid native response.');
    const result = raw as { version?: number; requestId?: string; result?: unknown; error?: {message?: string} };
    if (result.version !== VERSION || result.requestId !== requestId) throw new Error('Native interface version or request mismatch.');
    if (result.error) throw new Error(result.error.message || 'Native operation failed.');
    if (!('result' in result)) throw new Error('Native response is incomplete.');
    return result.result as Methods[K]['result'];
  } finally { clearTimeout(timer!); }
}
