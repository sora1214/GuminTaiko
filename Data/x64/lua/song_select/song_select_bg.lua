-- 曲選択画面.背景クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

SongSelectBg = {}
function SongSelectBg.New(InstanceName_1)
	return
	{
		--　インスタンス名を代入
		instance_name_1 = InstanceName_1,

		-- ジャンルで背景が変わるか（コラボ背景はfalse）
		is_variable_background = true,
		
		--　ロード
		LoadMovieBg = function(this)
			local filename = "lumen/000_default/enso_normal/song_select/song_select_bg"
			local bgFla = QR.GetSongSelectBGFla(SceneType.kSongSelect)
			if(bgFla ~= "") then
				filename = "lumen/"..bgFla
				this.is_variable_background = false
				Debug.PrintString(filename);
			end
--[[
			for i = 1,2 do
				local play_data = PlayDataManager.GetEntryPlayData(i)
				if(play_data.qr_data.qrDataList_size > 0) then
					local qrCodeInfo = QRCodeInfo.create(play_data.qr_data.qrDataList[1].responseId) -- 1でいいかは後で確認
					-- この辺の条件についても後で直す
					if(qrCodeInfo.unique_id == 2001) then
						this.is_variable_background = false
						filename = "lumen/"..qrCodeInfo.songselect_bg_fla
						Debug.PrintString(filename);
					end
				end
			end
]]
			Lumen.LoadMovie(filename,this.instance_name_1)
		end,
		
		-- セットアップ
		SetupBg = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_bg 	= Lumen.GetMovieClip(this.instance_name_1,true)				
			end
		end,
		
		-- ジャンルで背景が変わるか（コラボ背景はfalse）
		IsVariableBackground = function(this)
			return this.is_variable_background
		end,
	}
end

