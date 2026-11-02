-- TXsetRF2/main.lua  (widget name: TX-set_RF2)
-- EdgeTX 2.12 / Rotorflight 対応
-- Thr RPM(GV1) / Coll P.(GV2) を FM0-2 で表示・編集
--
-- CH13 → GV1 (Thr RPM)   増減
-- CH11 → GV2 (Coll P.)   増減
-- EditSwitch手前: EDIT モード / 奥: LOCK モード
--
-- ※ Rotorflight 4.7 マスターゲイン調整は今後ここに追加予定

local app_name = "TX-set_RF2"

local WHITE  = 0xFFFFFF
local GREY   = 0x808080
local GREEN  = 0x00FF00
local RED    = 0xFF0000

local drawText = lcd.drawText
local drawLine = lcd.drawLine

-- ============================================================
--  数値変換
-- ============================================================
local function thrRPM(val, maxRPM)
    return math.floor(maxRPM * (val + 100) / 2000) * 10
end
local function collDeg(val, maxColl)
    return maxColl * (val + 100) / 200
end

-- ============================================================
--  GV変更共通処理
-- ============================================================
local function applyGV(wgt, gv_idx, dir, fm, maxRPM, maxColl, now, v_delay)
    local val = wgt.gv_vals["f"..fm.."g"..gv_idx] or 0
    local lo  = -100  -- 全GV共通下限
    val = math.max(lo, math.min(100, val + dir))
    model.setGlobalVariable(gv_idx, fm, val)
    wgt.gv_vals["f"..fm.."g"..gv_idx] = val
    wgt.last_tick       = now + 5
    wgt.voice_timer     = now + v_delay
    wgt.voice_dirty     = true
    wgt.last_played_num = -999
    if gv_idx == 0 then
        wgt.pending_voice_val = thrRPM(val, maxRPM)
    else
        wgt.pending_voice_val = math.floor(collDeg(val, maxColl) * 10)
    end
end

-- ============================================================
--  create
-- ============================================================
local function create(zone, options)
    return {
        zone              = zone,
        options           = options,
        gv_vals           = {},
        last_gv_tick      = 0,
        last_inputs       = { c13=0, c11=0 },
        last_tick         = 0,
        pending_voice_val = nil,
        voice_timer       = 0,
        last_played_num   = -999,
        min_voice_gap     = 0,
        voice_dirty       = false,
    }
end

