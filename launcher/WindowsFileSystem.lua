local ffi = require("ffi")

ffi.cdef[[
int __stdcall MultiByteToWideChar(unsigned int codePage, unsigned long flags,
    const char *text, int length, wchar_t *output, int outputLength);
void *_wfopen(const wchar_t *path, const wchar_t *mode);
int _wremove(const wchar_t *path);
int _wrename(const wchar_t *source, const wchar_t *target);
size_t fread(void *buffer, size_t size, size_t count, void *file);
size_t fwrite(const void *buffer, size_t size, size_t count, void *file);
int fclose(void *file);
int ferror(void *file);
int *_errno(void);
char *strerror(int errorCode);
]]

local kernel = ffi.load("kernel32")
local crt = ffi.load("msvcrt")
local WindowsFileSystem = {}

local function wide(text)
    local length = kernel.MultiByteToWideChar(65001, 8, text, #text, nil, 0)
    if length == 0 then return nil end
    local output = ffi.new("wchar_t[?]", length + 1)
    kernel.MultiByteToWideChar(65001, 8, text, #text, output, length)
    return output
end

local function lastError()
    local code = crt._errno()[0]
    return nil, ffi.string(crt.strerror(code)), code
end

function WindowsFileSystem.open(path, mode)
    local widePath = wide(path)
    if not widePath then return nil, "Invalid UTF-8 path", 22 end
    local handle = crt._wfopen(widePath, wide(mode))
    if handle == nil then return lastError() end
    local file = {}

    function file:read()
        local buffer = ffi.new("char[65536]")
        local chunks = {}
        while true do
            local count = tonumber(crt.fread(buffer, 1, 65536, handle))
            if count > 0 then chunks[#chunks + 1] = ffi.string(buffer, count) end
            if count < 65536 then
                if crt.ferror(handle) ~= 0 then return lastError() end
                return table.concat(chunks)
            end
        end
    end

    function file:write(contents)
        if tonumber(crt.fwrite(contents, 1, #contents, handle)) ~= #contents then
            return lastError()
        end
        return self
    end

    function file:close()
        if crt.fclose(handle) ~= 0 then return lastError() end
        return true
    end

    return file
end

function WindowsFileSystem.remove(path)
    local widePath = wide(path)
    if not widePath then return nil, "Invalid UTF-8 path", 22 end
    if crt._wremove(widePath) ~= 0 then return lastError() end
    return true
end

function WindowsFileSystem.rename(sourcePath, targetPath)
    local source, target = wide(sourcePath), wide(targetPath)
    if not source or not target then return nil, "Invalid UTF-8 path", 22 end
    if crt._wrename(source, target) ~= 0 then return lastError() end
    return true
end

return WindowsFileSystem
