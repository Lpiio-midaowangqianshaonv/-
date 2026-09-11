# 房源记录与客户分析工具 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a mobile-first, installable PWA for privately recording property listings and matching them to customer profiles.

**Architecture:** `index.html` is a Vue 3 CDN single-page application with hash-free in-memory views for entry, listing, detail, and settings. A small IndexedDB repository persists listings and Blob media locally; `manifest.json` and `sw.js` make the otherwise self-contained app installable and cache its shell.

**Tech Stack:** HTML5, inline CSS/JavaScript, Vue 3 global CDN build, IndexedDB, Media Capture input attributes, High AMap JavaScript API 2.0.

**Spec:** User-approved chat design, 2026-09-12.

## Global Constraints

- Create exactly three deliverable files: `index.html`, `manifest.json`, and `sw.js`.
- Store every listing field, image, video, and analysis locally in IndexedDB; never send listing data to a server.
- Load Vue and AMap only from their public CDNs; the AMap key is user-entered and stored locally.
- Responsive controls must be finger-sized and work on modern mobile browsers.
- AMap use must fall back to a public map-search link if no valid key is configured.

---

### Task 1: Define app shell and install metadata

**Files:**
- Create: `index.html`
- Create: `manifest.json`
- Create: `sw.js`

**Interfaces:**
- Produces: `<div id="app">`, `window.__APP_VERSION__`, `navigator.serviceWorker.register('./sw.js')`.

- [ ] **Step 1: Write a browser-console smoke assertion before app code**

```js
console.assert(document.querySelector('#app'), 'app mount point is missing');
console.assert(document.querySelector('meta[name="theme-color"]'), 'theme color is missing');
```

- [ ] **Step 2: Verify the assertion fails in a blank HTML shell**

Run: open the blank shell in a browser and evaluate the two assertions.
Expected: the mount-point assertion fails.

- [ ] **Step 3: Build the minimal shell**

```html
<link rel="manifest" href="./manifest.json">
<meta name="theme-color" content="#0f766e">
<div id="app"></div>
<script>navigator.serviceWorker?.register('./sw.js');</script>
```

`manifest.json` supplies standalone display mode and app name. `sw.js` caches `./`, `./index.html`, and `./manifest.json` during install and answers same-origin cache hits before fetching.

- [ ] **Step 4: Verify the shell**

Run: serve the folder over `http://localhost` and use DevTools Application panel.
Expected: manifest is recognized and the service worker is activated.

### Task 2: Add testable listing model, analysis rules, and IndexedDB repository

**Files:**
- Modify: `index.html`

**Interfaces:**
- Produces: `analyzeListing(listing) -> {score, clients, advice, areaNote}`, `db.saveListing(listing)`, `db.listListings()`, `db.getListing(id)`, `db.deleteListing(id)`.

- [ ] **Step 1: Add a failing analysis test harness**

```js
const result = analyzeListing({ decoration:'精装', orientation:'南', area:55, floor:'12/28', address:'石厦路' });
console.assert(result.clients.includes('追求品质'), 'south-facing fine decoration should match quality clients');
console.assert(result.areaNote.includes('石厦片区'), 'Shixia address should produce area note');
```

- [ ] **Step 2: Verify failure before implementation**

Run: load the page and execute the harness before defining `analyzeListing`.
Expected: `ReferenceError: analyzeListing is not defined`.

- [ ] **Step 3: Implement model and repository**

Define one listing object with all requested fields, an `analysis` object, and `media: [{id, kind, name, type, blob}]`. Use `structuredClone`-safe fields and store each listing under its UUID in IndexedDB object store `listings`; media Blob records use store `media` keyed by media id.

Score rules: start at 45; add 20/10/2 for 精装/简装/老旧; add 15 for 南 or 东南; add 8 for middle floors and 4 for other stated floors; add 8 for 40–90㎡ and 4 otherwise; clamp 0–100. Implement all three requested client matches and default to “需求明确的租客”.

