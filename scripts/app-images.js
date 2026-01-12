const PLATFORM_CONFIG = [
  { key: "tvos", folder: "tvOS", label: "tvOS" },
  { key: "macos", folder: "macOS", label: "macOS" },
  { key: "ios", folder: "iOS", label: "iOS" },
];

const IMAGE_EXTENSIONS = new Set(["png", "jpg", "jpeg", "webp", "gif", "avif"]);

function isImageFilename(filename) {
  if (!filename || filename.startsWith(".")) return false;
  const parts = filename.split(".");
  if (parts.length < 2) return false;
  const ext = parts.at(-1).toLowerCase();
  return IMAGE_EXTENSIONS.has(ext);
}

function baseName(filename) {
  return filename.replace(/\.[^.]+$/, "");
}

function naturalSort(items) {
  const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" });
  return [...items].sort((a, b) => collator.compare(a, b));
}

function inferGitHubRepo() {
  const metaOwner = document.querySelector('meta[name="github-owner"]')?.getAttribute("content");
  const metaRepo = document.querySelector('meta[name="github-repo"]')?.getAttribute("content");
  if (metaOwner && metaRepo) return { owner: metaOwner, repo: metaRepo };

  const { hostname, pathname } = window.location;
  if (!hostname.endsWith(".github.io")) return null;

  const owner = hostname.split(".")[0];
  const segments = pathname.split("/").filter(Boolean);
  const repo = segments.length === 0 ? `${owner}.github.io` : segments[0];
  return { owner, repo };
}

function normalizePlatformKey(value) {
  if (!value) return null;
  const cleaned = String(value).trim().toLowerCase();
  return PLATFORM_CONFIG.some(({ key }) => key === cleaned) ? cleaned : null;
}

function applyInitialPlatformSelection() {
  const params = new URLSearchParams(window.location.search);
  const preview = normalizePlatformKey(params.get("preview"));
  const gallery = normalizePlatformKey(params.get("gallery"));

  if (preview) {
    const input = document.getElementById(`preview-${preview}`);
    if (input && input instanceof HTMLInputElement) input.checked = true;
  }

  if (gallery) {
    const input = document.getElementById(`gallery-${gallery}`);
    if (input && input instanceof HTMLInputElement) input.checked = true;
  }
}

function getCheckedPlatform(prefix, fallbackKey) {
  const input = document.querySelector(`input[id^="${prefix}-"]:checked`);
  if (!input || !(input instanceof HTMLInputElement)) return fallbackKey;
  const key = input.id.replace(`${prefix}-`, "");
  return normalizePlatformKey(key) ?? fallbackKey;
}

