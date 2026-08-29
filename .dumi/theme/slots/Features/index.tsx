import { Link, useRouteMeta } from 'dumi';
import React from 'react';
import 'dumi/theme-default/slots/Features/index.less';

interface Feature {
  description?: string;
  emoji?: string;
  link?: string;
  title?: string;
}

export default function Features() {
  const { frontmatter } = useRouteMeta();
  const features = frontmatter.features as Feature[] | undefined;
  if (!features?.length) return null;

  return (
    <section
      aria-labelledby="utlint-core-capabilities"
      className="dumi-default-features"
      data-cols={[3, 2].find((count) => features.length % count === 0) || 3}
    >
      <h2 className="utlint-sr-only" id="utlint-core-capabilities">
        Core capabilities
      </h2>
      {features.map(({ title, description, emoji, link }) => {
        let linkedTitle: React.ReactNode = title;
        if (link && title) {
          linkedTitle = /^(\w+:)\/\/|^(mailto|tel):/.test(link) ? (
            <a href={link} rel="noreferrer" target="_blank">
              {title}
            </a>
          ) : (
            <Link to={link}>{title}</Link>
          );
        }

        return (
          <div className="dumi-default-features-item" key={title}>
            {emoji && <i aria-hidden="true">{emoji}</i>}
            {title && <h3>{linkedTitle}</h3>}
            {description && (
              <p dangerouslySetInnerHTML={{ __html: description }} />
            )}
          </div>
        );
      })}
    </section>
  );
}