- [ ] **Step 4: Verify analysis and persistence**

Run: execute the harness plus save/list/get/delete calls in the browser console.
Expected: all assertions pass and saved records survive reload.

### Task 3: Build mobile entry flow and local media previews

**Files:**
- Modify: `index.html`

**Interfaces:**
- Consumes: `analyzeListing`, `db.saveListing`.
- Produces: `saveCurrentListing()`, `removeMedia(id)`, `previewUrl(media)`.

- [ ] **Step 1: Add a failing DOM behavior assertion**

```js
console.assert(document.querySelector('input[accept="image/*"][capture="environment"]'), 'camera image input is missing');
console.assert(document.querySelector('input[accept="video/*"][capture="environment"]'), 'camera video input is missing');
```

- [ ] **Step 2: Verify failure before building the form**

Run: inspect the existing shell in the browser.
Expected: both assertions fail.

- [ ] **Step 3: Implement entry UI**

Use Vue `v-model` controls for every requested listing field. Wire “拍照” and “录视频” labels to hidden file inputs with `capture="environment"`; convert selected files to Blob media records, render image/video previews via `URL.createObjectURL`, and revoke URLs when removed or component unmounts. Place “智能分析” before the result panel; saving validates 小区名称 and then persists the analysis with the listing.

- [ ] **Step 4: Verify mobile behavior**

Run: test with responsive DevTools and a selected image/video.
Expected: fields are operable at 375px width, previews render, delete removes each preview, and save survives reload.

### Task 4: Build list, filtering, detail, export, and maps

**Files:**
- Modify: `index.html`

**Interfaces:**
- Consumes: `db.listListings`, `db.getListing`, `db.deleteListing`.
- Produces: `filteredListings`, `openDetail(id)`, `exportAll()`, `openMap(listing)`.

- [ ] **Step 1: Add failing filter assertions**

```js
const matches = filterListings([{ layout:'1室1厅', decoration:'简装', rent:3200 }], { layout:'1室1厅', decoration:'简装', minRent:3000, maxRent:3500 });
console.assert(matches.length === 1, 'matching listing should remain after all filters');
```

- [ ] **Step 2: Verify the failure**

Run: execute the assertion before defining `filterListings`.
Expected: `ReferenceError: filterListings is not defined`.

- [ ] **Step 3: Implement list and detail views**

Render cards with 小区名称、户型、租金、装修、推荐客户类型. Filter by layout, decoration, and inclusive rental min/max values. Detail renders every field, analysis, and media previews. Export combines listings with media transformed to Base64 into a downloadable UTF-8 JSON Blob.

`openMap` uses the entered AMap key to load API 2.0, geocodes `深圳市 + address`, and adds a marker. If the address is empty use `114.055,22.517` (石厦 area); if the key is absent or loading fails, open `https://uri.amap.com/search?keyword=` with the encoded address or “深圳市福田区石厦”.

- [ ] **Step 4: Verify final paths**

Run: create two records with different rents/decorations, filter them, open a card, export, and invoke map fallback without a key.
Expected: each list/detail/export/map path works and the export JSON has no remote URLs for media.

### Task 5: Run static and runtime verification

**Files:**
- Modify: `index.html`, `manifest.json`, `sw.js` only if verification identifies a defect.

- [ ] **Step 1: Validate JavaScript syntax**

Run: extract inline JavaScript and run `node --check` against a temporary copy.
Expected: exit code 0.

- [ ] **Step 2: Validate PWA files**

Run: `python3 -m json.tool manifest.json >/dev/null` and inspect service-worker registration in a local HTTP server.
Expected: JSON valid and worker activated.

- [ ] **Step 3: Verify privacy boundary**

Run: search source for `fetch(` and verify it is only CDN/app-shell/AMap loading; inspect export implementation.
Expected: no listing or media upload code exists.

