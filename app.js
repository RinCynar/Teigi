const REPOSITORY = "RinCynar/Teigi";
const RELEASE_MANIFEST = "./release.json";
const supportedLocales = ["zh", "en", "ja"];
const localeInfo = {
  zh: { html: "zh-CN", intl: "zh-CN" },
  en: { html: "en", intl: "en-US" },
  ja: { html: "ja", intl: "ja-JP" },
};

const translations = {
  zh: {
    "meta.description": "Teigi 是一个基于 Flutter 和 FFmpeg 的桌面媒体转换工具",
    "nav.label": "主导航",
    "nav.downloads": "下载",
    "nav.github": "打开 GitHub 仓库",
    "language.label": "语言",
    "theme.toggle": "切换主题",
    "theme.switchToLight": "切换到浅色主题",
    "theme.switchToDark": "切换到深色主题",
    "hero.eyebrow": "开源桌面工具",
    "hero.copy": "安静、清晰地处理你的音频、视频与图片文件。",
    "status.loadingManifest": "正在读取版本清单",
    "status.loadingLatest": "正在读取最新 Release",
    "status.synced": "已同步最新 Release",
    "status.failed": "Release 同步失败",
    "release.latest": "最新发布",
    "release.connecting": "正在连接 GitHub",
    "release.syncing": "稍等片刻，正在同步版本信息。",
    "release.view": "查看 Release",
    "release.publishedMeta": ({ date, count }) => `发布于 ${date} · ${count} 个下载文件`,
    "common.loading": "读取中",
    "common.unknown": "未知",
    "downloads.eyebrow": "Release 文件",
    "downloads.title": "下载文件",
    "downloads.syncing": "文件将从版本清单自动同步。",
    "downloads.refresh": "刷新",
    "downloads.loading": "正在加载下载文件",
    "downloads.summary": ({ count }) => `${count} 个文件，按 Windows 架构整理。`,
    "aside.releaseInfo": "版本信息",
    "facts.version": "发布版本",
    "facts.date": "发布日期",
    "facts.assets": "可用文件",
    "facts.assetCount": ({ count }) => `${count} 个`,
    "project.title": "项目",
    "project.repository": "GitHub 仓库",
    "project.releases": "全部 Releases",
    "footer.product": "Teigi · 开源桌面媒体转换工具",
    "footer.manifest": "Release 清单由仓库工作流自动同步",
    "asset.architecture.x64": "x64",
    "asset.architecture.arm64": "arm64",
    "asset.architecture.generic": "通用",
    "asset.fileType.installer": "安装程序",
    "asset.fileType.archive": "压缩包",
    "asset.fileType.file": "文件",
    "asset.ffmpeg.optional": "安装时可选 FFmpeg",
    "asset.ffmpeg.bundled": "内置 FFmpeg",
    "asset.ffmpeg.none": "不含 FFmpeg",
    "asset.download": "下载",
    "asset.downloadAria": ({ name }) => `下载 ${name}`,
    "asset.sizeUnknown": "大小未知",
    "group.other": "其他文件",
    "group.windows": ({ architecture }) => `Windows · ${architecture}`,
    "errors.manifestMissingTitle": "Release 清单尚未生成",
    "errors.noReleaseTitle": "还没有可用的 Release",
    "errors.manifestErrorTitle": "暂时无法读取 Release 清单",
    "errors.manifestMissingCopy": "仓库工作流正在生成版本清单，请稍后刷新页面。",
    "errors.noReleaseCopy": "发布第一个 GitHub Release 后，下载文件会自动出现在这里。",
    "errors.manifestErrorCopy": "清单文件暂时无法读取，请稍后重试或直接打开仓库。",
    "errors.noVersion": "暂无版本",
    "errors.notSynced": "Release 数据尚未同步。",
    "errors.noFiles": "没有可显示的下载文件。",
    "errors.emptyTitle": "这个 Release 没有可下载文件",
    "errors.emptyCopy": "请前往 GitHub Release 页面查看版本详情。",
    "errors.retry": "重新读取",
  },
  en: {
    "meta.description": "Teigi is a desktop media converter built with Flutter and FFmpeg",
    "nav.label": "Main navigation",
    "nav.downloads": "Downloads",
    "nav.github": "Open GitHub repository",
    "language.label": "Language",
    "theme.toggle": "Toggle theme",
    "theme.switchToLight": "Switch to light theme",
    "theme.switchToDark": "Switch to dark theme",
    "hero.eyebrow": "Open-source desktop tool",
    "hero.copy": "Process your audio, video, and image files with clarity and control.",
    "status.loadingManifest": "Reading release manifest",
    "status.loadingLatest": "Reading latest Release",
    "status.synced": "Latest Release synced",
    "status.failed": "Release sync failed",
    "release.latest": "Latest release",
    "release.connecting": "Connecting to GitHub",
    "release.syncing": "Please wait while version information is synchronized.",
    "release.view": "View Release",
    "release.publishedMeta": ({ date, count }) => `Published ${date} · ${count} download ${count === 1 ? "file" : "files"}`,
    "common.loading": "Loading",
    "common.unknown": "Unknown",
    "downloads.eyebrow": "Release assets",
    "downloads.title": "Download files",
    "downloads.syncing": "Files will be synchronized from the release manifest.",
    "downloads.refresh": "Refresh",
    "downloads.loading": "Loading download files",
    "downloads.summary": ({ count }) => `${count} ${count === 1 ? "file" : "files"}, organized by Windows architecture.`,
    "aside.releaseInfo": "Release information",
    "facts.version": "Release version",
    "facts.date": "Release date",
    "facts.assets": "Available files",
    "facts.assetCount": ({ count }) => `${count}`,
    "project.title": "Project",
    "project.repository": "GitHub repository",
    "project.releases": "All Releases",
    "footer.product": "Teigi · Open-source desktop media converter",
    "footer.manifest": "Release manifest synchronized by the repository workflow",
    "asset.architecture.x64": "x64",
    "asset.architecture.arm64": "arm64",
    "asset.architecture.generic": "Universal",
    "asset.fileType.installer": "Installer",
    "asset.fileType.archive": "Archive",
    "asset.fileType.file": "File",
    "asset.ffmpeg.optional": "FFmpeg selectable during setup",
    "asset.ffmpeg.bundled": "FFmpeg included",
    "asset.ffmpeg.none": "FFmpeg not included",
    "asset.download": "Download",
    "asset.downloadAria": ({ name }) => `Download ${name}`,
    "asset.sizeUnknown": "Size unknown",
    "group.other": "Other files",
    "group.windows": ({ architecture }) => `Windows · ${architecture}`,
    "errors.manifestMissingTitle": "Release manifest is not ready",
    "errors.noReleaseTitle": "No Release is available yet",
    "errors.manifestErrorTitle": "Unable to read the Release manifest",
    "errors.manifestMissingCopy": "The repository workflow is generating the release manifest. Refresh in a moment.",
    "errors.noReleaseCopy": "Download files will appear here after the first GitHub Release is published.",
    "errors.manifestErrorCopy": "The manifest could not be read. Try again later or open the repository directly.",
    "errors.noVersion": "No version",
    "errors.notSynced": "Release data has not been synchronized.",
    "errors.noFiles": "No download files to display.",
    "errors.emptyTitle": "This Release has no downloadable files",
    "errors.emptyCopy": "Open the GitHub Release page to view its details.",
    "errors.retry": "Retry",
  },
  ja: {
    "meta.description": "Teigi は Flutter と FFmpeg で作られたデスクトップメディア変換ツールです",
    "nav.label": "メインナビゲーション",
    "nav.downloads": "ダウンロード",
    "nav.github": "GitHub リポジトリを開く",
    "language.label": "言語",
    "theme.toggle": "テーマを切り替え",
    "theme.switchToLight": "ライトテーマに切り替え",
    "theme.switchToDark": "ダークテーマに切り替え",
    "hero.eyebrow": "オープンソースのデスクトップツール",
    "hero.copy": "音声、動画、画像ファイルをシンプルかつ明快に処理できます。",
    "status.loadingManifest": "リリース一覧を読み込み中",
    "status.loadingLatest": "最新 Release を読み込み中",
    "status.synced": "最新 Release を同期しました",
    "status.failed": "Release の同期に失敗しました",
    "release.latest": "最新リリース",
    "release.connecting": "GitHub に接続中",
    "release.syncing": "バージョン情報を同期しています。",
    "release.view": "Release を見る",
    "release.publishedMeta": ({ date, count }) => `${date} に公開 · ダウンロード ${count} 件`,
    "common.loading": "読み込み中",
    "common.unknown": "不明",
    "downloads.eyebrow": "リリースファイル",
    "downloads.title": "ダウンロードファイル",
    "downloads.syncing": "ファイルはリリース一覧から自動的に同期されます。",
    "downloads.refresh": "更新",
    "downloads.loading": "ダウンロードファイルを読み込み中",
    "downloads.summary": ({ count }) => `${count} 件のファイルを Windows アーキテクチャ別に表示しています。`,
    "aside.releaseInfo": "バージョン情報",
    "facts.version": "リリースバージョン",
    "facts.date": "リリース日",
    "facts.assets": "利用可能なファイル",
    "facts.assetCount": ({ count }) => `${count} 件`,
    "project.title": "プロジェクト",
    "project.repository": "GitHub リポジトリ",
    "project.releases": "すべての Releases",
    "footer.product": "Teigi · オープンソースのデスクトップメディア変換ツール",
    "footer.manifest": "リリース一覧はリポジトリのワークフローで自動同期されます",
    "asset.architecture.x64": "x64",
    "asset.architecture.arm64": "arm64",
    "asset.architecture.generic": "共通",
    "asset.fileType.installer": "インストーラー",
    "asset.fileType.archive": "アーカイブ",
    "asset.fileType.file": "ファイル",
    "asset.ffmpeg.optional": "インストール時に FFmpeg を選択可能",
    "asset.ffmpeg.bundled": "FFmpeg 内蔵",
    "asset.ffmpeg.none": "FFmpeg なし",
    "asset.download": "ダウンロード",
    "asset.downloadAria": ({ name }) => `${name} をダウンロード`,
    "asset.sizeUnknown": "サイズ不明",
    "group.other": "その他のファイル",
    "group.windows": ({ architecture }) => `Windows · ${architecture}`,
    "errors.manifestMissingTitle": "リリース一覧はまだ生成されていません",
    "errors.noReleaseTitle": "利用可能な Release はありません",
    "errors.manifestErrorTitle": "Release 一覧を読み込めません",
    "errors.manifestMissingCopy": "リポジトリのワークフローがリリース一覧を生成しています。少し待ってから更新してください。",
    "errors.noReleaseCopy": "最初の GitHub Release が公開されると、ダウンロードファイルがここに表示されます。",
    "errors.manifestErrorCopy": "リリース一覧を読み込めませんでした。後でもう一度試すか、リポジトリを直接開いてください。",
    "errors.noVersion": "バージョンなし",
    "errors.notSynced": "Release データはまだ同期されていません。",
    "errors.noFiles": "表示できるダウンロードファイルはありません。",
    "errors.emptyTitle": "この Release にはダウンロードファイルがありません",
    "errors.emptyCopy": "GitHub Release ページでバージョンの詳細を確認してください。",
    "errors.retry": "再読み込み",
  },
};

