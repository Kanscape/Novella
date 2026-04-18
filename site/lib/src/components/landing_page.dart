import 'package:jaspr/dom.dart' show RawText;
import 'package:jaspr/jaspr.dart';

import '../content/models.dart';
import '../utils/formatters.dart';
import '../utils/platform_assets.dart';

// GitHub SVG 图标
const _githubSvg =
    '<svg class="w-5 h-5" viewBox="0 0 16 16" fill="currentColor">'
    '<path d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08'
    '-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2'
    ' 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0'
    ' 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03'
    '-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0'
    ' 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66'
    '-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45'
    '.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995'
    ' 0 0 1 0 8c0-4.42 3.58-8 8-8Z"/></svg>';

const _repositoryJsonPath = 'repository.json';

// ━━━ 页面组件 ━━━

class HomePage extends StatelessComponent {
  const HomePage({required this.siteData, super.key});

  final SiteData siteData;

  @override
  Component build(BuildContext context) {
    final featured = featuredAssets(siteData.latestRelease.assets);

    return _siteShell(
      currentPath: '/',
      siteData: siteData,
      children: [
        _buildHomeHero(siteData, featured),
        _buildFeatureStrip(),
        _buildContributorsSection(siteData),
      ],
    );
  }
}

class DownloadPage extends StatelessComponent {
  const DownloadPage({required this.siteData, super.key});

  final SiteData siteData;

  @override
  Component build(BuildContext context) {
    final featured = featuredAssets(siteData.latestRelease.assets);

    return _siteShell(
      currentPath: '/download',
      siteData: siteData,
      children: [
        _buildPageHero(
          eyebrow: 'Download',
          title: '获取最新版本',
          description: '下载 Novella 最新版安装包，目前仅支持部分平台。',
          heroImage: 'assets/screenshots/Novella_reader.png',
        ),
        _buildDownloadSection(siteData, featured),
      ],
    );
  }
}

class ChangelogPage extends StatelessComponent {
  const ChangelogPage({required this.siteData, super.key});

  final SiteData siteData;

  @override
  Component build(BuildContext context) {
    return _siteShell(
      currentPath: '/changelog',
      siteData: siteData,
      children: [
        _buildPageHero(
          eyebrow: 'Changelog',
          title: '更新日志',
          description: '查看最新版本的变更内容与改进详情。',
        ),
        _buildReleaseSection(siteData),
      ],
    );
  }
}

// ━━━ 页面外壳 ━━━

class NotFoundPage extends StatelessComponent {
  const NotFoundPage({required this.siteData, super.key});

  final SiteData siteData;

