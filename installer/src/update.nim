## GSD Update checker
## Checks GitHub API for new releases and caches result

import std/[httpclient, json, os, options, strutils, times]
import config, platform

const
  GitHubApiUrl = "https://api.github.com/repos/puremachinery/gsd/releases/latest"
  UserAgent = "gsd-cli/" & Version
  CacheFileName = "gsd-update-check.json"
  CacheTtlHours = 24
  HttpTimeoutMs = 15000 # 15 seconds - allows for slow connections

type
  UpdateCheckResult* = object
    currentVersion*: string
    latestVersion*: string
    updateAvailable*: bool
    releaseUrl*: string

proc getCachePath(configDir: string): string =
  result = getGsdCacheDir(configDir) / CacheFileName

proc isCacheValid(cachePath: string): bool =
  ## Check if cache exists and is less than CacheTtlHours old
  if not fileExists(cachePath):
    return false

  try:
    let content = readFile(cachePath)
    let json = parseJson(content)

    if json.hasKey("checked_at"):
      let checkedAt = json["checked_at"].getStr()
      let checkedTime = parse(checkedAt, "yyyy-MM-dd'T'HH:mm:ss'Z'", utc())
      let age = now().utc - checkedTime

      return age.inHours < CacheTtlHours
  except CatchableError:
    discard

  return false

proc loadCachedResult(cachePath: string): Option[UpdateCheckResult] =
  ## Load cached update check result
  if not fileExists(cachePath):
    return none(UpdateCheckResult)

  try:
    let content = readFile(cachePath)
    let json = parseJson(content)

    var cached = UpdateCheckResult()
    cached.currentVersion = json.getOrDefault("current_version").getStr("")
    cached.latestVersion = json.getOrDefault("latest_version").getStr("")
    cached.updateAvailable = json.getOrDefault("update_available").getBool(false)
    cached.releaseUrl = json.getOrDefault("release_url").getStr("")

    return some(cached)
  except CatchableError:
    return none(UpdateCheckResult)

proc loadCachedEtag(cachePath: string): string =
  ## Load cached ETag for conditional requests
  if not fileExists(cachePath):
    return ""
  try:
    let content = readFile(cachePath)
    let json = parseJson(content)
    return json.getOrDefault("etag").getStr("")
  except CatchableError:
    return ""

proc saveCacheResult(cachePath: string, result: UpdateCheckResult, etag: string = "") =
  ## Save update check result to cache
  let cacheDir = parentDir(cachePath)
  if not dirExists(cacheDir):
    try:
      createDir(cacheDir)
    except OSError:
      return

  let json = %*{
    "current_version": result.currentVersion,
    "latest_version": result.latestVersion,
    "update_available": result.updateAvailable,
    "release_url": result.releaseUrl,
    "checked_at": now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'"),
    "etag": etag
  }

  try:
    writeFile(cachePath, json.pretty())
  except IOError:
    discard

proc compareVersions*(current, latest: string): int =
  ## Compare semver versions. Returns:
  ## -1 if current < latest
  ##  0 if current == latest
  ##  1 if current > latest

  proc parseVersion(v: string): seq[int] =
    let clean = v.strip().strip(chars = {'v', 'V'})
    result = @[]
    for part in clean.split('.'):
      try:
        result.add(parseInt(part.split('-')[0])) # Handle pre-release tags
      except ValueError:
        result.add(0)
    # Pad to 3 parts
    while result.len < 3:
      result.add(0)

  let currentParts = parseVersion(current)
  let latestParts = parseVersion(latest)

  for i in 0..2:
    if currentParts[i] < latestParts[i]:
      return -1
    elif currentParts[i] > latestParts[i]:
      return 1

  return 0

type
  FetchResult = object
    version: string
    url: string
    etag: string
    notModified: bool

proc fetchLatestRelease(cachedEtag: string = ""): Option[FetchResult] =
  ## Fetch latest release info from GitHub API
  ## Uses ETag for conditional requests to reduce rate limit usage
  let client = newHttpClient(timeout = HttpTimeoutMs)
  defer: client.close()

  client.headers = newHttpHeaders({
    "User-Agent": UserAgent,
    "Accept": "application/vnd.github.v3+json"
  })

  # Add auth if available
  let token = getEnv("GITHUB_TOKEN")
  if token.len > 0:
    client.headers["Authorization"] = "Bearer " & token

  # Add ETag for conditional request (304 Not Modified saves rate limit)
  if cachedEtag.len > 0:
    client.headers["If-None-Match"] = cachedEtag

  try:
    let response = client.get(GitHubApiUrl)

    # 304 Not Modified - cache is still valid
    if response.status == "304" or response.status.startsWith("304"):
      return some(FetchResult(notModified: true))

    if response.status == "404" or response.status.startsWith("404"):
      # No releases published yet
      return none(FetchResult)

    if not response.status.startsWith("2"):
      # API error (rate limit, server error, etc.) - fail silently
      return none(FetchResult)

    let json = parseJson(response.body)
    let tagName = json["tag_name"].getStr()
    let htmlUrl = json["html_url"].getStr()

    # Extract ETag from response headers for future conditional requests
    var newEtag = ""
    if response.headers.hasKey("ETag"):
      newEtag = response.headers["ETag"]

    return some(FetchResult(
      version: tagName,
      url: htmlUrl,
      etag: newEtag,
      notModified: false
    ))
  except CatchableError:
    # Network error, timeout, parse error - fail silently
    return none(FetchResult)