const elements = {
  syncStatus: document.querySelector("#sync-status"),
  releaseHeading: document.querySelector("#release-heading"),
  releaseTag: document.querySelector("#release-tag"),
  releaseMeta: document.querySelector("#release-meta"),
  releaseNotes: document.querySelector("#release-notes"),
  releaseLink: document.querySelector("#release-link"),
  assetsSummary: document.querySelector("#assets-summary"),
  downloadList: document.querySelector("#download-list"),
  refreshButton: document.querySelector("#refresh-button"),
  factVersion: document.querySelector("#fact-version"),
  factDate: document.querySelector("#fact-date"),
  factAssets: document.querySelector("#fact-assets"),
  themeToggle: document.querySelector("#theme-toggle"),
  languageSelect: document.querySelector("#language-select"),
};

const themeStorageKey = "teigi-pages-theme";
const languageStorageKey = "teigi-pages-language";
let currentLocale = "en";
let latestRelease = null;
let latestError = null;
let syncState = {
  state: "loading",
  messageKey: "status.loadingManifest",
  icon: "loader-circle",
};

function t(key, values = {}) {
  const entry = translations[currentLocale]?.[key] ?? translations.en[key];
  if (typeof entry === "function") return entry(values);
  if (typeof entry !== "string") return key;
  return entry.replace(/\{\{(\w+)\}\}/g, (_, name) => values[name] ?? "");
}

