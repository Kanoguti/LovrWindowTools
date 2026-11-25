local ffi=require("ffi")
local bit=require("bit")

ffi.cdef([[
    enum {
        GLFW_TRUE = 1,
        GLFW_FALSE = 0,
		GLFW_RESIZABLE = 0x00020003,
        GLFW_VISIBLE = 0x00020004,
		GLFW_DECORATED = 0x00020005,
		GLFW_FLOATING = 0x00020007,
        GLFW_DONT_CARE = -1,
        GLFW_CURSOR = 0x00033001,
        GLFW_CURSOR_NORMAL = 0x00034001,
        GLFW_CURSOR_HIDDEN = 0x00034002,
        GLFW_FOCUSED = 0x00020001,
        GLFW_MAXIMIZED = 0x00020008,
        GLFW_ICONIFIED = 0x00020002
	};

    typedef struct GLFWwindow GLFWwindow;
    typedef struct {
        int width;
        int height;
        unsigned char* pixels;
    } GLFWimage;
    typedef struct GLFWmonitor GLFWmonitor;
    typedef struct {
        int width;
        int height;
        int redBits;
        int greenBits;
        int blueBits;
        int refreshRate;
    } GLFWvidmode;
    typedef void* HWND;

    GLFWwindow* os_get_glfw_window(void);
    void glfwMaximizeWindow(GLFWwindow* window);
    void glfwIconifyWindow(GLFWwindow* window);
    void glfwRestoreWindow(GLFWwindow* window);
    void glfwFocusWindow(GLFWwindow* window);
    void glfwSetWindowSize(GLFWwindow* window, int width, int height);
	void glfwGetWindowSize(GLFWwindow* window, int *width, int *height);
    void glfwSetWindowPos(GLFWwindow* window, int xpos, int ypos);
	void glfwGetWindowPos(GLFWwindow* window, int *xpos, int *ypos);
    void glfwSetWindowSizeLimits(GLFWwindow* window, int minwidth, int minheight, int maxwidth, int maxheight);
    void glfwSetWindowAspectRatio(GLFWwindow* window, int number, int denom);
    void glfwSetWindowAttrib(GLFWwindow* window, int attrib, int value);
    int glfwGetWindowAttrib(GLFWwindow* window, int attrib);
    void glfwSetInputMode(GLFWwindow* window, int mode, int value);
    int glfwGetInputMode(GLFWwindow* window, int mode);
    void glfwSetWindowTitle(GLFWwindow* window, const char* title);
    const char* glfwGetWindowTitle(GLFWwindow* window);
    void glfwSetWindowIcon(GLFWwindow* window, int count, GLFWimage* images);
    void glfwShowWindow(GLFWwindow* window);
    void glfwHideWindow(GLFWwindow* window);

    GLFWmonitor* glfwGetPrimaryMonitor(void);
    GLFWmonitor** glfwGetMonitors(int* count);
    const GLFWvidmode* glfwGetVideoMode(GLFWmonitor* monitor);
    void glfwGetMonitorPos(GLFWmonitor* monitor, int* xpos, int* ypos);

    GLFWwindow* glfwCreateWindow(int width, int height, const char *title, GLFWmonitor *monitor, GLFWwindow *share);
    HWND glfwGetWin32Window(GLFWwindow* window);
    void glfwDestroyWindow(GLFWwindow* window);
]])

local dll_name
if(ffi.os=="Windows") then
    dll_name="glfw3.dll"
elseif(ffi.os=="OSX") then
    dll_name="libglfw.3.dylib"
elseif(ffi.os=="Linux") then
    dll_name="libglfw.so.3"
else
    error("LovrWindowTools is not supported on this OS!")
end
local glfw=ffi.load(dll_name)

