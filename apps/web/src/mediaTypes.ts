export function normalizedMime(file: Pick<File,'type'|'name'>) {
  const declared = file.type.toLowerCase().split(';')[0].trim();
  if (declared && declared!=='application/octet-stream') return declared;
  const ext = file.name.toLowerCase().split('.').pop() || '';
  const known: Record<string,string> = {
    jpg:'image/jpeg',jpeg:'image/jpeg',png:'image/png',heic:'image/heic',heif:'image/heif',gif:'image/gif',webp:'image/webp',
    m4a:'audio/mp4',mp3:'audio/mpeg',wav:'audio/wav',aac:'audio/aac',ogg:'audio/ogg',mp4:'video/mp4',mov:'video/quicktime',m4v:'video/x-m4v',webm:'video/webm',
  };
  return known[ext] || '';
}