  @override
  Component build(BuildContext context) {
    return _siteShell(
      currentPath: '',
      siteData: siteData,
      children: [
        _section(
          id: 'not-found',
          child: _el(
            'div',
            attrs: {'class': 'min-h-[60vh] flex items-center justify-center'},
            children: [
              _el(
                'div',
                attrs: {
                  'class':
                      'card bg-base-200/60 border border-base-content/5 '
                      'max-w-3xl w-full shadow-2xl',
                },
                children: [
                  _el(
                    'div',
                    attrs: {'class': 'card-body p-8 lg:p-12 gap-6'},
                    children: [
                      _el(
                        'span',
                        attrs: {
                          'class': 'badge badge-primary badge-outline w-fit',
                        },
                        children: [_text('404 Not Found')],
                      ),
                      _el(
                        'h1',
                        attrs: {
                          'class':
                              'text-4xl lg:text-6xl font-extrabold tracking-tight m-0',
                        },
                        children: [_text('这个页面不存在')],
                      ),
                      _el(
                        'p',
                        attrs: {
                          'class':
                              'text-base lg:text-lg text-base-content/65 m-0 leading-relaxed',
                        },
                        children: [_text('当前访问的路径没有对应的站点页面。')],
                      ),
                      _el(
                        'div',
                        attrs: {'class': 'flex flex-wrap gap-3'},
                        children: [
                          _anchor('/', '返回首页', classes: 'btn btn-primary'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Component _siteShell({
  required String currentPath,
  required SiteData siteData,
  required List<Component> children,
}) {
  return _el(
    'div',
    attrs: {'data-theme': 'novella', 'class': 'min-h-screen'},
    children: [
      _buildHeader(currentPath, siteData),
      _el('main', children: children),
      _buildFooter(siteData),
    ],
  );
}

// ━━━ 导航栏 ━━━

Component _buildHeader(String currentPath, SiteData siteData) {
  return _el(
    'header',
    attrs: {
      'class':
          'sticky top-0 z-50 '
          'bg-base-100/80 backdrop-blur-xl '
          'border-b border-base-content/5',
    },
    children: [
      _el(
        'div',
        attrs: {
          'class':
              'max-w-7xl mx-auto px-6 '
              'flex items-center justify-between h-16',
        },
        children: [
          // 品牌
          _el(
            'a',
            attrs: {'href': '/', 'class': 'flex items-center gap-3'},
            children: [
              _img(
                src: 'assets/brand/favicon.png',
                alt: 'Novella',
                classes: 'w-8 h-8 rounded-lg',
              ),
              _el(
                'span',
                attrs: {'class': 'text-lg font-bold tracking-tight'},
                children: [_text('Novella')],
              ),
            ],
          ),
          // 导航链接
          _el(
            'nav',
            attrs: {'class': 'hidden md:flex items-center gap-6 text-sm'},
            children: [
              _navLink('/', 'Home', currentPath),
              _navLink('/download', 'Download', currentPath),
              _navLink('/changelog', 'Changelog', currentPath),
            ],
          ),
          // 右侧操作区
          _el(
            'div',
            attrs: {'class': 'flex items-center gap-3'},
            children: [
              _el(
                'a',
                attrs: {
                  'href': siteData.repository.url,
                  'target': '_blank',
                  'rel': 'noreferrer noopener',
                  'class':
                      'btn btn-ghost btn-sm gap-2 hover:bg-base-content hover:text-base-100',
                },
                children: [
                  RawText(_githubSvg),
                  _text(formatCompactNumber(siteData.repository.stars)),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

// ━━━ 首页 Hero ━━━

Component _buildHomeHero(SiteData siteData, List<ReleaseAsset> featured) {
  final platforms = _homePlatforms(featured);

  return _el(
    'section',
    attrs: {'class': 'pt-16 pb-8 lg:pt-24 lg:pb-16'},
    children: [
      _el(
        'div',
        attrs: {
          'class':
              'max-w-7xl mx-auto px-6 '
              'grid lg:grid-cols-2 gap-12 lg:gap-16 items-center',
        },
        children: [
          // 左侧文案
          _el(
            'div',
            attrs: {'class': 'max-w-xl'},
            children: [
              // 徽章行
              _el(
                'div',
                attrs: {'class': 'flex flex-wrap gap-2 mb-6'},
                children: [_pill('Open Source'), _pill('AGPL-3.0')],
              ),
              // 大标题
              _el(
                'h1',
                attrs: {
                  'class':
                      'text-4xl sm:text-5xl lg:text-6xl '
                      'font-extrabold leading-[0.95] tracking-tight mb-6',
                },
                children: [
                  _el(
                    'span',
                    attrs: {'class': 'text-primary'},
                    children: [_text('Novella,')],
                  ),
                  _text(' crafted with Flutter & Rust'),
                ],
              ),
              // 兼容平台行
              _el(
                'div',
                attrs: {'class': 'flex flex-wrap items-center gap-3 mb-6'},
                children: [
                  _el(
                    'span',
                    attrs: {
                      'class':
                          'text-xs font-bold tracking-widest '
                          'text-base-content/80 uppercase',
                    },
                    children: [_text('AVAILABLE ON:')],
                  ),
                  for (final platform in platforms)
                    _el(
                      'span',
                      attrs: {'class': 'badge badge-outline badge-sm'},
                      children: [_text(platform)],
                    ),
                ],
              ),
              // 描述段落
              _el(
                'p',
                attrs: {
                  'class':
                      'text-base lg:text-lg text-base-content/60 '
                      'mb-8 leading-relaxed',
                },
                children: [
                  _text(
                    '轻书架第三方客户端，'
                    '提供高度个性化的阅读体验。',
                  ),
                ],
              ),
              // 操作按钮
              _el(
                'div',
                attrs: {'class': 'flex flex-col sm:flex-row gap-3'},
                children: [
                  _anchor('/download', '立即下载', classes: 'btn btn-primary'),
                  _anchor(
                    siteData.repository.url,
                    '查看源代码',
                    classes:
                        'btn btn-ghost btn-outline hover:bg-base-content hover:text-base-100',
                    external: true,
                  ),
                ],
              ),
              // 版本信息行
              _el(
                'div',
                attrs: {'class': 'flex flex-wrap items-center gap-4 mt-6'},
                children: [
                  _el(
                    'a',
                    attrs: {
                      'href': _repositoryJsonPath,
                      'class':
                          'font-semibold text-base-content/80 hover:text-primary transition-colors',
                      'data-app-sources-trigger': 'true',
                      'data-repository-url': _repositoryJsonPath,
                      'aria-haspopup': 'dialog',
                    },
                    children: [_text('App Sources →')],
                  ),
                ],
              ),
              _buildAppSourcesModal(),
            ],
          ),
          // 右侧视觉区域
          _buildHeroVisual(siteData, featured),
        ],
      ),
    ],
  );
}

Component _buildAppSourcesModal() {
  return _el(
    'div',
    attrs: {
      'class':
          'hidden fixed inset-0 z-[70] overflow-y-auto overscroll-contain '
          'bg-black/70 backdrop-blur-md',
      'data-app-sources-modal': 'true',
      'role': 'dialog',
      'aria-modal': 'true',
      'aria-labelledby': 'app-sources-title',
    },
    children: [
      // Centering wrapper – bottom sheet on mobile, centered on desktop
      _el(
        'div',
        attrs: {
          'class':
              'flex min-h-full items-end sm:items-center justify-center p-0 sm:p-6',
        },
        children: [
          // Panel — sheet-style on mobile, centered card on desktop
          _el(
            'div',
            attrs: {
              'class':
                  'relative w-full sm:max-w-lg overflow-hidden '
                  'rounded-t-[1.75rem] sm:rounded-[1.75rem] '
                  'border border-base-content/8 bg-base-200 shadow-2xl',
              'data-app-sources-panel': 'true',
            },
            children: [
              // Decorative gradient glow
              _el(
                'div',
                attrs: {
                  'class':
                      'pointer-events-none absolute -top-24 left-1/2 -translate-x-1/2 '
                      'h-48 w-72 rounded-full bg-primary/20 blur-3xl',
                },
              ),
              // Content
              _el(
                'div',
                attrs: {'class': 'relative p-5 sm:p-6'},
                children: [
                  // Header row
                  _el(
                    'div',
                    attrs: {
                      'class': 'flex items-start justify-between gap-3 mb-1',
                    },
                    children: [
                      _el(
                        'div',
                        children: [
                          _el(
                            'h3',
                            attrs: {
                              'id': 'app-sources-title',
                              'class': 'text-lg font-bold tracking-tight',
                            },
                            children: [_text('添加 App Source')],
                          ),
                          _el(
                            'p',
                            attrs: {
                              'class':
                                  'mt-1 text-sm leading-relaxed text-base-content/50',
                            },
                            children: [_text('选择侧载工具，自动导入源。')],
                          ),
                        ],
                      ),
                      // Close button — circular ×
                      _el(
                        'button',
                        attrs: {
                          'type': 'button',
                          'class':
                              'flex h-8 w-8 shrink-0 items-center justify-center rounded-full '
                              'bg-base-content/8 text-base-content/50 '
                              'transition hover:bg-base-content/15 hover:text-base-content',
                          'data-app-sources-close': 'true',
                          'aria-label': '关闭',
                        },
                        children: [
                          RawText(
                            '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">'
                            '<path d="M1 1l12 12M13 1L1 13"/></svg>',
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Sideload target cards — horizontal list
                  _el(
                    'div',
                    attrs: {'class': 'mt-4 flex flex-col gap-2.5'},
                    children: [
                      _sideloadTargetCard(
                        id: 'altstore',
                        title: 'AltStore',
                        description: 'AltStore is an alternative app store for non-jailbroken iOS devices.',
                        iconPath: 'assets/sideloaders/altstore.png',
                      ),
                      _sideloadTargetCard(
                        id: 'sidestore',
                        title: 'SideStore',
                        description: 'SideStore is a fork of AltStore that doesn\'t require an AltServer.',
                        iconPath: 'assets/sideloaders/sidestore.png',
                      ),
                      _sideloadTargetCard(
                        id: 'feather',
                        title: 'Feather',
                        description: 'On-device iOS installer utilizing Apple Developer certificates.',
                        iconPath: 'assets/sideloaders/feather.png',
                      ),
                    ],
                  ),
                  // Footer — compact URL bar
                  _el(
                    'div',
                    attrs: {
                      'class':
                          'mt-4 flex items-center gap-3 rounded-xl '
                          'bg-base-content/5 px-3.5 py-2.5',
                    },
                    children: [
                      _el(
                        'code',
                        attrs: {
                          'class':
                              'flex-1 min-w-0 truncate text-xs text-base-content/45',
                          'data-app-sources-url': 'true',
                        },
                        children: [_text(_repositoryJsonPath)],
                      ),
                      _anchor(
                        _repositoryJsonPath,
                        '打开',
                        classes:
                            'shrink-0 text-xs font-semibold text-primary hover:text-primary/80 transition-colors',
                        extraAttrs: const {
                          'data-app-sources-fallback': 'true',
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Component _sideloadTargetCard({
  required String id,
  required String title,
  required String description,
  required String iconPath,
}) {
  return _el(
    'a',
    attrs: {
      'href': _repositoryJsonPath,
      'class':
          'group flex items-center gap-4 rounded-2xl '
          'border border-base-content/6 bg-base-100/50 '
          'px-4 py-3.5 transition-all duration-200 '
          'hover:border-primary/30 hover:bg-base-100/80 '
          'hover:shadow-lg hover:shadow-primary/5',
      'data-app-source-target': id,
    },
    children: [
      // Icon
      _img(
        src: iconPath,
        alt: title,
        classes: 'h-10 w-10 shrink-0 object-contain',
        loading: 'lazy',
      ),
      // Text
      _el(
        'div',
        attrs: {'class': 'flex-1 min-w-0'},
        children: [
          _el(
            'div',
            attrs: {'class': 'text-sm font-semibold tracking-tight'},
            children: [_text(title)],
          ),
          _el(
            'p',
            attrs: {
              'class':
                  'mt-0.5 text-xs leading-relaxed text-base-content/45',
            },
            children: [_text(description)],
          ),
        ],
      ),
      // Chevron arrow
      RawText(
        '<svg class="shrink-0 w-4 h-4 text-base-content/25 group-hover:text-primary/60 transition-colors" '
        'viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" '
        'stroke-linecap="round" stroke-linejoin="round">'
        '<path d="M6 3l5 5-5 5"/></svg>',
      ),
    ],
  );
}

Component _buildHeroVisual(SiteData siteData, List<ReleaseAsset> featured) {
  return _el(
    'div',
    attrs: {
      'class': 'relative mt-12 lg:mt-0 flex w-full items-center justify-center',
    },
    children: [
      _img(
        src: 'assets/screenshots/Novella_hero.png',
        alt: 'Novella app preview',
        classes:
            'w-full max-w-sm lg:max-w-md h-auto object-contain drop-shadow-2xl transition hover:-translate-y-2 duration-500',
      ),
    ],
  );
}
// ━━━ 首页特性区（Preline 式 3 列） ━━━

Component _buildFeatureStrip() {
  final items = [
    (
      index: '01',
      title: '沉浸式阅读体验',
      description: '支持字号大小、行间距调节、背景色调整，为长时间阅读场景而设计的界面。',
    ),
    (
      index: '02',
      title: 'Material 3 动态主题',
      description: '自动适配浅色、深色与纯黑模式，详情页还支持从封面提取主色调，呈现独特的视觉效果。',
    ),
    (index: '03', title: '跨设备同步', description: '书架、阅读进度、状态标记在设备间无缝同步，随时继续阅读。'),
  ];

  return _el(
    'section',
    attrs: {'class': 'py-16 lg:py-24 border-t border-base-content/5'},
    children: [
      _el(
        'div',
        attrs: {
          'class':
              'max-w-7xl mx-auto px-6 '
              'grid md:grid-cols-3 gap-8 lg:gap-12',
        },
        children: [
          for (final item in items)
            _el(
              'div',
              attrs: {'class': 'flex gap-4'},
              children: [
                _el(
                  'div',
                  attrs: {
                    'class':
                        'shrink-0 w-12 h-12 rounded-xl '
                        'bg-primary/10 flex items-center justify-center '
                        'text-primary font-bold text-sm',
                  },
                  children: [_text(item.index)],
                ),
                _el(
                  'div',
                  children: [
                    _el(
                      'h3',
                      attrs: {'class': 'font-bold text-base mb-1'},
                      children: [_text(item.title)],
                    ),
                    _el(
                      'p',
                      attrs: {
                        'class':
                            'text-sm text-base-content/60 '
                            'leading-relaxed m-0',
                      },
                      children: [_text(item.description)],
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

// ━━━ 贡献者 ━━━

Component _buildContributorsSection(SiteData siteData) {
  return _el(
    'section',
    attrs: {'id': 'contributors', 'class': 'py-16 lg:py-24'},
    children: [
      _el(
        'div',
        attrs: {'class': 'max-w-7xl mx-auto px-6'},
        children: [
          // 标题
          _el(
            'div',
            attrs: {'class': 'text-center mb-12'},
            children: [
              _el(
                'span',
                attrs: {
                  'class':
                      'text-sm font-bold tracking-widest '
                      'text-primary uppercase mb-3 block',
                },
                children: [_text('Contributors')],
              ),
              _el(
                'h2',
                attrs: {
                  'class':
                      'text-3xl lg:text-4xl font-bold '
                      'tracking-tight mb-4',
                },
                children: [_text('开源贡献者')],
              ),
              _el(
                'p',
                attrs: {'class': 'text-base-content/60 max-w-lg mx-auto'},
                children: [_text('感谢每一位为 Novella 贡献代码的开发者。')],
              ),
            ],
          ),
          // 贡献者网格
          _el(
            'div',
            attrs: {'class': 'grid sm:grid-cols-2 lg:grid-cols-3 gap-4'},
            children: [
              if (siteData.contributors.isEmpty)
                _el(
                  'div',
                  attrs: {
                    'class':
                        'card bg-base-200/60 border '
                        'border-base-content/5 col-span-full',
                  },
                  children: [
                    _el(
                      'div',
                      attrs: {'class': 'card-body p-5'},
                      children: [
                        _el(
                          'p',
                          attrs: {'class': 'text-base-content/50'},
                          children: [_text('暂无贡献者数据。')],
                        ),
                      ],
                    ),
                  ],
                )
              else
                for (final contributor in siteData.contributors)
                  _el(
                    'div',
                    attrs: {
                      'class':
                          'card bg-base-200/60 border '
                          'border-base-content/5',
                    },
                    children: [
                      _el(
                        'div',
                        attrs: {
                          'class':
                              'card-body flex-row '
                              'items-center gap-4 p-5',
                        },
                        children: [
                          _img(
                            src: contributor.avatarUrl,
                            alt: contributor.login,
                            classes: 'w-14 h-14 rounded-full object-cover',
                            loading: 'lazy',
                          ),
                          _el(
                            'div',
                            attrs: {'class': 'flex-1 min-w-0'},
                            children: [
                              _el(
                                'h3',
                                attrs: {'class': 'font-bold truncate'},
                                children: [_text(contributor.login)],
                              ),
                              _el(
                                'p',
                                attrs: {
                                  'class': 'text-sm text-base-content/50 m-0',
                                },
                                children: [
                                  _text('${contributor.contributions} commits'),
                                ],
                              ),
                            ],
                          ),
                          _anchor(
                            contributor.profileUrl,
                            'GitHub',
                            classes:
                                'btn btn-ghost btn-sm hover:bg-base-content hover:text-base-100',
                            external: true,
                          ),
                        ],
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    ],
  );
}

// ━━━ 子页面 Hero（通用） ━━━

Component _buildPageHero({
  required String eyebrow,
  required String title,
  required String description,
  String? heroImage,
}) {
  return _el(
    'section',
    attrs: {'class': 'pt-24 pb-8 lg:pt-32 lg:pb-12'},
    children: [
      _el(
        'div',
        attrs: {
          'class': heroImage != null
              ? 'max-w-7xl mx-auto px-6 w-full grid lg:grid-cols-2 gap-12 lg:gap-16 items-center'
              : 'max-w-7xl mx-auto px-6',
        },
        children: [
          _el(
            'div',
            attrs: {'class': 'max-w-3xl'},
            children: [
              _el(
                'span',
                attrs: {
                  'class':
                      'text-sm font-bold tracking-widest '
                      'text-primary uppercase mb-3 block',
                },
                children: [_text(eyebrow)],
              ),
              _el(
                'h1',
                attrs: {
                  'class':
                      'text-3xl lg:text-5xl font-bold '
                      'tracking-tight mb-4',
                },
                children: [_text(title)],
              ),
              _el(
                'p',
                attrs: {'class': 'text-base-content/60 text-lg'},
                children: [_text(description)],
              ),
            ],
          ),
          if (heroImage != null)
            _el(
              'div',
              attrs: {
                'class':
                    'mt-12 lg:mt-0 flex w-full items-center justify-center',
              },
              children: [
                _el(
                  'div',
                  attrs: {'class': 'max-w-sm lg:max-w-md w-full relative'},
                  children: [
                    _el(
                      'img',
                      attrs: {
                        'src': heroImage,
                        'alt': '$title preview',
                        'class':
                            'w-full h-auto drop-shadow-2xl '
                            'hover:scale-105 transition-transform duration-500',
                      },
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

// ━━━ 特性页（4 条详情） ━━━

// ━━━ 下载页 ━━━

Component _buildDownloadSection(
  SiteData siteData,
  List<ReleaseAsset> featured,
) {
  return _section(
    id: 'download',
    child: _el(
      'div',
      attrs: {'class': 'grid lg:grid-cols-[0.8fr_1.2fr] gap-4'},
      children: [
        // 版本概览卡片
        _el(
          'div',
          attrs: {'class': 'card bg-base-200/60 border border-base-content/5'},
          children: [
            _el(
              'div',
              attrs: {'class': 'card-body p-6'},
              children: [
                _el(
                  'h3',
                  attrs: {'class': 'font-bold text-xl mb-2'},
                  children: [_text(siteData.latestRelease.name)],
                ),
                _el(
                  'span',
                  attrs: {'class': 'badge badge-outline badge-sm mb-5'},
                  children: [_text('LATEST')],
                ),
                _el(
                  'dl',
                  attrs: {'class': 'grid gap-3 mb-6'},
                  children: [
                    _metaRow(
                      '发布时间',
                      formatChineseDate(siteData.latestRelease.publishedAt),
                    ),
                    _metaRow(
                      '资源数量',
                      '${siteData.latestRelease.assets.length} 个',
                    ),
                    _metaRow('站点构建', formatChineseDate(siteData.generatedAt)),
                  ],
                ),
                _el(
                  'div',
                  attrs: {'class': 'flex flex-wrap gap-3'},
                  children: [
                    _anchor(
                      siteData.latestRelease.url,
                      '前往 GitHub Release',
                      classes: 'btn btn-primary btn-sm',
                      external: true,
                    ),
                    _anchor(
                      '/changelog',
                      '查看更新日志',
                      classes:
                          'btn btn-ghost btn-sm hover:bg-base-content hover:text-base-100',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // 平台下载卡片
        _el(
          'div',
          attrs: {'class': 'grid sm:grid-cols-2 gap-4'},
          children: [
            if (featured.isEmpty)
              _el(
                'div',
                attrs: {
                  'class':
                      'card bg-base-200/60 border '
                      'border-base-content/5 col-span-full',
                },
                children: [
                  _el(
                    'div',
                    attrs: {'class': 'card-body p-6'},
                    children: [
                      _el(
                        'h3',
                        attrs: {'class': 'font-bold'},
                        children: [_text('暂未识别到平台安装包')],
                      ),
                      _el(
                        'p',
                        attrs: {'class': 'text-base-content/50'},
                        children: [_text('当前 Release 未识别出可用安装包，请查看完整资源列表。')],
                      ),
                    ],
                  ),
                ],
              )
            else
              for (final asset in featured) _featuredAssetCard(asset),
          ],
        ),
        // 完整资源列表
        _el(
          'div',
          attrs: {
            'class':
                'card bg-base-200/60 border '
                'border-base-content/5 lg:col-span-full',
          },
          children: [
            _el(
              'div',
              attrs: {'class': 'card-body p-6'},
              children: [
                _el(
                  'div',
                  attrs: {'class': 'mb-5'},
                  children: [
                    _el(
                      'h3',
                      attrs: {'class': 'font-bold mb-1'},
                      children: [_text('完整资源列表')],
                    ),
                    _el(
                      'p',
                      attrs: {'class': 'text-sm text-base-content/50 m-0'},
                      children: [_text('来自 GitHub Release 的全部公开 assets。')],
                    ),
                  ],
                ),
                if (siteData.latestRelease.assets.isEmpty)
                  _el(
                    'p',
                    attrs: {'class': 'text-base-content/50'},
                    children: [_text('暂无可下载资源。')],
                  )
                else
                  _el(
                    'div',
                    attrs: {'class': 'grid gap-3'},
                    children: [
                      for (final asset in siteData.latestRelease.assets)
                        _assetRow(asset),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

// ━━━ 更新日志页 ━━━

Component _buildReleaseSection(SiteData siteData) {
  return _section(
    id: 'changelog',
    child: _el(
      'div',
      attrs: {'class': 'card bg-base-200/60 border border-base-content/5'},
      children: [
        _el(
          'div',
          attrs: {'class': 'card-body p-6'},
          children: [
            _el(
              'div',
              attrs: {
                'class':
                    'flex flex-col sm:flex-row '
                    'items-start sm:items-center '
                    'justify-between gap-4 mb-6',
              },
              children: [
                _el(
                  'div',
                  children: [
                    _el(
                      'h3',
                      attrs: {'class': 'font-bold text-lg'},
                      children: [_text(siteData.latestRelease.name)],
                    ),
                  ],
                ),
                _anchor(
                  siteData.latestRelease.url,
                  '在 GitHub 中查看',
                  classes:
                      'btn btn-ghost btn-sm hover:bg-base-content hover:text-base-100',
                  external: true,
                ),
              ],
            ),
            _el(
              'div',
              attrs: {'class': 'release-markdown'},
              children: [
                if (siteData.latestRelease.hasBody)
                  RawText(siteData.latestRelease.bodyHtml)
                else
                  _el(
                    'p',
                    attrs: {'class': 'text-base-content/50'},
                    children: [_text('该版本暂无发布说明，站点会在检测到内容后自动更新。')],
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

// ━━━ Footer ━━━

Component _buildFooter(SiteData siteData) {
  return _el(
    'footer',
    attrs: {'class': 'border-t border-base-content/5'},
    children: [
      _el(
        'div',
        attrs: {
          'class':
              'max-w-7xl mx-auto px-6 py-8 '
              'flex flex-col sm:flex-row '
              'items-start justify-between gap-6',
        },
        children: [
          _el(
            'div',
            children: [
              _el(
                'strong',
                attrs: {'class': 'block mb-2'},
                children: [_text('Novella')],
              ),
              _el(
                'p',
                attrs: {
                  'class':
                      'text-sm text-base-content/50 '
                      'max-w-md m-0 leading-relaxed',
                },
                children: [
                  _text('开源小说阅读器，轻书架第三方客户端。'),
                  _el('br'),
                  _text('网页由 Jaspr 静态构建，通过 Cloudflare Pages 发布。'),
                ],
              ),
            ],
          ),
          _el(
            'style',
            children: [
              _text('''
                .footer-right-col { align-items: flex-start; }
                .badge-wrapper { display: flex; justify-content: flex-start; width: 100%; }
                @media (min-width: 640px) {
                  .footer-right-col { align-items: flex-end; }
                  .badge-wrapper { justify-content: flex-end; }
                }
              '''),
            ],
          ),
          _el(
            'div',
            attrs: {
              'class':
                  'flex flex-col gap-3 text-sm text-base-content/50 footer-right-col',
            },
            children: [
              _el(
                'div',
                attrs: {'class': 'flex items-center gap-3'},
                children: [
                  _anchor(siteData.repository.url, 'GitHub', external: true),
                  _anchor(
                    '${siteData.repository.url}/releases',
                    'Changelog',
                    external: true,
                  ),
                  _anchor(
                    '${siteData.repository.url}/discussions',
                    'Discussions',
                    external: true,
                  ),
                  _anchor(
                    'https://www.lightnovel.app',
                    'LightNovelShelf',
                    external: true,
                  ),
                ],
              ),
              _el(
                'div',
                attrs: {'class': 'badge-wrapper'},
                children: [
                  _el(
                    'a',
                    attrs: {
                      'href': 'https://jaspr.site',
                      'target': '_blank',
                      'rel': 'noreferrer noopener',
                    },
                    children: [JasprBadge.dark()],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

// ━━━ 可复用组件 ━━━

Component _featuredAssetCard(ReleaseAsset asset) {
  return _el(
    'article',
    attrs: {'class': 'card bg-base-200/60 border border-base-content/5'},
    children: [
      _el(
        'div',
        attrs: {'class': 'card-body p-5 gap-3'},
        children: [
          _el(
            'div',
            children: [
              _el(
                'span',
                attrs: {'class': 'badge badge-outline badge-sm mb-2'},
                children: [_text(platformLabel(asset.platform))],
              ),
              _el(
                'strong',
                attrs: {'class': 'block text-sm'},
                children: [_text(asset.name)],
              ),
            ],
          ),
          _el(
            'p',
            attrs: {'class': 'text-sm text-base-content/50 m-0'},
            children: [_text(platformHint(asset.platform))],
          ),
          _el(
            'dl',
            attrs: {'class': 'grid gap-2'},
            children: [
              _metaRow('大小', formatFileSize(asset.size)),
              _metaRow('下载', '${asset.downloadCount} 次'),
              _metaRow('更新', formatChineseDate(asset.updatedAt)),
            ],
          ),
          _anchor(
            asset.url,
            '下载 ${platformLabel(asset.platform)} 版本',
            classes: 'btn btn-primary btn-sm',
            external: true,
          ),
        ],
      ),
    ],
  );
}

Component _assetRow(ReleaseAsset asset) {
  return _el(
    'div',
    attrs: {
      'class':
          'flex flex-col sm:flex-row items-start sm:items-center '
          'justify-between gap-3 p-4 rounded-xl '
          'border border-base-content/5 bg-base-content/3',
    },
    children: [
      _el(
        'div',
        children: [
          _el(
            'strong',
            attrs: {'class': 'block text-sm'},
            children: [_text(asset.name)],
          ),
          _el(
            'span',
            attrs: {'class': 'text-sm text-base-content/50'},
            children: [
              _text(
                '${platformLabel(asset.platform)} · '
                '${formatFileSize(asset.size)} · '
                '${asset.downloadCount} 次下载',
              ),
            ],
          ),
        ],
      ),
      _anchor(
        asset.url,
        '下载',
        classes:
            'btn btn-ghost btn-sm hover:bg-base-content hover:text-base-100',
        external: true,
      ),
    ],
  );
}

Component _section({required String id, required Component child}) {
  return _el(
    'section',
    attrs: {'id': id, 'class': 'py-16 lg:py-24'},
    children: [
      _el('div', attrs: {'class': 'max-w-7xl mx-auto px-6'}, children: [child]),
    ],
  );
}

List<String> _homePlatforms(List<ReleaseAsset> featured) {
  final labels = [
    for (final asset in featured.take(4)) platformLabel(asset.platform),
  ];
  if (labels.isEmpty) {
    return const ['Android', 'Windows', 'macOS', 'Linux'];
  }
  return labels;
}

Component _metaRow(String label, String value) {
  return _el(
    'div',
    attrs: {
      'class':
          'flex items-center justify-between gap-4 '
          'pb-2 border-b border-base-content/5 text-sm',
    },
    children: [
      _el(
        'dt',
        attrs: {'class': 'text-base-content/50 m-0'},
        children: [_text(label)],
      ),
      _el('dd', attrs: {'class': 'm-0'}, children: [_text(value)]),
    ],
  );
}

Component _pill(String value) {
  return _el(
    'span',
    attrs: {'class': 'badge badge-ghost badge-sm'},
    children: [_text(value)],
  );
}

Component _navLink(String href, String label, String currentPath) {
  final isActive = currentPath == href;
  final classes = isActive
      ? 'text-primary font-medium'
      : 'text-base-content/60 hover:text-base-content transition-colors';
  return _anchor(href, label, classes: classes);
}

Component _anchor(
  String href,
  String label, {
  String? classes,
  bool external = false,
  Map<String, String?> extraAttrs = const {},
}) {
  final attrs = <String, String>{'href': href};
  if (classes != null) {
    attrs['class'] = classes;
  }
  if (external) {
    attrs['target'] = '_blank';
    attrs['rel'] = 'noreferrer noopener';
  }
  for (final entry in extraAttrs.entries) {
    final value = entry.value;
    if (value != null && value.isNotEmpty) {
      attrs[entry.key] = value;
    }
  }

  return _el('a', attrs: attrs, children: [_text(label)]);
}

Component _img({
  required String src,
  required String alt,
  String? classes,
  String? loading,
}) {
  final attrs = <String, String>{'src': src, 'alt': alt};
  if (classes != null) {
    attrs['class'] = classes;
  }
  if (loading != null) {
    attrs['loading'] = loading;
  }

  return _el('img', attrs: attrs);
}

Component _text(String value) => Component.text(value);

Component _el(
  String tag, {
  Map<String, String?> attrs = const {},
  List<Component> children = const [],
}) {
  final resolved = <String, String>{};
  for (final entry in attrs.entries) {
    final value = entry.value;
    if (value != null && value.isNotEmpty) {
      resolved[entry.key] = value;
    }
  }

  return Component.element(tag: tag, attributes: resolved, children: children);
}