proc checkForUpdate*(configDir: string = "", forceCheck: bool = false): Option[UpdateCheckResult] =
  ## Check for updates, using cache if valid
  ## Returns None if check fails (fail-open policy)

  # Resolve config dir
  let resolvedConfigDir = if configDir.len > 0:
    expandPath(configDir)
  else:
    let found = findConfigDir()
    if found.isNone:
      getGlobalConfigDir() # Default to global
    else:
      found.get()

  let cachePath = getCachePath(resolvedConfigDir)

  # Check cache first (unless forcing)
  if not forceCheck and isCacheValid(cachePath):
    return loadCachedResult(cachePath)

  # Get current installed version from the resolved config dir
  let currentVersion = getInstalledVersion(resolvedConfigDir)
  if currentVersion.isNone:
    return none(UpdateCheckResult)

  # Load cached ETag for conditional request
  let cachedEtag = loadCachedEtag(cachePath)

  # Fetch latest from GitHub (with ETag for conditional request)
  let latest = fetchLatestRelease(cachedEtag)
  if latest.isNone:
    # Fetch failed - return cached result if available, otherwise none
    return loadCachedResult(cachePath)

  # If server returned 304 Not Modified, cache is still valid
  if latest.get().notModified:
    # Update the checked_at timestamp but keep other cached data
    let cached = loadCachedResult(cachePath)
    if cached.isSome:
      saveCacheResult(cachePath, cached.get(), cachedEtag)
    return cached

  # Compare versions
  let cmp = compareVersions(currentVersion.get(), latest.get().version)

  var checkResult = UpdateCheckResult(
    currentVersion: currentVersion.get(),
    latestVersion: latest.get().version,
    updateAvailable: cmp < 0, # Update available if current < latest
    releaseUrl: latest.get().url
  )

  # Cache the result with new ETag
  saveCacheResult(cachePath, checkResult, latest.get().etag)

  return some(checkResult)

proc runCheckUpdate*(silent: bool = true, configDir: string = "") =
  ## Run update check (called from hook)
  ## Silent mode: just update cache, no output
  ## Non-silent: print result
  ## If configDir is empty, checks all installed platforms

  if configDir.len > 0:
    # Check specific config dir
    let result = checkForUpdate(configDir, forceCheck = false)

    if not silent and result.isSome:
      let r = result.get()
      if r.updateAvailable:
        echo "GSD update available: ", r.currentVersion, " -> ", r.latestVersion
        echo "Run 'gsd update' or visit: ", r.releaseUrl
      else:
        echo "GSD is up to date (", r.currentVersion, ")"
  else:
    # Check all installed platforms
    let installed = findInstalledPlatforms()

    if installed.len == 0:
      if not silent:
        echo "No GSD installation found."
      return

    var anyUpdateAvailable = false
    var latestVersion = ""
    var releaseUrl = ""
    var currentVersion = ""

    for plat in installed:
      let found = findConfigDir(plat)
      if found.isNone:
        continue

      let result = checkForUpdate(found.get(), forceCheck = false)

      if result.isSome:
        let r = result.get()
        if r.updateAvailable:
          anyUpdateAvailable = true
          latestVersion = r.latestVersion
          releaseUrl = r.releaseUrl
        currentVersion = r.currentVersion

    if not silent:
      if anyUpdateAvailable:
        echo "GSD update available: ", currentVersion, " -> ", latestVersion
        echo "Run 'gsd update' or visit: ", releaseUrl
      elif currentVersion.len > 0:
        echo "GSD is up to date (", currentVersion, ")"

proc runUpdateAll*(sourceDir: string, verbose: bool = false): bool =
  ## Update all installed platforms
  ## Returns true if all updates succeeded
  let installed = findInstalledPlatforms()

  if installed.len == 0:
    echo "No GSD installation found."
    return false

  var allSuccess = true

  # Import install module dynamically to avoid circular deps
  # We'll call install() for each platform
  for plat in installed:
    let found = findConfigDir(plat)
    if found.isNone:
      continue

    echo "Updating ", $plat, "..."

    # Clear cache for this platform
    let cachePath = found.get() / CacheDirName / CacheFileName
    if fileExists(cachePath):
      try:
        removeFile(cachePath)
      except OSError:
        discard

  return allSuccess

proc clearUpdateCache*(configDir: string = "") =
  ## Clear the update cache (called after update)
  if configDir.len > 0:
    let path = expandPath(configDir) / CacheDirName / CacheFileName
    if fileExists(path):
      try:
        removeFile(path)
      except OSError:
        discard
  else:
    # Clear cache for all installed platforms
    let installed = findInstalledPlatforms()
    for plat in installed:
      let found = findConfigDir(plat)
      if found.isSome:
        let path = found.get() / CacheDirName / CacheFileName
        if fileExists(path):
          try:
            removeFile(path)
          except OSError:
            discard
