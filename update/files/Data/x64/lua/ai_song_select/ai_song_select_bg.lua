-- AI曲選択画面.背景クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectBg = {}
function AISongSelectBg.New(InstanceName_1)
	return
	{
		--　インスタンス名を代入
		instance_name_1 = InstanceName_1,
		
		--　ロード
		LoadMovieBg = function(this)
			local filename = "lumen/000_default/enso_ai/song_select/ai_song_select_bg"
			local bgFla = QR.GetSongSelectBGFla(SceneType.kAISelect)
			if(bgFla ~= "") then
				filename = "lumen/"..bgFla
				Debug.PrintString(filename);
			end
--[[
			for i = 1,2 do
				local play_data = PlayDataManager.GetEntryPlayData(i)
				if(play_data.qr_data.qrDataList_size > 0) then
					local qrCodeInfo = QRCodeInfo.create(play_data.qr_data.qrDataList[1].uniqueId) -- 1でいいかは後で確認

					if(qrCodeInfo.unique_id == 2001) then
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
	}
end