function initializeIcons() {
  if (window.lucide) {
    window.lucide.createIcons({ attrs: { "stroke-width": 2 } });
  }
}

function setSyncStatus(state, messageKey, icon) {
  syncState = { state, messageKey, icon };
  elements.syncStatus.dataset.state = state;
  elements.syncStatus.replaceChildren();
  const iconElement = document.createElement("i");
  iconElement.dataset.lucide = icon;
  iconElement.setAttribute("aria-hidden", "true");
  const messageElement = document.createElement("span");
  messageElement.textContent = t(messageKey);
  elements.syncStatus.append(iconElement, messageElement);
  initializeIcons();
}

function formatDate(value) {
  if (!value) return t("common.unknown");
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return t("common.unknown");
  return new Intl.DateTimeFormat(localeInfo[currentLocale].intl, {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(date);
}

function formatBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes <= 0) return t("asset.sizeUnknown");
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  const digits = unit === 0 ? 0 : value >= 100 ? 0 : value >= 10 ? 1 : 2;
  const formatted = new Intl.NumberFormat(localeInfo[currentLocale].intl, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value);
  return `${formatted} ${units[unit]}`;
}

function getAssetInfo(asset) {
  const name = asset.name.toLowerCase();
  const architecture = name.includes("arm64") || name.includes("aarch64")
    ? "arm64"
    : name.includes("x64") || name.includes("amd64") || name.includes("win64")
      ? "x64"
      : "generic";
  const isInstaller = name.includes("installer") || name.endsWith(".exe");
  const bundledFfmpeg = name.includes("ffmpeg");
  const ffmpegMode = isInstaller
    ? "optional"
    : bundledFfmpeg
      ? "bundled"
      : "none";
  const isArchive = /\.(zip|7z|tar\.gz|dmg|pkg|deb|appimage)$/i.test(name);
  const fileType = isInstaller ? "installer" : isArchive ? "archive" : "file";

  return {
    architecture,
    ffmpegMode,
    fileType,
    sortKey: `${architecture === "x64" ? "0" : architecture === "arm64" ? "1" : "2"}-${ffmpegMode === "optional" ? "0" : ffmpegMode === "none" ? "1" : "2"}`,
  };
}