local ffi_user32,user32
local ffi_dwmapi,dwmapi
if(ffi.os=="Windows") then
    ffi_user32=require("ffi")
    ffi_user32.cdef([[
        enum {
            SWP_NOMOVE=0x0002,
            SWP_NOSIZE=0x0001,
            SWP_NOZORDER=0x0004,
            SWP_FRAMECHANGED=0x0020
        };

        typedef void* HWND;
        HWND SetParent(HWND hWndChild,HWND hWndNewParent);
        bool SetWindowPos(HWND hWnd,HWND hWndInsertAfter,int X,int Y,int cx,int cy,unsigned int uFlags);
    ]])
    user32=ffi_user32.load("User32")

    ffi_dwmapi=require("ffi")
    ffi_dwmapi.cdef([[
        enum {
            DWMWA_WINDOW_CORNER_PREFERENCE=33,
            DWMWCP_DONOTROUND=1
        };    

        typedef long HRESULT;
        typedef void* HWND;
        typedef unsigned long DWORD;
        typedef const void *LPCVOID;
        typedef void *PVOID;

        HRESULT DwmSetWindowAttribute(HWND hwnd,DWORD dwAttribute,LPCVOID pvAttribute,DWORD cbAttribute);
        HRESULT DwmGetWindowAttribute(HWND hwnd,DWORD dwAttribute,PVOID pvAttribute,DWORD cbAttribute);
    ]])
    dwmapi=ffi_dwmapi.load("Dwmapi")
end

local lib={}

setmetatable(lib,{target_window=nil,icon=nil,fake_window=nil,save_window_info={}})

function lib.setWindow(window)
    local mt=getmetatable(lib)
    mt.target_window=window
end

function lib.getWindow()
    local mt=getmetatable(lib)
    if(mt.target_window==nil) then
        if(lovr.system.isWindowOpen()==true) then
            return ffi.C.os_get_glfw_window()
        else
            return nil
        end
    else
        return mt.target_window
    end
end

function lib.getFakeWindow()
    local mt=getmetatable(lib)
    return mt.fake_window
end

function lib.getGLFWimage(p_width,p_height,p_table)
    local return_data=ffi.new("GLFWimage")
    return_data.width=p_width
    return_data.height=p_height
    return_data.pixels=ffi.new("unsigned char["..(return_data.width*return_data.height*4).."]")
    for y=0,return_data.height-1 do
        for x=0,return_data.width-1 do
            local index=(x+y*return_data.width)*4
            local r,g,b,a=p_table[index+1] or 0,p_table[index+2] or 0,p_table[index+3] or 0,p_table[index+4] or 0
            r,g,b,a=math.floor(r*255),math.floor(g*255),math.floor(b*255),math.floor(a*255)
            return_data.pixels[index+0]=r
            return_data.pixels[index+1]=g
            return_data.pixels[index+2]=b
            return_data.pixels[index+3]=a
        end
    end
    return return_data
end

function lib.getGLFWimageFromImage(p_image)
    local return_data=ffi.new("GLFWimage")
    return_data.width=p_image:getWidth()
    return_data.height=p_image:getHeight()
    return_data.pixels=ffi.new("unsigned char["..(return_data.width*return_data.height*4).."]")
    for y=0,return_data.height-1 do
        for x=0,return_data.width-1 do
            local index=(x+y*return_data.width)*4
            local r,g,b,a=p_image:getPixel(x,y)
            r,g,b,a=math.floor(r*255),math.floor(g*255),math.floor(b*255),math.floor(a*255)
            return_data.pixels[index+0]=r
            return_data.pixels[index+1]=g
            return_data.pixels[index+2]=b
            return_data.pixels[index+3]=a
        end
    end
    return return_data
end

function lib.getMonitors()
    if(lovr.system.isWindowOpen()==true) then
        local count=ffi.new("int[1]")
        local monitors=glfw.glfwGetMonitors(count)
        return monitors,count[0]
    else
        return nil,nil
    end
end

function lib.getMonitor(p_id)
    local monitor=nil
    if(lovr.system.isWindowOpen()==true) then
        if(p_id==nil) then
            monitor=glfw.glfwGetPrimaryMonitor()
        else
            local monitors,count=lib.getMonitors()
            if(1<=p_id and p_id<=count) then
                monitor=monitors[p_id-1]
            end
        end
    end
    return monitor
end