-- ============================================================
--  refresh
-- ============================================================
local function refresh(wgt, event, touchState)
    if not wgt then return end
    local zone = wgt.zone
    local x, y, w, h = zone.x, zone.y, zone.w, zone.h
    local fm  = getFlightMode() or 0
    local now = getTime()

    local v_delay = (wgt.options and wgt.options.VoiceDelay)     or 40
    local v_guard = (wgt.options and wgt.options.VoiceGuardTime) or 70
    local maxColl = (wgt.options and wgt.options.MaxColl) or 14
    local maxRPM  = (wgt.options and wgt.options.MaxRPM)  or 3000

    -- GVキャッシュ更新 (50ms周期) : GV1, GV2 のみ
    if now > wgt.last_gv_tick then
        for f = 0, 2 do
            for g = 0, 1 do
                wgt.gv_vals["f"..f.."g"..g] = model.getGlobalVariable(g, f)
            end
        end
        wgt.last_gv_tick = now + 5
    end

    -- 編集スイッチ取得 (オプション画面でスイッチを選択)
    local sw_val = getValue((wgt.options and wgt.options.EditSwitch) or 0) or 0
    local sb_fwd = (sw_val > 500)

    -- ==========================================================
    --  トリム入力処理 (EditSwitch手前のみ有効)
    -- ==========================================================
    local c13     = getValue("ch13") or 0
    local c11     = getValue("ch11") or 0
    local is_tick = (now > wgt.last_tick)

    if sb_fwd then
        if wgt.last_inputs.c13 == 0 and math.abs(c13) > 500 and is_tick then
            applyGV(wgt, 0, (c13 > 500) and 1 or -1, fm, maxRPM, maxColl, now, v_delay)
        end
        if wgt.last_inputs.c11 == 0 and math.abs(c11) > 500 and is_tick then
            applyGV(wgt, 1, (c11 > 500) and 1 or -1, fm, maxRPM, maxColl, now, v_delay)
        end
    end

    wgt.last_inputs.c13 = (math.abs(c13) > 500) and 1 or 0
    wgt.last_inputs.c11 = (math.abs(c11) > 500) and 1 or 0

    -- 音声再生
    if wgt.voice_dirty and now > wgt.voice_timer and now > wgt.min_voice_gap then
        if wgt.pending_voice_val and wgt.pending_voice_val ~= wgt.last_played_num then
            playNumber(wgt.pending_voice_val, 0)
            wgt.last_played_num = wgt.pending_voice_val
            wgt.min_voice_gap   = now + v_guard
        end
        wgt.voice_dirty = false
    end

    -- ==========================================================
    --  描画
    -- ==========================================================
    local c_p = (wgt.options and wgt.options.ColorPast)   or GREY
    local c_a = (wgt.options and wgt.options.ColorActive) or RED
    local c_l = (wgt.options and wgt.options.ColorLabel)  or WHITE

    -- フォント・レイアウト (2行: Thr / Coll)
    local fontS, fontV, hdrH, labelW

    if h >= 150 then
        fontS = SMLSIZE; fontV = DBLSIZE
        hdrH  = math.floor(h * 0.18); labelW = math.floor(w * 0.24)
    elseif h >= 100 then
        fontS = SMLSIZE; fontV = MIDSIZE
        hdrH  = math.floor(h * 0.22); labelW = math.floor(w * 0.25)
    else
        -- 小型 (h≈75)
        fontS = SMLSIZE; fontV = MIDSIZE
        hdrH  = math.floor(h * 0.28); labelW = math.floor(w * 0.26)
    end

    local colW = math.floor((w - labelW) / 3)

    -- FM ヘッダー行
    -- 現在FM: EDIT時=c_a / LOCK時=c_p / 他FM: 常にc_p
    for col = 0, 2 do
        local fc = (col == fm) and (sb_fwd and c_a or c_p) or c_p
        drawText(x + labelW + math.floor(colW * (col + 0.5)),
                 y + 2, "FM"..col, fontS + fc + CENTER)
    end
    local lineY = y + hdrH - 1
    drawLine(x + 4, lineY, x + w - 4, lineY, SOLID, FORCE)

    -- 値行: 残り高さを2行均等割り
    local remainH = h - hdrH
    local gap     = math.max(1, math.floor(remainH * 0.04))
    local rowSlot = math.floor((remainH - gap) / 2)

    local rows = {
        { name="ThrRPM", gv=0 },
        { name="Coll P", gv=1 },
    }

    for ri, row in ipairs(rows) do
        local ry = lineY + gap + rowSlot * (ri - 1)
        drawText(x + 2, ry, row.name, fontS + c_l)
        for col = 0, 2 do
            local val = wgt.gv_vals["f"..col.."g"..row.gv] or 0
            local fc  = (col == fm) and c_l or c_p
            local cx  = x + labelW + math.floor(colW * (col + 0.5))
            local str
            if row.gv == 0 then
                str = tostring(thrRPM(val, maxRPM))
            else
                str = string.format("%.1f", collDeg(val, maxColl))
            end
            drawText(cx, ry, str, fontV + CENTER + fc)
        end
    end
end

-- ============================================================
--  options
-- ============================================================
local options = {
    { "EditSwitch",     SOURCE, 0                },  -- スイッチをリストから選択
    { "ColorPast",      COLOR, GREY             },
    { "ColorActive",    COLOR, RED              },
    { "ColorLabel",     COLOR, WHITE            },
    { "MaxColl",        VALUE, 14,   10,  16    },
    { "MaxRPM",         VALUE, 3000, 2000, 8000 },
    { "VoiceDelay",     VALUE, 40,   0,   200   },
    { "VoiceGuardTime", VALUE, 70,   0,   300   },
}

return {
    name    = app_name,
    options = options,
    create  = create,
    refresh = refresh,
    update  = function(wgt, opts) wgt.options = opts end,
}
