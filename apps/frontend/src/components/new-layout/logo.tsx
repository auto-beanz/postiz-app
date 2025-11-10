'use client';

import Image from 'next/image';

export const Logo = () => {
  return (
    <Image
      src="/logo.png"
      alt="Logo"
      width={714}
      height={300}
      unoptimized
    />
  );
};