function lib.maximize(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_bool==true) then
            glfw.glfwMaximizeWindow(window)
        elseif(p_bool==false) then
            glfw.glfwRestoreWindow(window)
        else
            local get=glfw.glfwGetWindowAttrib(window,glfw.GLFW_MAXIMIZED)
            if(get==glfw.GLFW_TRUE) then
                return true
            else
                return false
            end
        end
    end
    return nil
end

function lib.minimize(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_bool==true) then
            glfw.glfwIconifyWindow(window)
        elseif(p_bool==false) then
            glfw.glfwRestoreWindow(window)
        else
            local get=glfw.glfwGetWindowAttrib(window,glfw.GLFW_ICONIFIED)
            if(get==glfw.GLFW_TRUE) then
                return true
            else
                return false
            end
        end
    end
    return nil
end

function lib.focus(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        local mt=getmetatable(lib)
        if(p_bool==true) then
            if(mt.fake_window~=nil) then
                glfw.glfwFocusWindow(mt.fake_window)
            end
            glfw.glfwFocusWindow(window)
        else
            local get=glfw.glfwGetWindowAttrib(window,glfw.GLFW_FOCUSED)
            if(get==glfw.GLFW_TRUE) then
                return true
            else
                return false
            end
        end
    end
    return nil
end

function lib.resizable(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_bool==true) then
            glfw.glfwSetWindowAttrib(window,glfw.GLFW_RESIZABLE,glfw.GLFW_TRUE)
        elseif(p_bool==false) then
            glfw.glfwSetWindowAttrib(window,glfw.GLFW_RESIZABLE,glfw.GLFW_FALSE)
        else
            local get=glfw.glfwGetWindowAttrib(window,glfw.GLFW_RESIZABLE)
            if(get==glfw.GLFW_TRUE) then
                return true
            else
                return false
            end
        end
    end
    return nil
end

function lib.visible(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_bool==true) then
            glfw.glfwShowWindow(window)
        elseif(p_bool==false) then
            glfw.glfwHideWindow(window)
        else
            local get=glfw.glfwGetWindowAttrib(window,glfw.GLFW_VISIBLE)
            if(get==glfw.GLFW_TRUE) then
                return true
            else
                return false
            end
        end
    end
    return nil
end

function lib.decorated(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_bool==true) then
            glfw.glfwSetWindowAttrib(window,glfw.GLFW_DECORATED,glfw.GLFW_TRUE)
        elseif(p_bool==false) then
            glfw.glfwSetWindowAttrib(window,glfw.GLFW_DECORATED,glfw.GLFW_FALSE)
        else
            local get=glfw.glfwGetWindowAttrib(window,glfw.GLFW_DECORATED)
            if(get==glfw.GLFW_TRUE) then
                return true
            else
                return false
            end
        end
    end
    return nil
end

function lib.floating(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_bool==true) then
            glfw.glfwSetWindowAttrib(window,glfw.GLFW_FLOATING,glfw.GLFW_TRUE)
        elseif(p_bool==false) then
            glfw.glfwSetWindowAttrib(window,glfw.GLFW_FLOATING,glfw.GLFW_FALSE)
        else
            local get=glfw.glfwGetWindowAttrib(window,glfw.GLFW_FLOATING)
            if(get==glfw.GLFW_TRUE) then
                return true
            else
                return false
            end
        end
    end
    return nil
end

function lib.size(p_width,p_height)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_width~=nil and p_height~=nil) then
            glfw.glfwSetWindowSize(window,p_width,p_height)
        else
            local return_data={width=ffi.new("int[1]"),height=ffi.new("int[1]")}
            glfw.glfwGetWindowSize(window,return_data.width,return_data.height)
            return return_data.width[0],return_data.height[0]
        end
    end
    return nil,nil
end

function lib.sizeLimits(p_min_width,p_min_height,p_max_width,p_max_height)
    p_min_width=p_min_width or glfw.GLFW_DONT_CARE
    p_min_height=p_min_height or glfw.GLFW_DONT_CARE
    p_max_width=p_max_width or glfw.GLFW_DONT_CARE
    p_max_height=p_max_height or glfw.GLFW_DONT_CARE

    local window=lib.getWindow()
    if(window~=nil) then
        glfw.glfwSetWindowSizeLimits(window,p_min_width,p_min_height,p_max_width,p_max_height)
    end
