-- AI難易度選択画面.導出演出Lua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectDerivationMain = {}
function AISongSelectDerivationMain.New(InstanceName_1)
	return
	{
		-- インスタンス名を代入
		instance_name_1 = InstanceName_1,
		
		-- 導入演出Lumenのロード
		LoadMovieDerivationMain = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_before_load", this.instance_name_1)
		end,
		
		-- ムービークリップを取得
		SetupDerivation = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_main = Lumen.GetMovieClip(this.instance_name_1, true)				
				this.mc_main:SetText("main/txt_loading","txt_derivation","ai_song_select_derivation_loading")
				this.mc_main:SetText("main/txt_start","txt_derivation","ai_song_select_derivation_start")
			end
		end,
		
		-- 導入演出の再生
		PlayDerivation = function(this)
			Debug.PrintString("PlayDerivation")
			Debug.PrintString(this.mc_main)
			this.mc_main.main:GotoAndPlay("init")
		end,
		
		-- 導入演出が終わったらtrueを返す
		Is_EndAnimation = function(this)
			if (this.mc_main.main:IsPlay() == false) then
				--this.mc_main.main:GotoAndPlay("out")
				return true
			else
				return false
			end
		end,
	}
end