function createIcon(name) {
  const icon = document.createElement("i");
  icon.dataset.lucide = name;
  icon.setAttribute("aria-hidden", "true");
  return icon;
}

function makeTag(label, accent = false) {
  const tag = document.createElement("span");
  tag.className = accent ? "asset-tag accent" : "asset-tag";
  tag.textContent = label;
  return tag;
}

function renderAsset(asset) {
  const info = getAssetInfo(asset);
  const row = document.createElement("article");
  row.className = "download-row";

  const icon = document.createElement("div");
  icon.className = "asset-icon";
  icon.append(createIcon(info.fileType === "installer" ? "app-window" : "file-archive"));

  const main = document.createElement("div");
  main.className = "asset-main";
  const name = document.createElement("div");
  name.className = "asset-name";
  name.textContent = asset.name;
  const meta = document.createElement("div");
  meta.className = "asset-meta";
  meta.append(
    makeTag(t(`asset.architecture.${info.architecture}`), info.architecture !== "generic"),
    makeTag(t(`asset.ffmpeg.${info.ffmpegMode}`)),
  );
  const details = document.createElement("span");
  details.textContent = `${t(`asset.fileType.${info.fileType}`)} · ${formatBytes(asset.size)}`;
  meta.append(details);
  main.append(name, meta);

  const download = document.createElement("a");
  download.className = "download-button";
  download.href = asset.browser_download_url;
  download.target = "_blank";
  download.rel = "noreferrer";
  download.setAttribute("download", asset.name);
  download.setAttribute("aria-label", t("asset.downloadAria", { name: asset.name }));
  download.append(createIcon("download"));
  const downloadLabel = document.createElement("span");
  downloadLabel.textContent = t("asset.download");
  download.append(downloadLabel);

  row.append(icon, main, download);
  return { row, info };
}

