import {call} from './bridge';
import type {MediaAsset} from '../../../packages/contracts/bridge';
import {normalizedMime} from './mediaTypes';

export const MAX_MEDIA_BYTES = 80 * 1024 * 1024;
export const MEDIA_CHUNK_BYTES = 256 * 1024;

function arrayBufferBase64(bytes: Uint8Array) {
  let binary = '';
  const stride = 0x8000;
  for (let offset=0; offset<bytes.length; offset+=stride) binary += String.fromCharCode(...bytes.subarray(offset,offset+stride));
  return btoa(binary);
}

export async function jpegPreview(file: File): Promise<string> {
  if (!normalizedMime(file).startsWith('image/') || !('createImageBitmap' in window)) return '';
  let bitmap: ImageBitmap | undefined;
  try {
    bitmap = await createImageBitmap(file);
    const scale = Math.min(1,480/Math.max(bitmap.width,bitmap.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1,Math.round(bitmap.width*scale));
    canvas.height = Math.max(1,Math.round(bitmap.height*scale));
    const context = canvas.getContext('2d');
    if (!context) return '';
    context.drawImage(bitmap,0,0,canvas.width,canvas.height);
    for (const quality of [0.65,0.45,0.3]) {
      const data = canvas.toDataURL('image/jpeg',quality).split(',')[1] || '';
      if (data.length <= 250_000) return data;
    }
    return '';
  } catch { return ''; }
  finally { bitmap?.close(); }
}

export async function saveMediaFile(file: File, day: string, progress: (value:string)=>void, signal?:AbortSignal): Promise<MediaAsset> {
  if (!file.size || file.size > MAX_MEDIA_BYTES) throw new Error('Choose a media file between 1 byte and 80 MB.');
  const mimeType = normalizedMime(file);
  if (!mimeType.startsWith('image/')&&!mimeType.startsWith('audio/')&&!mimeType.startsWith('video/')) throw new Error('Choose a photo, audio or video file.');
  const previewBase64 = await jpegPreview(file);
  const id = crypto.randomUUID();
  const {uploadId} = await call('media.begin',{id,day,filename:file.name || 'Memory media',mimeType,byteCount:file.size,previewBase64});
  try {
    let offset=0, chunkIndex=0;
    while (offset<file.size) {
      if(signal?.aborted)throw new DOMException('Upload cancelled.','AbortError');
      const bytes = new Uint8Array(await file.slice(offset,Math.min(offset+MEDIA_CHUNK_BYTES,file.size)).arrayBuffer());
      const data = arrayBufferBase64(bytes);
      const response = await call('media.append',{uploadId,chunkIndex,data});
      offset = response.receivedBytes;
      chunkIndex++;
      progress(`Saving ${file.name || 'media'} · ${Math.floor(offset/file.size*100)}%`);
    }
    return await call('media.finish',{uploadId});
  } catch (error) {
    await call('media.cancel',{uploadId}).catch(()=>undefined);
    throw error;
  }
}

export async function loadMediaBlob(asset: MediaAsset, progress: (value:string)=>void): Promise<Blob> {
  const parts: BlobPart[]=[];
  let offset=0;
  while(offset<asset.byteCount){
    const result=await call('media.read',{id:asset.id,offset,length:MEDIA_CHUNK_BYTES});
    if(result.offset!==offset||result.nextOffset<=offset)throw new Error('The saved media could not be read completely.');
    const binary=atob(result.data), bytes=new Uint8Array(binary.length);
    for(let i=0;i<binary.length;i++)bytes[i]=binary.charCodeAt(i);
    const buffer=new ArrayBuffer(bytes.byteLength);new Uint8Array(buffer).set(bytes);parts.push(buffer);offset=result.nextOffset;
    progress(`Loading ${asset.filename} · ${Math.floor(offset/asset.byteCount*100)}%`);
    if(result.done)break;
  }
  if(offset!==asset.byteCount)throw new Error('The saved media is incomplete.');
  return new Blob(parts,{type:asset.mimeType});
}
