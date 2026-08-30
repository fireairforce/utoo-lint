import React, { type AnchorHTMLAttributes, type MouseEvent } from 'react';

interface NativeLinkProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  href: string;
}

export default function NativeLink({
  href,
  onClick,
  target,
  ...props
}: NativeLinkProps) {
  const navigate = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event);
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey ||
      (target && target !== '_self')
    ) {
      return;
    }

    event.preventDefault();
    window.location.assign(href);
  };

  return <a {...props} href={href} onClick={navigate} target={target} />;
}
