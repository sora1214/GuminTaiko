-- AI曲選択画面.AIどん調子クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectTension = {}
function AISongSelectTension.New(InstanceName_1)
	return
	{
		--　インスタンス名を代入
		instance_name_1 = InstanceName_1,
		
		mc_tension_ = 0,
		tension_level = 1,
		
		-- AIどんのテンションゲージ用のラベル名
		tbl_tensionLabel = {"worst", "bad", "normal", "good", "best"},
		
		--　ロード
		LoadMovieTension = function(this)
			local filename = "lumen/000_default/enso_ai/song_select/ai_song_select_tension"
			Lumen.LoadMovie(filename,this.instance_name_1)
		end,
		
		-- セットアップ
		SetupTension = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_tension_ 	= Lumen.GetMovieClip(this.instance_name_1,true)
				
				-- イベント中なら表示位置が下がる
				local is_event = false 					-- イベント中かどうかのフラグを代入
				
				if (is_event == true) then
					this.mc_tension_:GotoAndStop("event")
				end
				
				this.tension_level = aiCondition
				
				if (this.tension_level <= 1) then
					this.tension_level = AICondition.kWorst
				elseif (this.tension_level >= 5) then
					this.tension_level = AICondition.kBest
				end

				-- C++側で見れるようにグローバル変数に格納
				ai_don_condition = this.tension_level
				
				this:SetTensionGauge()
			end
		end,
		
		-- AIどんの調子ゲージ
		SetTensionGauge = function(this)
			
			this.mc_tension_:GotoAndStop("main",this.tbl_tensionLabel[this.tension_level])
			
			this:SetTextTension()
			
		end,
		
		-- テキスト流し込み
		SetTextTension = function(this)
		
			this.mc_tension_:SetText("main/text_tension_name", "text_tension_name", "ai_song_select_tension_name")
			
			if (this.tension_level == AICondition.kWorst) then
				this.mc_tension_:SetText("main/text_tension", "text_tension", "ai_song_select_tension_worst")
			elseif (this.tension_level == AICondition.kBad) then
				this.mc_tension_:SetText("main/text_tension", "text_tension", "ai_song_select_tension_bad")
			elseif (this.tension_level == AICondition.kNormal) then
				this.mc_tension_:SetText("main/text_tension", "text_tension", "ai_song_select_tension_normal")
			elseif (this.tension_level == AICondition.kGood) then
				this.mc_tension_:SetText("main/text_tension", "text_tension", "ai_song_select_tension_good")
			elseif (this.tension_level == AICondition.kBest) then
				this.mc_tension_:SetText("main/text_tension", "text_tension", "ai_song_select_tension_best")
			end
			
		end,
		
		-- AIの調子を取得するよう
		GetAITension = function(this)
			return this.tension_level
		end,
	}
end

