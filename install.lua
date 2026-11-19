local CONFIG = {
    Owner = "Not-CatDev",
    Repository = "PawUI",
    Branch = "main",
    InstallPath = "/PawUI"
}

local API_URL = "https://api.github.com/repos/"
    .. CONFIG.Owner .. "/"
    .. CONFIG.Repository
    .. "/git/trees/" .. CONFIG.Branch
    .. "?recursive=1"

local RAW_URL = "https://raw.githubusercontent.com/"
    .. CONFIG.Owner .. "/"
    .. CONFIG.Repository .. "/"
    .. CONFIG.Branch .. "/"

local args = { ... }
local UPDATE_MODE = false

for _, argument in ipairs(args) do
    if argument == "--update" then
        UPDATE_MODE = true
    end
end

local function log(message)
    print("[PawUI] " .. message)
end

local function fail(message)
    error(message, 0)
end

local function encodePath(path)
    local result = {}

    for segment in path:gmatch("[^/]+") do
        table.insert(result, textutils.urlEncode(segment))
    end

    return table.concat(result, "/")
end

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then
        return nil
    end

    local file = fs.open(path, "r")

    if not file then
        return nil
    end

    local content = file.readAll()
    file.close()

    return content
end

local function request(url)
    local response, reason = http.get(url)

    if not response then
        fail("Request failed: " .. tostring(reason))
    end

    local code = response.getResponseCode()
    local content = response.readAll()

    response.close()

    if code < 200 or code >= 300 then
        fail("HTTP error " .. code .. " while accessing:\n" .. url)
    end

    return content
end

local function getRepositoryFiles()
    log("Fetching repository information...")

    local content = request(API_URL)
    local data = textutils.unserializeJSON(content)

    if not data or not data.tree then
        fail("Invalid GitHub API response.")
    end

    if data.truncated then
        fail("Repository is too large for a complete file listing.")
    end

    local files = {}

    for _, entry in ipairs(data.tree) do
        if entry.type == "blob" and entry.path ~= "install.lua" then
            -- Prevent paths from escaping the installation directory.
            if not entry.path:match("^/")
                and not entry.path:match("(^|/)%.%.(/|$)") then
                table.insert(files, entry.path)
            end
        end
    end

    return files
end

local function installFile(path)
    local destination = fs.combine(CONFIG.InstallPath, path)
    local url = RAW_URL .. encodePath(path)

    local remoteContent = request(url)

    if UPDATE_MODE then
        local localContent = readFile(destination)

        if localContent == remoteContent then
            return "unchanged"
        end
    end

    local directory = fs.getDir(destination)

    if not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local file = fs.open(destination, "w")

    if not file then
        fail("Could not write file: " .. destination)
    end

    file.write(remoteContent)
    file.close()

    return "updated"
end

local function install()
    log("Starting " .. (UPDATE_MODE and "update" or "installation") .. "...")

    if not http then
        fail("HTTP is unavailable. Enable HTTP in the server configuration.")
    end

    local files = getRepositoryFiles()

    if not fs.exists(CONFIG.InstallPath) then
        fs.makeDir(CONFIG.InstallPath)
    end

    local updated = 0
    local unchanged = 0

    for index, path in ipairs(files) do
        log("[" .. index .. "/" .. #files .. "] " .. path)

        local result = installFile(path)

        if result == "updated" then
            updated = updated + 1
        else
            unchanged = unchanged + 1
        end
    end

    print("")
    log("Operation completed!")
    print("Updated: " .. updated)
    print("Unchanged: " .. unchanged)
    print("Total: " .. #files)
end

local success, result = pcall(install)

if success then
    local installerPath = shell.getRunningProgram()

    if installerPath and fs.exists(installerPath) then
        fs.delete(installerPath)
    end

    print("")
    log("Installer removed.")
else
    print("")
    printError("Installation failed:")
    printError(tostring(result))
    printError("Installer retained for retry.")
end
