import {call} from './bridge.ts';
import type {MediaAsset, VisualJob} from '../../../packages/contracts/bridge';

export async function analyzeVisualMemory(
  asset: MediaAsset,
  progress: (message: string) => void,
  signal?: AbortSignal,
): Promise<VisualJob> {
  if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError');
  const job = await call('visual.start', {id: asset.id});
  const cancel = () => { void call('visual.cancel', {id: job.id}).catch(() => undefined); };
  signal?.addEventListener('abort', cancel, {once: true});
  if (signal?.aborted) cancel();
  try {
    let state = job;
    const deadline = Date.now() + 5 * 60 * 1000;
    while (state.state === 'running') {
      progress(state.message);
      if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError');
      if (Date.now() > deadline) {
        cancel();
        throw new Error('Visual analysis timed out. The original media is saved; retry when ready.');
      }
      await new Promise(resolve => setTimeout(resolve, 700));
      state = await call('visual.status', {id: job.id});
    }
    if (state.state !== 'complete') throw new Error(state.message);
    return state;
  } catch (error) {
    cancel();
    throw error;
  } finally {
    signal?.removeEventListener('abort', cancel);
  }
}