function renderAssets(assets) {
  elements.downloadList.replaceChildren();
  if (!assets.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.append(createIcon("package-open"));
    const title = document.createElement("strong");
    title.textContent = t("errors.emptyTitle");
    const copy = document.createElement("p");
    copy.textContent = t("errors.emptyCopy");
    empty.append(title, copy);
    elements.downloadList.append(empty);
    initializeIcons();
    return;
  }

  const groups = new Map();
  const sortedAssets = [...assets].sort((a, b) => {
    return getAssetInfo(a).sortKey.localeCompare(getAssetInfo(b).sortKey) || a.name.localeCompare(b.name);
  });

  for (const asset of sortedAssets) {
    const info = getAssetInfo(asset);
    const groupName = info.architecture === "generic"
      ? t("group.other")
      : t("group.windows", { architecture: t(`asset.architecture.${info.architecture}`) });
    if (!groups.has(groupName)) groups.set(groupName, []);
    groups.get(groupName).push(asset);
  }

  for (const [groupName, groupAssets] of groups) {
    const group = document.createElement("section");
    group.className = "download-group";
    const heading = document.createElement("div");
    heading.className = "group-heading";
    const title = document.createElement("span");
    title.textContent = groupName;
    const count = document.createElement("span");
    count.className = "group-count";
    count.textContent = t("facts.assetCount", { count: groupAssets.length });
    heading.append(title, count);
    group.append(heading);

    for (const asset of groupAssets) {
      group.append(renderAsset(asset).row);
    }
    elements.downloadList.append(group);
  }

  initializeIcons();
}

function excerptReleaseNotes(body) {
  if (!body) return "";
  const text = body.replace(/[#*_>`]/g, "").replace(/\s+/g, " ").trim();
  return text.length > 180 ? `${text.slice(0, 180)}…` : text;
}

function renderRelease(release) {
  const tag = release.tag_name || t("common.unknown");
  const title = release.name || tag;
  const date = formatDate(release.published_at || release.created_at);
  const assets = Array.isArray(release.assets) ? release.assets : [];
  const notes = excerptReleaseNotes(release.body);

  elements.releaseHeading.textContent = title;
  elements.releaseTag.textContent = tag;
  elements.releaseMeta.textContent = t("release.publishedMeta", { date, count: assets.length });
  elements.releaseNotes.textContent = notes;
  elements.releaseNotes.hidden = !notes;
  elements.releaseLink.href = release.html_url || `https://github.com/${REPOSITORY}/releases`;
  elements.releaseLink.classList.remove("disabled");
  elements.releaseLink.removeAttribute("aria-disabled");
  elements.assetsSummary.textContent = t("downloads.summary", { count: assets.length });
  elements.factVersion.textContent = tag;
  elements.factDate.textContent = date;
  elements.factAssets.textContent = t("facts.assetCount", { count: assets.length });
  renderAssets(assets);
}

function renderLoadError(error) {
  const isManifestMissing = error && error.code === "manifest-missing";
  const isNoRelease = error && error.code === "no-release";
  const title = isManifestMissing
    ? t("errors.manifestMissingTitle")
    : isNoRelease
      ? t("errors.noReleaseTitle")
      : t("errors.manifestErrorTitle");
  const copy = isManifestMissing
    ? t("errors.manifestMissingCopy")
    : isNoRelease
      ? t("errors.noReleaseCopy")
      : t("errors.manifestErrorCopy");

  elements.releaseHeading.textContent = title;
  elements.releaseTag.textContent = t("errors.noVersion");
  elements.releaseMeta.textContent = t("errors.notSynced");
  elements.releaseNotes.hidden = true;
  elements.releaseLink.classList.add("disabled");
  elements.releaseLink.setAttribute("aria-disabled", "true");
  elements.assetsSummary.textContent = t("errors.noFiles");
  elements.factVersion.textContent = "—";
  elements.factDate.textContent = "—";
  elements.factAssets.textContent = "—";
  elements.downloadList.replaceChildren();

  const state = document.createElement("div");
  state.className = "error-state";
  state.append(createIcon(isManifestMissing || isNoRelease ? "calendar-off" : "cloud-off"));
  const stateTitle = document.createElement("strong");
  stateTitle.textContent = title;
  const stateCopy = document.createElement("p");
  stateCopy.textContent = copy;
  const retry = document.createElement("button");
  retry.className = "outlined-button";
  retry.type = "button";
  retry.append(createIcon("refresh-cw"));
  const retryLabel = document.createElement("span");
  retryLabel.textContent = t("errors.retry");
  retry.append(retryLabel);
  retry.addEventListener("click", loadLatestRelease);
  state.append(stateTitle, stateCopy, retry);
  elements.downloadList.append(state);
  initializeIcons();
}

async function loadLatestRelease() {
  elements.refreshButton.disabled = true;
  elements.refreshButton.classList.add("is-loading");
  latestRelease = null;
  latestError = null;
  setSyncStatus("loading", "status.loadingLatest", "loader-circle");
  elements.assetsSummary.textContent = t("downloads.syncing");
  elements.downloadList.innerHTML = `
    <div class="loading-list" aria-label="${t("downloads.loading")}">
      <div class="loading-row"></div>
      <div class="loading-row"></div>
    </div>`;

  try {
    const response = await fetch(`${RELEASE_MANIFEST}?t=${Date.now()}`, {
      cache: "no-store",
    });
    if (!response.ok) {
      const error = new Error(`Release manifest returned ${response.status}`);
      error.status = response.status;
      error.code = response.status === 404 ? "manifest-missing" : "manifest-error";
      throw error;
    }
    const manifest = await response.json();
    if (!manifest.release) {
      const error = new Error("No published release found");
      error.code = "no-release";
      throw error;
    }
    latestRelease = {
      tag_name: manifest.release.tagName,
      name: manifest.release.name,
      body: manifest.release.body,
      published_at: manifest.release.publishedAt,
      created_at: manifest.release.createdAt,
      html_url: manifest.release.htmlUrl,
      assets: Array.isArray(manifest.release.assets)
        ? manifest.release.assets.map((asset) => ({
            name: asset.name,
            size: asset.size,
            browser_download_url: asset.browserDownloadUrl,
          }))
        : [],
    };
    renderRelease(latestRelease);
    setSyncStatus("success", "status.synced", "check-circle-2");
  } catch (error) {
    console.error(error);
    latestError = error;
    renderLoadError(error);
    setSyncStatus("error", "status.failed", "circle-alert");
  } finally {
    elements.refreshButton.disabled = false;
    elements.refreshButton.classList.remove("is-loading");
  }
}

function applyTranslations() {
  document.documentElement.lang = localeInfo[currentLocale].html;
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    element.textContent = t(element.dataset.i18n);
  });
  document.querySelectorAll("[data-i18n-content]").forEach((element) => {
    element.setAttribute("content", t(element.dataset.i18nContent));
  });
  document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    element.setAttribute("aria-label", t(element.dataset.i18nAriaLabel));
  });
  document.querySelectorAll("[data-i18n-title]").forEach((element) => {
    element.setAttribute("title", t(element.dataset.i18nTitle));
  });
  elements.languageSelect.value = currentLocale;
}

