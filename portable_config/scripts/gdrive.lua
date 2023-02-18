TOKEN = ""
OPTIONS = {}



function on_load_hook()
    print("Loading GDrive script")
    local path = mp.get_property("path", "")
    file_id = detect_gdrive_file_id(path)
    if file_id then
        print("Detected google drive link, rewriting stream-open-filename")
        direct_url = "https://www.googleapis.com/drive/v3/files/" .. file_id .. "?alt=media"
        mp.set_property("stream-open-filename", direct_url)

        OPTIONS = load_options()
        TOKEN = get_access_token(OPTIONS)
        set_auth_headers(TOKEN)

        
        mp.add_hook("on_load_fail", 50, on_load_fail_hook)
    else
        print("Not google drive link, doing nothing.")
    end

end

function on_load_fail_hook()
    
    print('Token failed, refreshing...')
    TOKEN = get_access_token(OPTIONS)
    set_auth_headers(TOKEN)
end

mp.add_hook("on_load", 50, on_load_hook)


function detect_gdrive_file_id(path)
    if (path:find("gdrive://") == 1) then
        return path:sub(10) 
    elseif (path:find("https://drive.google.com/file/d/") == 1) then
        remainder = path:sub(33) 
        return remainder:sub(1, remainder:find("/") - 1)
    else
        return nil
    end
end


function set_auth_headers(access_token)
    print("Setting GDrive authorization headers")
    headers = {}
    headers[1] = "Authorization: Bearer " .. access_token
    mp.set_property_native("file-local-options/http-header-fields", headers)
end


function load_options()
    local options = require 'mp.options'
    local o = {
        gd_client_id = "",
        gd_client_secret = "",
        gd_refresh_token = "",
    }
    options.read_options(o, "gd")
    return o
end


function get_access_token(o)
    local utils = require 'mp.utils'

    request_body = (
        "client_id=" .. o.gd_client_id ..
        "&client_secret=" .. o.gd_client_secret ..
        "&refresh_token=" .. o.gd_refresh_token ..
        "&grant_type=refresh_token"
    )
    print("Requesting token for client_id", o.gd_client_id:sub(1, 10) .. "[...]")

    ret = mp.command_native({
        name = "subprocess",
        args = {
            "curl", "-s", "-X", "POST",
            "https://www.googleapis.com/oauth2/v4/token",
            "-H", "Accept: application/json",
            "-H", "Content-Type: application/x-www-form-urlencoded",
            "-d", request_body
        },
        capture_stdout=true
    })
    local resp_json, err = utils.parse_json(ret.stdout)
    access_token = resp_json["access_token"]
    print("Received access_token", access_token:sub(1, 10) .. "[...]")
    return access_token
end
