import React from 'react';

export type IconName =
  | "book"
  | "search"
  | "plus"
  | "calendar"
  | "settings"
  | "chevron-left"
  | "chevron-right"
  | "edit"
  | "mic"
  | "video"
  | "upload"
  | "text"
  | "play"
  | "cloud-rain"
  | "cloud"
  | "sun"
  | "snowflake"
  | "more"
  | "x"
  | "image"
  | "sparkles"
  | "share"
  | "layers";

const paths: Record<IconName, React.ReactNode> = {
  book: (
    <>
      <path d="M3.5 5.5A3.5 3.5 0 0 1 7 2h4v18H7a3.5 3.5 0 0 0-3.5 3.5z" />
      <path d="M20.5 5.5A3.5 3.5 0 0 0 17 2h-4v18h4a3.5 3.5 0 0 1 3.5 3.5z" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="7.5" />
      <path d="m16.5 16.5 5 5" />
    </>
  ),
  plus: (
    <>
      <path d="M12 5v14M5 12h14" />
    </>
  ),
  calendar: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M7 3v4M17 3v4M3 10h18" />
    </>
  ),
  settings: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.8 1.8 0 0 0 .36 1.98l.06.06-2.78 2.78-.06-.06A1.8 1.8 0 0 0 15 19.4a1.8 1.8 0 0 0-1.1 1.64V21h-3.8v-.08A1.8 1.8 0 0 0 9 19.3a1.8 1.8 0 0 0-1.98.36l-.06.06-2.78-2.78.06-.06A1.8 1.8 0 0 0 4.6 15a1.8 1.8 0 0 0-1.64-1.1H3v-3.8h.08A1.8 1.8 0 0 0 4.7 9a1.8 1.8 0 0 0-.36-1.98l-.06-.06 2.78-2.78.06.06A1.8 1.8 0 0 0 9 4.6a1.8 1.8 0 0 0 1.1-1.64V3h3.8v.08A1.8 1.8 0 0 0 15 4.7a1.8 1.8 0 0 0 1.98-.36l.06-.06 2.78 2.78-.06.06A1.8 1.8 0 0 0 19.4 9a1.8 1.8 0 0 0 1.64 1.1H21v3.8h-.08A1.8 1.8 0 0 0 19.4 15Z" />
    </>
  ),
  "chevron-left": <path d="m15 18-6-6 6-6" />,
  "chevron-right": <path d="m9 18 6-6-6-6" />,
  edit: (
    <>
      <path d="m14 5 5 5L9 20H4v-5z" />
      <path d="m13 6 5 5" />
    </>
  ),
  mic: (
    <>
      <rect x="9" y="3" width="6" height="12" rx="3" />
      <path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V22M9 22h6" />
    </>
  ),
  video: (
    <>
      <rect x="3" y="6" width="13" height="12" rx="2" />
      <path d="m16 10 5-3v10l-5-3z" />
    </>
  ),
  upload: (
    <>
      <path d="M12 16V4M7 9l5-5 5 5" />
      <path d="M4 15v5h16v-5" />
    </>
  ),
  text: (
    <>
      <path d="M5 5h14M12 5v14M8 19h8" />
    </>
  ),
  play: <path d="m9 6 10 6-10 6z" />,
  cloud: (<>
    <path d="M7 18h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.2 9.2 4.5 4.5 0 0 0 7 18Z" />
  </>),
  sun: (<>
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v2m0 16v2M4.93 4.93l1.42 1.42m11.3 11.3 1.42 1.42M2 12h2m16 0h2M4.93 19.07l1.42-1.42m11.3-11.3 1.42-1.42" />
  </>),
  snowflake: (<>
    <path d="M12 2v20M4 7l16 10M4 17 20 7" />
    <path d="m9 4 3-2 3 2m-6 16 3 2 3-2M4 10 4 7l3-1m10 12 3-1v-3M4 14v3l3 1m10-12 3 1v3" />
  </>),
  "cloud-rain": (
    <>
      <path d="M7 17h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.2 8.2 4.5 4.5 0 0 0 7 17Z" />
      <path d="m8 20-1 2m5-2-1 2m5-2-1 2" />
    </>
  ),
  more: (
    <>
      <circle cx="5" cy="12" r="1" />
      <circle cx="12" cy="12" r="1" />
      <circle cx="19" cy="12" r="1" />
    </>
  ),
  x: <path d="M6 6l12 12M18 6 6 18" />,
  image: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <circle cx="8.5" cy="9" r="1.5" />
      <path d="m4 17 5-5 4 4 2-2 5 4" />
    </>
  ),
  sparkles: (
    <>
      <path d="m12 3 1.1 3.4L16.5 8l-3.4 1.1L12 12.5l-1.1-3.4L7.5 8l3.4-1.6zM18 14l.7 2.3L21 17l-2.3.7L18 20l-.7-2.3L15 17l2.3-.7zM6 14l.6 1.9 1.9.6-1.9.6L6 19l-.6-1.9-1.9-.6 1.9-.6z" />
    </>
  ),
  share: (
    <>
      <circle cx="18" cy="5" r="2.5" />
      <circle cx="6" cy="12" r="2.5" />
      <circle cx="18" cy="19" r="2.5" />
      <path d="m8.3 10.8 7.4-4.5M8.3 13.2l7.4 4.5" />
    </>
  ),
  layers: (
    <>
      <path d="m12 3 9 5-9 5-9-5z" />
      <path d="m3 12 9 5 9-5M3 16l9 5 9-5" />
    </>
  ),
};

export function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  return (
    <svg
      aria-hidden="true"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {paths[name]}
    </svg>
  );
}