end

function lib.position(p_x,p_y)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_x~=nil and p_y~=nil) then
            glfw.glfwSetWindowPos(window,p_x,p_y)
        else
            local return_data={x=ffi.new("int[1]"),y=ffi.new("int[1]")}
            glfw.glfwGetWindowPos(window,return_data.x,return_data.y)
            return return_data.x[0],return_data.y[0]
        end
    end
    return nil,nil
end

function lib.aspectRatio(p_x,p_y)
    p_x=p_x or glfw.GLFW_DONT_CARE
    p_y=p_y or glfw.GLFW_DONT_CARE
    if(p_x<1 or p_y<1) then
        p_x=glfw.GLFW_DONT_CARE
        p_y=glfw.GLFW_DONT_CARE
    end

    local window=lib.getWindow()
    if(window~=nil) then
        glfw.glfwSetWindowAspectRatio(window,p_x,p_y)
    end
end

function lib.cursor(p_bool)
    local window=lib.getWindow()
    if(window~=nil) then
        if(p_bool==true) then
            glfw.glfwSetInputMode(window,glfw.GLFW_CURSOR,glfw.GLFW_CURSOR_NORMAL)
        elseif(p_bool==false) then
            glfw.glfwSetInputMode(window,glfw.GLFW_CURSOR,glfw.GLFW_CURSOR_HIDDEN)
        else
            local get=glfw.glfwGetInputMode(window,glfw.GLFW_CURSOR)
            if(get==glfw.GLFW_CURSOR_HIDDEN) then
                return false
            else
                return true
            end
        end
    end
    return nil
end

function lib.title(p_text)
    local window=lib.getWindow()
    if(window~=nil) then
        local mt=getmetatable(lib)
        if(p_text~=nil) then
            glfw.glfwSetWindowTitle(window,p_text)
            if(mt.fake_window~=nil) then
                glfw.glfwSetWindowTitle(mt.fake_window,p_text)
            end
            return nil
        else
            return ffi.string(glfw.glfwGetWindowTitle(window))
        end
    end
    return nil
end

function lib.icon(p_GLFWimage)
    if(ffi.os~="OSX") then
        local window=lib.getWindow()
        if(window~=nil) then
            local mt=getmetatable(lib)
            mt.icon=p_GLFWimage

            if(mt.icon~=nil) then
                glfw.glfwSetWindowIcon(window,1,mt.icon)
                if(mt.fake_window~=nil) then
                    glfw.glfwSetWindowIcon(mt.fake_window,1,mt.icon)
                end
            else
                glfw.glfwSetWindowIcon(window,0,nil)
                if(mt.fake_window~=nil) then
                    glfw.glfwSetWindowIcon(mt.fake_window,0,nil)
                end
            end

            if(mt.fake_window~=nil) then
                user32.SetWindowPos(glfw.glfwGetWin32Window(mt.fake_window),nil, 0,0,0,0, bit.bor(user32.SWP_NOMOVE,user32.SWP_NOSIZE,user32.SWP_NOZORDER,user32.SWP_FRAMECHANGED))
            end
        end
    end
end

function lib.monitorSize(p_id)
    local monitor=lib.getMonitor(p_id)
    if(monitor~=nil) then
        local vidmode=glfw.glfwGetVideoMode(monitor)
        return vidmode.width,vidmode.height
    end
    return nil,nil
end

function lib.monitorRefreshRate(p_id)
    local monitor=lib.getMonitor(p_id)
    if(monitor~=nil) then
        local vidmode=glfw.glfwGetVideoMode(monitor)
        return vidmode.refreshRate
    end
    return nil
end

function lib.monitorPosition(p_id)
    local monitor=lib.getMonitor(p_id)
    if(monitor~=nil) then
        local x,y=ffi.new("int[1]"),ffi.new("int[1]")
        glfw.glfwGetMonitorPos(monitor,x,y)
        return x[0],y[0]
    end
    return nil,nil
end