function normalizeLocale(value) {
  const language = String(value || "").toLowerCase();
  if (language.startsWith("zh")) return "zh";
  if (language.startsWith("ja")) return "ja";
  return "en";
}

function applyLocale(locale) {
  currentLocale = supportedLocales.includes(locale) ? locale : "en";
  applyTranslations();
  if (latestRelease) renderRelease(latestRelease);
  if (latestError) renderLoadError(latestError);
  setSyncStatus(syncState.state, syncState.messageKey, syncState.icon);
}

function initializeLocale() {
  const saved = localStorage.getItem(languageStorageKey);
  const browserLanguage = navigator.languages?.[0] || navigator.language;
  applyLocale(supportedLocales.includes(saved) ? saved : normalizeLocale(browserLanguage));
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  const isDark = theme === "dark";
  elements.themeToggle.replaceChildren(createIcon(isDark ? "sun" : "moon"));
  const label = isDark ? t("theme.switchToLight") : t("theme.switchToDark");
  elements.themeToggle.setAttribute("aria-label", label);
  elements.themeToggle.title = label;
  initializeIcons();
}

function initializeTheme() {
  const saved = localStorage.getItem(themeStorageKey);
  if (saved === "light" || saved === "dark") {
    applyTheme(saved);
    return;
  }
  applyTheme(window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
}

elements.refreshButton.addEventListener("click", loadLatestRelease);
elements.languageSelect.addEventListener("change", (event) => {
  const nextLocale = supportedLocales.includes(event.target.value) ? event.target.value : "en";
  localStorage.setItem(languageStorageKey, nextLocale);
  applyLocale(nextLocale);
});
elements.themeToggle.addEventListener("click", () => {
  const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  localStorage.setItem(themeStorageKey, next);
  applyTheme(next);
});

initializeLocale();
initializeTheme();
initializeIcons();
loadLatestRelease();
