const REPOSITORY = "RinCynar/Teigi";
const RELEASES_API = `https://api.github.com/repos/${REPOSITORY}/releases?per_page=20`;

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
};

const themeStorageKey = "teigi-pages-theme";

function initializeIcons() {
  if (window.lucide) {
    window.lucide.createIcons({ attrs: { "stroke-width": 2 } });
  }
}

function setSyncStatus(state, message, icon) {
  elements.syncStatus.dataset.state = state;
  elements.syncStatus.replaceChildren();
  const iconElement = document.createElement("i");
  iconElement.dataset.lucide = icon;
  iconElement.setAttribute("aria-hidden", "true");
  const messageElement = document.createElement("span");
  messageElement.textContent = message;
  elements.syncStatus.append(iconElement, messageElement);
  initializeIcons();
}

function formatDate(value) {
  if (!value) return "未知";
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date(value));
}

function formatBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "大小未知";
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  const digits = unit === 0 ? 0 : value >= 100 ? 0 : value >= 10 ? 1 : 2;
  return `${value.toFixed(digits)} ${units[unit]}`;
}

function getAssetInfo(asset) {
  const name = asset.name.toLowerCase();
  const architecture = name.includes("arm64") || name.includes("aarch64")
    ? "arm64"
    : name.includes("x64") || name.includes("amd64") || name.includes("win64")
      ? "x64"
      : "通用";
  const bundledFfmpeg = name.includes("ffmpeg");
  const isInstaller = name.includes("installer") || name.endsWith(".exe");
  const isArchive = /\.(zip|7z|tar\.gz|dmg|pkg|deb|appimage)$/i.test(name);
  const fileType = isInstaller ? "安装程序" : isArchive ? "压缩包" : "文件";

  return {
    architecture,
    bundledFfmpeg,
    fileType,
    sortKey: `${architecture === "x64" ? "0" : architecture === "arm64" ? "1" : "2"}-${bundledFfmpeg ? "1" : "0"}`,
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
  icon.append(createIcon(info.fileType === "安装程序" ? "app-window" : "file-archive"));

  const main = document.createElement("div");
  main.className = "asset-main";
  const name = document.createElement("div");
  name.className = "asset-name";
  name.textContent = asset.name;
  const meta = document.createElement("div");
  meta.className = "asset-meta";
  meta.append(
    makeTag(info.architecture, info.architecture !== "通用"),
    makeTag(info.bundledFfmpeg ? "内置 FFmpeg" : "不含 FFmpeg"),
  );
  const details = document.createElement("span");
  details.textContent = `${info.fileType} · ${formatBytes(asset.size)}`;
  meta.append(details);
  main.append(name, meta);

  const download = document.createElement("a");
  download.className = "download-button";
  download.href = asset.browser_download_url;
  download.target = "_blank";
  download.rel = "noreferrer";
  download.setAttribute("download", asset.name);
  download.setAttribute("aria-label", `下载 ${asset.name}`);
  download.append(createIcon("download"));
  const downloadLabel = document.createElement("span");
  downloadLabel.textContent = "下载";
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
    title.textContent = "这个 Release 没有可下载文件";
    const copy = document.createElement("p");
    copy.textContent = "请前往 GitHub Release 页面查看版本详情。";
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
    const groupName = info.architecture === "通用" ? "其他文件" : `Windows · ${info.architecture}`;
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
    count.textContent = `${groupAssets.length} 个文件`;
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
  const tag = release.tag_name || "未命名版本";
  const title = release.name || tag;
  const date = formatDate(release.published_at || release.created_at);
  const assets = Array.isArray(release.assets) ? release.assets : [];
  const notes = excerptReleaseNotes(release.body);

  elements.releaseHeading.textContent = title;
  elements.releaseTag.textContent = tag;
  elements.releaseMeta.textContent = `发布于 ${date} · ${assets.length} 个下载文件`;
  elements.releaseNotes.textContent = notes;
  elements.releaseNotes.hidden = !notes;
  elements.releaseLink.href = release.html_url || `https://github.com/${REPOSITORY}/releases`;
  elements.releaseLink.classList.remove("disabled");
  elements.releaseLink.removeAttribute("aria-disabled");
  elements.assetsSummary.textContent = `${assets.length} 个文件，按 Windows 架构整理。`;
  elements.factVersion.textContent = tag;
  elements.factDate.textContent = date;
  elements.factAssets.textContent = `${assets.length} 个`;
  renderAssets(assets);
}

function renderLoadError(error) {
  const isNotFound = error && error.status === 404;
  const title = isNotFound ? "还没有可用的 Release" : "暂时无法读取 Release";
  const copy = isNotFound
    ? "发布第一个 GitHub Release 后，下载文件会自动出现在这里。"
    : "GitHub API 可能暂时受限，请稍后重试或直接打开仓库。";

  elements.releaseHeading.textContent = title;
  elements.releaseTag.textContent = "暂无版本";
  elements.releaseMeta.textContent = "Release 数据尚未同步。";
  elements.releaseNotes.hidden = true;
  elements.releaseLink.classList.add("disabled");
  elements.releaseLink.setAttribute("aria-disabled", "true");
  elements.assetsSummary.textContent = "没有可显示的下载文件。";
  elements.factVersion.textContent = "—";
  elements.factDate.textContent = "—";
  elements.factAssets.textContent = "—";
  elements.downloadList.replaceChildren();

  const state = document.createElement("div");
  state.className = "error-state";
  state.append(createIcon(isNotFound ? "calendar-off" : "cloud-off"));
  const stateTitle = document.createElement("strong");
  stateTitle.textContent = title;
  const stateCopy = document.createElement("p");
  stateCopy.textContent = copy;
  const retry = document.createElement("button");
  retry.className = "outlined-button";
  retry.type = "button";
  retry.append(createIcon("refresh-cw"));
  const retryLabel = document.createElement("span");
  retryLabel.textContent = "重新读取";
  retry.append(retryLabel);
  retry.addEventListener("click", loadLatestRelease);
  state.append(stateTitle, stateCopy, retry);
  elements.downloadList.append(state);
  initializeIcons();
}

async function loadLatestRelease() {
  elements.refreshButton.disabled = true;
  elements.refreshButton.classList.add("is-loading");
  setSyncStatus("loading", "正在读取最新 Release", "loader-circle");
  elements.assetsSummary.textContent = "文件将从 GitHub 自动同步。";
  elements.downloadList.innerHTML = `
    <div class="loading-list" aria-label="正在加载下载文件">
      <div class="loading-row"></div>
      <div class="loading-row"></div>
    </div>`;

  try {
    const response = await fetch(RELEASES_API, {
      headers: { Accept: "application/vnd.github+json" },
      cache: "no-store",
    });
    if (!response.ok) {
      const error = new Error(`GitHub API returned ${response.status}`);
      error.status = response.status;
      throw error;
    }
    const releases = await response.json();
    const release = Array.isArray(releases)
      ? releases.find((candidate) => !candidate.draft)
      : null;
    if (!release) {
      const error = new Error("No published GitHub release found");
      error.status = 404;
      throw error;
    }
    renderRelease(release);
    setSyncStatus("success", "已同步最新 Release", "check-circle-2");
  } catch (error) {
    console.error(error);
    renderLoadError(error);
    setSyncStatus("error", "Release 同步失败", "circle-alert");
  } finally {
    elements.refreshButton.disabled = false;
    elements.refreshButton.classList.remove("is-loading");
  }
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  const isDark = theme === "dark";
  elements.themeToggle.replaceChildren(createIcon(isDark ? "sun" : "moon"));
  elements.themeToggle.setAttribute("aria-label", isDark ? "切换到浅色主题" : "切换到深色主题");
  elements.themeToggle.title = isDark ? "浅色主题" : "深色主题";
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
elements.themeToggle.addEventListener("click", () => {
  const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  localStorage.setItem(themeStorageKey, nextTheme);
  applyTheme(nextTheme);
});

initializeTheme();
initializeIcons();
loadLatestRelease();
