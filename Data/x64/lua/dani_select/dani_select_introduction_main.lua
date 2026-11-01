-- 段位選択画面.段位選択導入演出Lua
-- Masayuki_Teraoka@al.bandainamco.jp

DaniSelectIntroductionMain = {}
function DaniSelectIntroductionMain.New(InstanceName_1)
	return
	{
		-- インスタンス名を代入
		instance_name_1 = InstanceName_1,
		
		-- 導入演出Lumenのロード
		LoadMovieIntroductionMain = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_dani/loading_dani/loading_dani_intro", this.instance_name_1)
		end,
		
		-- ムービークリップを取得
		SetupIntroduction = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_main = Lumen.GetMovieClip(this.instance_name_1, true)				
			end
		end,
		
		-- 導入演出の再生
		PlayIntroduction = function(this)
			Debug.PrintString("PlayIntroduction")
			Debug.PrintString(this.mc_main)
			TSound:Play("se_daniodai_v12e","intro")
			this.mc_main.main:GotoAndPlay("in")
		end,
		
		-- 導入演出が終わったらtrueを返す
		Is_EndAnimation = function(this)
			if (this.mc_main.main:IsPlay() == false) then
				this.mc_main.main:GotoAndPlay("out")
				return true
			else
				return false
			end
		end,
	}
end

