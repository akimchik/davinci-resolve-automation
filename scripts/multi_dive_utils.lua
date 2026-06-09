local Utils = {}

function Utils.parse_resolve_date(date_str)
    if not date_str then return nil end
    local months = {Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6, Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12}
    
    -- Format: "8 Jun 2026 10:00:00"
    local day, month_str, year, hour, min, sec = date_str:match("(%d+) (%a+) (%d+) (%d+):(%d+):(%d+)")
    if day and month_str and year then
        return os.time({year=year, month=months[month_str], day=day, hour=hour, min=min, sec=sec})
    end
    
    -- Format: "08/06/2026 10:00:00"
    local d, m, y, h, mn, s = date_str:match("(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")
    if d and m and y then
        return os.time({year=y, month=m, day=d, hour=h, min=mn, sec=s})
    end
    
    -- Format: "2026:06:08 10:00:00"
    local y2, m2, d2, h2, mn2, s2 = date_str:match("(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)")
    if y2 and m2 and d2 then
        return os.time({year=y2, month=m2, day=d2, hour=h2, min=mn2, sec=s2})
    end

    return nil
end

return Utils