async function listGitHubDir({ owner, repo, path }) {
  const url = `https://api.github.com/repos/${owner}/${repo}/contents/${path}`;
  const response = await fetch(url, {
    headers: {
      Accept: "application/vnd.github+json",
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to list ${path}: ${response.status} ${response.statusText}`);
  }

  const data = await response.json();
  if (!Array.isArray(data)) return [];

  return data
    .filter((item) => item && item.type === "file" && typeof item.name === "string")
    .map((item) => item.name);
}

function buildImageItems({ folder, label, filenames, optimizedWebpNames }) {
  const sorted = naturalSort(filenames.filter(isImageFilename));
  return sorted.map((name, index) => {
    const originalSrc = `AppImages/${folder}/${name}`;
    const optimizedName = `${folder}-${baseName(name)}.webp`;
    const optimizedSrc = optimizedWebpNames.has(optimizedName) ? `AppImages/web/${optimizedName}` : null;

    return {
      originalSrc,
      src: optimizedSrc ?? originalSrc,
      alt: `${label} screenshot ${index + 1}`,
    };
  });
}

function setImageWithFallback(img, preferredSrc, fallbackSrc) {
  img.src = preferredSrc;
  if (preferredSrc === fallbackSrc) return;

  img.addEventListener(
    "error",
    () => {
      img.src = fallbackSrc;
    },
    { once: true },
  );
}

function renderCarousel(root, items, { active } = { active: false }) {
  if (!root) return;

  const viewport = root.querySelector(".carousel-viewport");
  const prevBtn = root.querySelector(".carousel-btn.prev");
  const nextBtn = root.querySelector(".carousel-btn.next");
  const dots = root.querySelector(".carousel-dots");

  if (!viewport || !prevBtn || !nextBtn || !dots) return;

  root.classList.toggle("is-empty", items.length === 0);
  root.classList.toggle("is-single", items.length <= 1);

  viewport.innerHTML = "";
  dots.innerHTML = "";

  if (items.length === 0) {
    const empty = document.createElement("div");
    empty.className = "carousel-empty";
    empty.textContent = "No screenshots found.";
    viewport.appendChild(empty);
    prevBtn.disabled = true;
    nextBtn.disabled = true;
    return;
  }

  items.forEach((item, index) => {
    const slide = document.createElement("a");
    slide.className = "carousel-slide";
    slide.href = item.originalSrc;
    slide.target = "_blank";
    slide.rel = "noopener noreferrer";

    const img = document.createElement("img");
    img.alt = item.alt;
    img.decoding = "async";
    img.loading = active && index === 0 ? "eager" : "lazy";
    if (active && index === 0) img.setAttribute("fetchpriority", "high");
    setImageWithFallback(img, item.src, item.originalSrc);

    slide.appendChild(img);
    viewport.appendChild(slide);

    const dot = document.createElement("button");
    dot.type = "button";
    dot.className = "carousel-dot";
    dot.setAttribute("aria-label", `Go to screenshot ${index + 1} of ${items.length}`);
    dot.addEventListener("click", () => scrollToIndex(index));
    dots.appendChild(dot);
  });

  const slides = () => Array.from(viewport.querySelectorAll(".carousel-slide"));

  const getIndex = () => {
    const width = viewport.clientWidth || 1;
    const idx = Math.round(viewport.scrollLeft / width);
    return Math.min(Math.max(idx, 0), items.length - 1);
  };

  const setActiveDot = (index) => {
    Array.from(dots.children).forEach((child, i) => {
      if (!(child instanceof HTMLElement)) return;
      if (i === index) child.setAttribute("aria-current", "true");
      else child.removeAttribute("aria-current");
    });
  };

  const updateControls = () => {
    const idx = getIndex();
    setActiveDot(idx);
    prevBtn.disabled = idx <= 0;
    nextBtn.disabled = idx >= items.length - 1;
  };

  function scrollToIndex(index) {
    const slideEls = slides();
    const target = slideEls[index];
    if (!target) return;
    viewport.scrollTo({ left: target.offsetLeft, behavior: "smooth" });
  }

  prevBtn.addEventListener("click", () => scrollToIndex(getIndex() - 1));
  nextBtn.addEventListener("click", () => scrollToIndex(getIndex() + 1));

  let raf = 0;
  viewport.addEventListener("scroll", () => {
    if (raf) return;
    raf = window.requestAnimationFrame(() => {
      raf = 0;
      updateControls();
    });
  });

  viewport.addEventListener("keydown", (event) => {
    if (!(event instanceof KeyboardEvent)) return;
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      scrollToIndex(getIndex() - 1);
    }
    if (event.key === "ArrowRight") {
      event.preventDefault();
      scrollToIndex(getIndex() + 1);
    }
  });

  viewport.scrollLeft = 0;
  updateControls();
}

function renderGalleryGrid(container, items, { active } = { active: false }) {
  if (!container) return;
  container.innerHTML = "";

  if (items.length === 0) {
    const empty = document.createElement("p");
    empty.className = "gallery-empty";
    empty.textContent = "No screenshots found.";
    container.appendChild(empty);
    return;
  }

  items.forEach((item, index) => {
    const shot = document.createElement("a");
    shot.className = "gallery-shot";
    shot.href = item.originalSrc;
    shot.target = "_blank";
    shot.rel = "noopener noreferrer";

    const img = document.createElement("img");
    img.alt = item.alt;
    img.decoding = "async";
    img.loading = active && index < 3 ? "eager" : "lazy";
    setImageWithFallback(img, item.src, item.originalSrc);

    shot.appendChild(img);
    container.appendChild(shot);
  });
}

async function init() {
  applyInitialPlatformSelection();

  const repoInfo = inferGitHubRepo();
  if (!repoInfo) return;

  const activePreview = getCheckedPlatform("preview", "tvos");
  const activeGallery = getCheckedPlatform("gallery", "tvos");

  const optimizedWebpNames = new Set();
  try {
    const webFiles = await listGitHubDir({ ...repoInfo, path: "AppImages/web" });
    webFiles.filter((name) => name.toLowerCase().endsWith(".webp")).forEach((name) => optimizedWebpNames.add(name));
  } catch {
    // Optional optimization directory; ignore failures.
  }

  const dirListings = await Promise.all(
    PLATFORM_CONFIG.map(async ({ folder }) => ({
      folder,
      files: await listGitHubDir({ ...repoInfo, path: `AppImages/${folder}` }),
    })),
  );

  const imagesByPlatform = Object.fromEntries(
    PLATFORM_CONFIG.map(({ key, folder, label }) => {
      const listing = dirListings.find((item) => item.folder === folder);
      const items = buildImageItems({
        folder,
        label,
        filenames: listing?.files ?? [],
        optimizedWebpNames,
      });
      return [key, items];
    }),
  );

  PLATFORM_CONFIG.forEach(({ key }) => {
    const carouselRoot = document.querySelector(`.preview-carousel[data-platform="${key}"]`);
    renderCarousel(carouselRoot, imagesByPlatform[key] ?? [], { active: key === activePreview });

    const galleryGrid = document.querySelector(`.gallery-grid[data-platform="${key}"]`);
    renderGalleryGrid(galleryGrid, imagesByPlatform[key] ?? [], { active: key === activeGallery });
  });
}

init().catch(() => {
  // Keep the page functional even if screenshots fail to load.
});
