import { useLocale, useSiteData } from 'dumi';
import React from 'react';
import 'dumi/theme-default/slots/Footer/index.less';

export default function Footer() {
  const { themeConfig } = useSiteData();
  const isChinese = useLocale().id === 'zh-CN';

  if (!themeConfig.footer) return null;

  return (
    <div className="dumi-default-footer">
      {isChinese
        ? '基于 MIT 许可证发布 · 由 utoo-lint 贡献者共同构建'
        : 'Released under the MIT License · Built by the utoo-lint contributors'}
    </div>
  );
}
