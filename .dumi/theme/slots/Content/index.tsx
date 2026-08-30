import { useRouteMeta, useSidebarData, useSiteData } from 'dumi';
import React, { type ReactNode } from 'react';
import 'dumi/theme-default/slots/Content/index.less';
import 'dumi/theme-default/styles/heti.less';

export default function Content({ children }: { children?: ReactNode }) {
  const sidebar = useSidebarData();
  const { themeConfig } = useSiteData();
  const { frontmatter } = useRouteMeta();

  return (
    <div
      className="dumi-default-content"
      data-no-footer={themeConfig.footer === false || undefined}
      data-no-sidebar={!sidebar || frontmatter.sidebar === false || undefined}
      id="utlint-main-content"
      tabIndex={-1}
    >
      {children}
    </div>
  );
}
