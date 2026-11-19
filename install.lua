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

local function log(message)
    print("[PawUI] " .. message)
end

local function fail(message)
    printError("[PawUI] " .. message)
    print("Installation failed. Installer retained.")
    error(message, 0)
end

local function download(url, destination)
    local response, reason = http.get(url)

    if not response then
        fail("Download failed: " .. url .. "\n" .. tostring(reason))
    end

    local content = response.readAll()
    response.close()

    if not content then
        fail("Empty response: " .. url)
    end

    local file = fs.open(destination, "w")

    if not file then
        fail("Could not write: " .. destination)
    end

    file.write(content)
    file.close()
end

local function getRepositoryFiles()
    log("Fetching repository information...")

    local response, reason = http.get(API_URL)

    if not response then
        fail("Could not access GitHub API: " .. tostring(reason))
    end

    local content = response.readAll()
    response.close()

    local data = textutils.unserializeJSON(content)

    if not data or not data.tree then
        fail("Invalid GitHub API response.")
    end

    local files = {}

    for _, entry in ipairs(data.tree) do
        if entry.type == "blob" then
            table.insert(files, entry.path)
        end
    end

    return files
end

local function install()
    log("Starting installation...")

    local files = getRepositoryFiles()

    if fs.exists(CONFIG.InstallPath) then
        fs.delete(CONFIG.InstallPath)
    end

    fs.makeDir(CONFIG.InstallPath)

    local installed = 0

    for _, path in ipairs(files) do
        if path ~= "install.lua" then
            local destination = fs.combine(CONFIG.InstallPath, path)
            local directory = fs.getDir(destination)

            if not fs.exists(directory) then
                fs.makeDir(directory)
            end

            log("Downloading " .. path)

            download(RAW_URL .. path, destination)

            installed = installed + 1
        end
    end

    log("Installed " .. installed .. " files.")
    log("PawUI installation completed!")
end

local success, result = pcall(install)

if success then
    if fs.exists("install.lua") then
        fs.delete("install.lua")
    end

    print("")
    log("Installer removed.")
    log("You can now use require('/PawUI').")
else
    printError("")
    printError("Installation stopped: " .. tostring(result))
end
