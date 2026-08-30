import {
  Helmet,
  useLocale,
  useLocation,
  useRouteMeta,
  useSiteData,
} from 'dumi';
import ColorSwitch from 'dumi/theme/slots/ColorSwitch';
import HeaderExtra from 'dumi/theme/slots/HeaderExtra';
import LangSwitch from 'dumi/theme/slots/LangSwitch';
import Logo from 'dumi/theme/slots/Logo';
import Navbar from 'dumi/theme/slots/Navbar';
import RtlSwitch from 'dumi/theme/slots/RtlSwitch';
import SearchBar from 'dumi/theme/slots/SearchBar';
import SocialIcon from 'dumi/theme/slots/SocialIcon';
import React, { useEffect, useId, useMemo, useState } from 'react';
import 'dumi/theme-default/slots/Header/index.less';

function CloseIcon() {
  return (
    <svg aria-hidden="true" viewBox="64 64 896 896">
      <path d="M563.8 512 832 243.8a8 8 0 0 0 0-11.3l-40.5-40.5a8 8 0 0 0-11.3 0L512 460.2 243.8 192a8 8 0 0 0-11.3 0L192 232.5a8 8 0 0 0 0 11.3L460.2 512 192 780.2a8 8 0 0 0 0 11.3l40.5 40.5a8 8 0 0 0 11.3 0L512 563.8 780.2 832a8 8 0 0 0 11.3 0l40.5-40.5a8 8 0 0 0 0-11.3L563.8 512Z" />
    </svg>
  );
}

function MenuIcon() {
  return (
    <svg aria-hidden="true" viewBox="64 64 896 896">
      <path d="M904 160H120c-4.4 0-8 3.6-8 8v64c0 4.4 3.6 8 8 8h784c4.4 0 8-3.6 8-8v-64c0-4.4-3.6-8-8-8Zm0 312H120c-4.4 0-8 3.6-8 8v64c0 4.4 3.6 8 8 8h784c4.4 0 8-3.6 8-8v-64c0-4.4-3.6-8-8-8Zm0 312H120c-4.4 0-8 3.6-8 8v64c0 4.4 3.6 8 8 8h784c4.4 0 8-3.6 8-8v-64c0-4.4-3.6-8-8-8Z" />
    </svg>
  );
}

export default function Header() {
  const { frontmatter } = useRouteMeta();
  const locale = useLocale();
  const isChinese = locale.id === 'zh-CN';
  const { pathname } = useLocation();
  const [showMenu, setShowMenu] = useState(false);
  const { hostname, themeConfig } = useSiteData();
  const mobileNavigationId = useId();
  const socialIcons = useMemo(() => {
    const { socialLinks } = themeConfig;
    return socialLinks
      ? Object.keys(socialLinks)
          .slice(0, 5)
          .map((icon) => ({ icon, link: socialLinks[icon] }))
          .filter((item) => Boolean(item.link))
      : [];
  }, [themeConfig.socialLinks]);

  useEffect(() => {
    if (!showMenu) return;

    const closeMenu = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setShowMenu(false);
    };

    document.addEventListener('keydown', closeMenu);
    return () => document.removeEventListener('keydown', closeMenu);
  }, [showMenu]);

  const pathWithoutLocale =
    pathname.replace(/^\/zh-CN(?=\/|$)/, '') || '/';
  const englishPath = pathWithoutLocale;
  const chinesePath =
    pathWithoutLocale === '/' ? '/zh-CN/' : `/zh-CN${pathWithoutLocale}`;

  return (
    <>
      <Helmet htmlAttributes={{ lang: isChinese ? 'zh-CN' : 'en' }}>
        {hostname && frontmatter.filename && (
          <>
            <link
              href={`${hostname}${englishPath}`}
              hrefLang="en"
              rel="alternate"
            />
            <link
              href={`${hostname}${chinesePath}`}
              hrefLang="zh-CN"
              rel="alternate"
            />
            <link
              href={`${hostname}${englishPath}`}
              hrefLang="x-default"
              rel="alternate"
            />
          </>
        )}
      </Helmet>
      <div
        className="dumi-default-header"
        data-mobile-active={showMenu || undefined}
        data-static={Boolean(frontmatter.hero) || undefined}
        onClick={() => setShowMenu(false)}
      >
        <a className="utlint-skip-link" href="#utlint-main-content">
          {isChinese ? '跳到正文' : 'Skip to content'}
        </a>
        <div className="dumi-default-header-content">
          <section className="dumi-default-header-left">
            <Logo />
          </section>
          <section
            className="dumi-default-header-right"
            id={mobileNavigationId}
          >
            <Navbar />
            <div className="dumi-default-header-right-aside">
              <SearchBar />
              <LangSwitch />
              <RtlSwitch />
              {themeConfig.prefersColor.switch && <ColorSwitch />}
              {socialIcons.map((item) => (
                <SocialIcon icon={item.icon} key={item.link} link={item.link!} />
              ))}
              <HeaderExtra />
            </div>
          </section>
          <button
            aria-controls={mobileNavigationId}
            aria-expanded={showMenu}
            aria-label={
              isChinese
                ? showMenu
                  ? '关闭导航菜单'
                  : '打开导航菜单'
                : showMenu
                  ? 'Close navigation menu'
                  : 'Open navigation menu'
            }
            className="dumi-default-header-menu-btn"
            onClick={(event) => {
              event.stopPropagation();
              setShowMenu((visible) => !visible);
            }}
            type="button"
          >
            {showMenu ? <CloseIcon /> : <MenuIcon />}
          </button>
        </div>
      </div>
    </>
  );
}