function lib.fakeFullscreen(p_bool,p_monitor_id)
    p_bool=p_bool or false
    p_monitor_id=p_monitor_id or 1
    if(lovr.system.isWindowOpen()==true) then
        local monitor_width,monitor_height=lib.monitorSize(p_monitor_id)
        local monitor_x,monitor_y=lib.monitorPosition(p_monitor_id)
        local window=ffi.C.os_get_glfw_window()
        local mt=getmetatable(lib)
        local temp_window=mt.target_window
        
        if(ffi.os=="Windows" and lovr.system.isWindowFullscreen()==false) then
            if(p_bool==true) then
                if(mt.fake_window==nil) then
                    lib.setWindow(nil)
                    mt.save_window_info={}
                    mt.save_window_info.decorated=lib.decorated()
                    mt.save_window_info.position={}
                    mt.save_window_info.position.x,mt.save_window_info.position.y=lib.position()
                    mt.save_window_info.size={}
                    mt.save_window_info.size.width,mt.save_window_info.size.height=lib.size()
                    mt.save_window_info.corner=ffi_dwmapi.new("int[1]")
                    mt.save_window_info.title=lib.title()
                    mt.save_window_info.focus=lib.focus()
                    dwmapi.DwmGetWindowAttribute(glfw.glfwGetWin32Window(window),dwmapi.DWMWA_WINDOW_CORNER_PREFERENCE,mt.save_window_info.corner,ffi_dwmapi.sizeof(mt.save_window_info.corner))

                    mt.fake_window=glfw.glfwCreateWindow(monitor_width,monitor_height,mt.save_window_info.title,nil,nil)
                    lib.setWindow(mt.fake_window)
                    lib.sizeLimits(0,0,monitor_width,monitor_height)
                    lib.size(monitor_width,monitor_height)
                    lib.decorated(false)
                    lib.position(monitor_x,monitor_y)
                    lib.visible(true)
                    lib.setWindow(nil)
                    lib.decorated(true)
                    user32.SetParent(glfw.glfwGetWin32Window(window),glfw.glfwGetWin32Window(mt.fake_window))
                    local corner_preference=ffi_dwmapi.new("int[1]",dwmapi.DWMWCP_DONOTROUND)
                    dwmapi.DwmSetWindowAttribute(glfw.glfwGetWin32Window(window),dwmapi.DWMWA_WINDOW_CORNER_PREFERENCE,corner_preference,ffi_dwmapi.sizeof(corner_preference))
                    lib.position(0,0)
                    lib.sizeLimits(0,0,monitor_width,monitor_height)
                    lib.size(monitor_width,monitor_height)
                    lib.icon(mt.icon)
                    if(mt.save_window_info.focus==true) then
                        lib.focus(true)
                    end
                    lib.setWindow(temp_window)
                end
            else
                if(mt.fake_window~=nil) then
                    user32.SetParent(glfw.glfwGetWin32Window(window),nil)
                    dwmapi.DwmSetWindowAttribute(glfw.glfwGetWin32Window(window),dwmapi.DWMWA_WINDOW_CORNER_PREFERENCE,mt.save_window_info.corner,ffi_dwmapi.sizeof(mt.save_window_info.corner))
                    glfw.glfwDestroyWindow(mt.fake_window)
                    mt.fake_window=nil
                    lib.setWindow(nil)
                    lib.size(mt.save_window_info.size.width,mt.save_window_info.size.height)
                    lib.position(mt.save_window_info.position.x,mt.save_window_info.position.y)
                    lib.decorated(mt.save_window_info.decorated)
                    lib.setWindow(temp_window)
                end
            end
        else
            if(p_bool==true) then
                mt.save_window_info={}
                mt.save_window_info.position={}
                mt.save_window_info.position.x,mt.save_window_info.position.y=lib.position()
                mt.save_window_info.size={}
                mt.save_window_info.size.width,mt.save_window_info.size.height=lib.size()
                
                lib.decorated(false)
                lib.size(monitor_width,monitor_height)
                lib.position(monitor_x,monitor_y)
            else
                lib.decorated(true)
                lib.size(mt.save_window_info.size.width,mt.save_window_info.size.height)
                lib.position(mt.save_window_info.position.x,mt.save_window_info.position.y)
            end
        end
    end
end

return lib