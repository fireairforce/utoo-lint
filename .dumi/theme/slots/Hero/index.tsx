import { Link, useLocale, useRouteMeta } from 'dumi';
import HeroTitle from 'dumi/theme/slots/HeroTitle';
import React from 'react';
import NativeLink from '../../components/NativeLink';
import WebGPULogo from '../../components/WebGPULogo';

interface HeroAction {
  text: string;
  link: string;
}

interface HeroData {
  title?: string;
  description?: string;
  actions?: HeroAction[];
}

const heroMessages = {
  'en-US': {
    eyebrow: 'High-performance JavaScript / TypeScript linter',
    gpuLabel: 'utoo rabbit mark',
  },
  'zh-CN': {
    eyebrow: '高性能 JavaScript / TypeScript Linter',
    gpuLabel: 'utoo 兔子标志',
  },
} as const;

export default function Hero() {
  const { frontmatter } = useRouteMeta();
  const locale = useLocale();
  const messages =
    heroMessages[locale.id as keyof typeof heroMessages] ??
    heroMessages['en-US'];

  if (!('hero' in frontmatter)) {
    return null;
  }

  const hero = frontmatter.hero as HeroData;

  return (
    <div className="dumi-default-hero">
      <div className="utlint-hero-main">
        <div className="utlint-hero-shell">
          <div className="utlint-hero-copy">
            <span className="utlint-hero-eyebrow">{messages.eyebrow}</span>
            {hero.title && <HeroTitle>{hero.title}</HeroTitle>}
            {hero.description && (
              <p dangerouslySetInnerHTML={{ __html: hero.description }} />
            )}
            {Boolean(hero.actions?.length) && (
              <div className="dumi-default-hero-actions">
                {hero.actions?.map(({ text, link }, index) => {
                  const className = [
                    'utlint-hero-action',
                    index === 0 && 'utlint-hero-action--primary',
                  ]
                    .filter(Boolean)
                    .join(' ');

                  if (link.startsWith('/playground/')) {
                    return (
                      <NativeLink className={className} href={link} key={text}>
                        {text}
                      </NativeLink>
                    );
                  }

                  if (/^(\w+:)\/\/|^(mailto|tel):/.test(link)) {
                    return (
                      <a
                        className={className}
                        href={link}
                        key={text}
                        rel="noreferrer"
                        target="_blank"
                      >
                        {text}
                      </a>
                    );
                  }

                  return (
                    <Link className={className} key={text} to={link}>
                      {text}
                    </Link>
                  );
                })}
              </div>
            )}
          </div>

          <div className="utlint-hero-visual">
            <WebGPULogo label={messages.gpuLabel} />
          </div>
        </div>
      </div>
    </div>
  );
}
