local Utils = {}

function Utils.parse_resolve_date(date_str)
    if not date_str then return nil end
    local months = {Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6, Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12}

    -- Format: "Sat Jun 6 2026 11:03:47" (DaVinci Resolve Default on macOS)
    local _, m_str, day_num, year_num, h_num, mn_num, s_num = date_str:match(
        "(%a+) (%a+) (%d+) (%d+) (%d+):(%d+):(%d+)")
    if m_str and day_num and year_num then
        return os.time({year=year_num, month=months[m_str], day=day_num, hour=h_num, min=mn_num, sec=s_num})
    end

    -- Format: "8 Jun 2026 10:00:00"
    local d1, m1, y1, h1, min1, s1 = date_str:match("(%d+) (%a+) (%d+) (%d+):(%d+):(%d+)")
    if d1 and m1 and y1 then
        return os.time({year=y1, month=months[m1], day=d1, hour=h1, min=min1, sec=s1})
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
